import 'package:florien/core/storage/firestore_task_collection.dart';
import 'package:florien/core/storage/local_task_collection.dart';
import 'package:florien/core/storage/task_collection.dart';
import 'package:florien/core/storage/task_storage_mode.dart';
import 'package:flutter/foundation.dart';

typedef PremiumLookup = bool? Function();

/// Picks Hive vs Firestore and runs Free↔Premium migrations.
///
/// Free traffic never reaches Firestore except the one-time legacy import or
/// a Premium→Free download. Premium reads go through Firestore persistence.
class TaskStorageRouter {
  TaskStorageRouter({
    required this.uid,
    required this.profileId,
    required this.openLocal,
    this.cloud,
    required this.isPremium,
    required this.modeStore,
    this.confirmPremium,
    this.onModeChanged,
  });

  final String uid;
  final String profileId;
  final Future<LocalTaskCollection> Function() openLocal;
  final TaskCollection? cloud;
  final PremiumLookup isPremium;
  final TaskStorageModeStore modeStore;
  final Future<bool> Function()? confirmPremium;
  final void Function(TaskStorageMode mode)? onModeChanged;

  LocalTaskCollection? _local;
  TaskCollection? _active;
  bool? _lastPremium;
  Future<TaskCollection>? _inFlight;

  Future<LocalTaskCollection> _localCollection() async =>
      _local ??= await openLocal();

  Future<TaskCollection> resolve() {
    final premium = isPremium();
    if (_active != null && _lastPremium == premium && _inFlight == null) {
      return Future.value(_active);
    }
    return _inFlight ??= _resolve().whenComplete(() => _inFlight = null);
  }

  Future<void> refreshCloudCache() async {
    final active = await resolve();
    if (active is FirestoreTaskCollection) {
      await active.hydrateFromServer();
    }
  }

  Future<TaskCollection> _resolve() async {
    var premium = isPremium();
    final mode = await modeStore.load(uid: uid, profileId: profileId);
    final cloud = this.cloud;
    final local = await _localCollection();

    if (premium == null && mode == null && confirmPremium != null) {
      try {
        premium = await confirmPremium!();
      } catch (_) {
        premium = false;
      }
    }
    _lastPremium = premium;

    if (premium == true && cloud != null) {
      if (mode == TaskStorageMode.local || (mode == null && !local.isEmpty)) {
        await migrateLocalToCloud(local: local, cloud: cloud);
      } else if (cloud is FirestoreTaskCollection) {
        await cloud.hydrateFromServer();
      }
      await _persist(TaskStorageMode.cloud);
      _active = cloud;
      return cloud;
    }

    if (premium == false) {
      if (cloud != null && (mode == TaskStorageMode.cloud || mode == null)) {
        final imported = await migrateCloudToLocal(cloud: cloud, local: local);
        if (!imported && mode == TaskStorageMode.cloud) {
          _active = cloud;
          return cloud;
        }
      }
      await _persist(TaskStorageMode.local);
      _active = local;
      return local;
    }

    if (mode == TaskStorageMode.cloud && cloud != null) {
      _active = cloud;
      return cloud;
    }
    _active = local;
    return local;
  }

  Future<void> _persist(TaskStorageMode mode) async {
    await modeStore.save(uid: uid, profileId: profileId, mode: mode);
    onModeChanged?.call(mode);
  }
}

Future<void> migrateLocalToCloud({
  required LocalTaskCollection local,
  required TaskCollection cloud,
}) async {
  final locals = local.documents;
  final remote = await cloud.get(fromServer: true);
  final localIds = locals.keys.toSet();

  var batch = cloud.newBatch();
  var ops = 0;
  Future<void> flush() async {
    if (ops == 0) return;
    await batch.commit();
    batch = cloud.newBatch();
    ops = 0;
  }

  for (final entry in locals.entries) {
    batch.set(cloud.doc(entry.key), localTaskDataToFirestore(entry.value));
    ops++;
    if (ops >= 400) await flush();
  }
  for (final doc in remote.docs) {
    if (localIds.contains(doc.id)) continue;
    batch.delete(cloud.doc(doc.id));
    ops++;
    if (ops >= 400) await flush();
  }
  await flush();
  await local.clearAll();
}

/// Returns false when nothing could be copied (caller should not drop cloud).
Future<bool> migrateCloudToLocal({
  required TaskCollection cloud,
  required LocalTaskCollection local,
}) async {
  try {
    final snapshot = await _downloadCloudTasks(cloud);
    await local.replaceAll({
      for (final doc in snapshot.docs) doc.id: doc.data(),
    });
    return true;
  } catch (error, stack) {
    debugPrint('Task downgrade/import failed: $error\n$stack');
    return false;
  }
}

Future<TaskQuerySnapshot> _downloadCloudTasks(TaskCollection cloud) async {
  try {
    return await cloud.get(fromServer: true);
  } catch (_) {
    return cloud.get(fromServer: false);
  }
}

class RoutedTaskCollection implements TaskCollection {
  RoutedTaskCollection(this._resolve);

  final Future<TaskCollection> Function() _resolve;

  @override
  TaskDocRef doc([String? id]) =>
      RoutedTaskDocRef(_resolve, id ?? generateTaskId());

  @override
  TaskQuery where(
    String field, {
    Object? isEqualTo,
    Object? isLessThan,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Iterable<Object?>? whereIn,
    bool? isNull,
  }) => RoutedTaskQuery(_resolve, [
    TaskFilter(
      field: field,
      isEqualTo: isEqualTo,
      isLessThan: isLessThan,
      isGreaterThan: isGreaterThan,
      isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
      whereIn: whereIn,
      isNull: isNull,
    ),
  ]);

  @override
  Future<TaskQuerySnapshot> get({bool fromServer = false}) async {
    final active = await _resolve();
    return active.get(fromServer: fromServer);
  }

  @override
  TaskWriteBatch newBatch() => RoutedTaskWriteBatch(_resolve);

  @override
  TaskQuery query() => RoutedTaskQuery(_resolve, const []);

  @override
  Future<void> clearAll() async {
    final active = await _resolve();
    await active.clearAll();
  }

  @override
  Future<int> countDocuments() async {
    final active = await _resolve();
    return active.countDocuments();
  }
}

class RoutedTaskQuery implements TaskQuery {
  RoutedTaskQuery(this._resolve, this._filters, {TaskOrder? order, int? limit})
    : _order = order,
      _limit = limit;

  final Future<TaskCollection> Function() _resolve;
  final List<TaskFilter> _filters;
  final TaskOrder? _order;
  final int? _limit;

  @override
  TaskQuery where(
    String field, {
    Object? isEqualTo,
    Object? isLessThan,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Iterable<Object?>? whereIn,
    bool? isNull,
  }) => RoutedTaskQuery(
    _resolve,
    [
      ..._filters,
      TaskFilter(
        field: field,
        isEqualTo: isEqualTo,
        isLessThan: isLessThan,
        isGreaterThan: isGreaterThan,
        isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
        whereIn: whereIn,
        isNull: isNull,
      ),
    ],
    order: _order,
    limit: _limit,
  );

  @override
  TaskQuery orderBy(String field, {bool descending = false}) => RoutedTaskQuery(
    _resolve,
    _filters,
    order: TaskOrder(field, descending: descending),
    limit: _limit,
  );

  @override
  TaskQuery limit(int limit) =>
      RoutedTaskQuery(_resolve, _filters, order: _order, limit: limit);

  Future<TaskQuery> _materialize() async {
    var query = (await _resolve()).query();
    for (final filter in _filters) {
      query = query.where(
        filter.field,
        isEqualTo: filter.isEqualTo,
        isLessThan: filter.isLessThan,
        isGreaterThan: filter.isGreaterThan,
        isGreaterThanOrEqualTo: filter.isGreaterThanOrEqualTo,
        whereIn: filter.whereIn,
        isNull: filter.isNull,
      );
    }
    if (_order != null) {
      query = query.orderBy(_order.field, descending: _order.descending);
    }
    if (_limit != null) query = query.limit(_limit);
    return query;
  }

  @override
  Future<TaskQuerySnapshot> get({bool fromServer = false}) async {
    final query = await _materialize();
    return query.get(fromServer: fromServer);
  }

  @override
  TaskAggregateQuery count() => RoutedTaskAggregateQuery(_materialize);
}

class RoutedTaskAggregateQuery implements TaskAggregateQuery {
  RoutedTaskAggregateQuery(this._materialize);

  final Future<TaskQuery> Function() _materialize;

  @override
  Future<TaskAggregateQuerySnapshot> get() async {
    final query = await _materialize();
    return query.count().get();
  }
}

class RoutedTaskDocRef implements TaskDocRef {
  RoutedTaskDocRef(this._resolve, this.id);

  final Future<TaskCollection> Function() _resolve;

  @override
  final String id;

  Future<TaskDocRef> _ref() async => (await _resolve()).doc(id);

  @override
  Future<TaskDocumentSnapshot> get({bool fromServer = false}) async {
    return (await _ref()).get(fromServer: fromServer);
  }

  @override
  Future<void> set(Map<String, dynamic> data) async {
    await (await _ref()).set(data);
  }

  @override
  Future<void> update(Map<String, dynamic> data) async {
    await (await _ref()).update(data);
  }

  @override
  Future<void> delete() async {
    await (await _ref()).delete();
  }
}

class RoutedTaskWriteBatch implements TaskWriteBatch {
  RoutedTaskWriteBatch(this._resolve);

  final Future<TaskCollection> Function() _resolve;
  final List<_BatchOp> _ops = [];

  @override
  void set(TaskDocRef ref, Map<String, dynamic> data) {
    _ops.add(_BatchOp.set(ref.id, data));
  }

  @override
  void update(TaskDocRef ref, Map<String, dynamic> data) {
    _ops.add(_BatchOp.update(ref.id, data));
  }

  @override
  void delete(TaskDocRef ref) {
    _ops.add(_BatchOp.delete(ref.id));
  }

  @override
  Future<void> commit() async {
    final active = await _resolve();
    var batch = active.newBatch();
    var ops = 0;
    for (final op in _ops) {
      final ref = active.doc(op.id);
      switch (op.type) {
        case _BatchOpType.set:
          batch.set(ref, op.data!);
        case _BatchOpType.update:
          batch.update(ref, op.data!);
        case _BatchOpType.delete:
          batch.delete(ref);
      }
      ops++;
      if (ops >= 400) {
        await batch.commit();
        batch = active.newBatch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
    _ops.clear();
  }
}

enum _BatchOpType { set, update, delete }

class _BatchOp {
  const _BatchOp.set(this.id, this.data) : type = _BatchOpType.set;

  const _BatchOp.update(this.id, this.data) : type = _BatchOpType.update;

  const _BatchOp.delete(this.id) : type = _BatchOpType.delete, data = null;

  final _BatchOpType type;
  final String id;
  final Map<String, dynamic>? data;
}
