import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:florien/core/storage/task_collection.dart';
import 'package:hive_flutter/hive_flutter.dart';

const _hiveBoxPrefix = 'florien_tasks_v1_';

final Map<String, Map<String, Map<String, dynamic>>> _memoryBoxes = {};

bool hiveTaskStoreReady = false;

Future<void> initLocalTaskStore() async {
  if (hiveTaskStoreReady) return;
  await Hive.initFlutter();
  hiveTaskStoreReady = true;
}

void resetLocalTaskMemoryForTest() => _memoryBoxes.clear();

String localTaskBoxName(String uid, String profileId) =>
    '$_hiveBoxPrefix${uid}_$profileId';

class LocalTaskCollection implements TaskCollection {
  LocalTaskCollection._({
    required this.boxName,
    required Map<String, Map<String, dynamic>> docs,
    Box<dynamic>? box,
  }) : _docs = docs,
       _box = box;

  factory LocalTaskCollection.memory([String name = 'memory']) {
    return LocalTaskCollection._(
      boxName: name,
      docs: _memoryBoxes.putIfAbsent(
        name,
        () => <String, Map<String, dynamic>>{},
      ),
    );
  }

  static Future<LocalTaskCollection> open({
    required String uid,
    required String profileId,
  }) async {
    final name = localTaskBoxName(uid, profileId);
    if (!hiveTaskStoreReady) {
      return LocalTaskCollection.memory(name);
    }
    try {
      final box = Hive.isBoxOpen(name)
          ? Hive.box<dynamic>(name)
          : await Hive.openBox<dynamic>(name);
      final docs = <String, Map<String, dynamic>>{};
      for (final key in box.keys) {
        final value = box.get(key);
        if (value is Map) {
          docs[key.toString()] = _stringifyKeys(value);
        }
      }
      return LocalTaskCollection._(boxName: name, docs: docs, box: box);
    } catch (_) {
      return LocalTaskCollection.memory(name);
    }
  }

  final String boxName;
  final Map<String, Map<String, dynamic>> _docs;
  final Box<dynamic>? _box;

  Map<String, Map<String, dynamic>> get documents => {
    for (final entry in _docs.entries)
      entry.key: Map<String, dynamic>.from(entry.value),
  };

  bool get isEmpty => _docs.isEmpty;

  @override
  TaskDocRef doc([String? id]) => LocalTaskDocRef(this, id ?? generateTaskId());

  @override
  TaskQuery where(
    String field, {
    Object? isEqualTo,
    Object? isLessThan,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Iterable<Object?>? whereIn,
    bool? isNull,
  }) => LocalTaskQuery(this, [
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
    return _snapshotFor(_docs.entries);
  }

  @override
  TaskWriteBatch newBatch() => LocalTaskWriteBatch(this);

  @override
  TaskQuery query() => LocalTaskQuery(this, const []);

  @override
  Future<void> clearAll() async {
    _docs.clear();
    await _box?.clear();
  }

  @override
  Future<int> countDocuments() async => _docs.length;

  Future<void> replaceAll(Map<String, Map<String, dynamic>> docs) async {
    _docs
      ..clear()
      ..addAll({
        for (final entry in docs.entries)
          entry.key: normalizeLocalTaskData(entry.value),
      });
    final box = _box;
    if (box == null) return;
    await box.clear();
    for (final entry in _docs.entries) {
      await box.put(entry.key, entry.value);
    }
  }

  Future<void> put(String id, Map<String, dynamic> data) async {
    final normalized = normalizeLocalTaskData(data);
    _docs[id] = normalized;
    await _box?.put(id, normalized);
  }

  Future<void> patch(String id, Map<String, dynamic> data) async {
    final current = _docs[id];
    if (current == null) {
      throw StateError('Task not found');
    }
    final merged = normalizeLocalTaskData({...current, ...data});
    _docs[id] = merged;
    await _box?.put(id, merged);
  }

  Future<void> remove(String id) async {
    _docs.remove(id);
    await _box?.delete(id);
  }

  TaskQuerySnapshot snapshot(
    List<TaskFilter> filters, {
    TaskOrder? order,
    int? limit,
  }) {
    final entries = applyTaskQuery(
      docs: _docs,
      filters: filters,
      order: order,
      limit: limit,
    );
    return _snapshotFor(entries);
  }

  TaskQuerySnapshot _snapshotFor(
    Iterable<MapEntry<String, Map<String, dynamic>>> entries,
  ) {
    return TaskQuerySnapshot([
      for (final entry in entries)
        TaskQueryDocument(
          id: entry.key,
          data: decodeLocalTaskData(entry.value),
          reference: LocalTaskDocRef(this, entry.key),
        ),
    ]);
  }
}

class LocalTaskQuery implements TaskQuery {
  LocalTaskQuery(
    this._collection,
    this._filters, {
    TaskOrder? order,
    int? limit,
  }) : _order = order,
       _limit = limit;

  final LocalTaskCollection _collection;
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
  }) => LocalTaskQuery(
    _collection,
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
  TaskQuery orderBy(String field, {bool descending = false}) => LocalTaskQuery(
    _collection,
    _filters,
    order: TaskOrder(field, descending: descending),
    limit: _limit,
  );

  @override
  TaskQuery limit(int limit) =>
      LocalTaskQuery(_collection, _filters, order: _order, limit: limit);

  @override
  Future<TaskQuerySnapshot> get({bool fromServer = false}) async {
    return _collection.snapshot(_filters, order: _order, limit: _limit);
  }

  @override
  TaskAggregateQuery count() => LocalTaskAggregateQuery(this);
}

class LocalTaskAggregateQuery implements TaskAggregateQuery {
  LocalTaskAggregateQuery(this._query);

  final LocalTaskQuery _query;

  @override
  Future<TaskAggregateQuerySnapshot> get() async {
    final snapshot = await _query.get();
    return TaskAggregateQuerySnapshot(snapshot.docs.length);
  }
}

class LocalTaskDocRef implements TaskDocRef {
  LocalTaskDocRef(this._collection, this.id);

  final LocalTaskCollection _collection;

  @override
  final String id;

  @override
  Future<TaskDocumentSnapshot> get({bool fromServer = false}) async {
    final data = _collection._docs[id];
    return TaskDocumentSnapshot(
      id: id,
      data: data == null ? null : decodeLocalTaskData(data),
    );
  }

  @override
  Future<void> set(Map<String, dynamic> data) => _collection.put(id, data);

  @override
  Future<void> update(Map<String, dynamic> data) => _collection.patch(id, data);

  @override
  Future<void> delete() => _collection.remove(id);
}

class LocalTaskWriteBatch implements TaskWriteBatch {
  LocalTaskWriteBatch(this._collection);

  final LocalTaskCollection _collection;
  final List<Future<void> Function()> _ops = [];

  @override
  void set(TaskDocRef ref, Map<String, dynamic> data) {
    _ops.add(() => _collection.put(ref.id, data));
  }

  @override
  void update(TaskDocRef ref, Map<String, dynamic> data) {
    _ops.add(() => _collection.patch(ref.id, data));
  }

  @override
  void delete(TaskDocRef ref) {
    _ops.add(() => _collection.remove(ref.id));
  }

  @override
  Future<void> commit() async {
    for (final op in _ops) {
      await op();
    }
    _ops.clear();
  }
}

Map<String, dynamic> normalizeLocalTaskData(Map<String, dynamic> data) {
  return {
    for (final entry in data.entries)
      entry.key: _normalizeLocalValue(entry.value),
  };
}

Map<String, dynamic> decodeLocalTaskData(Map<String, dynamic> data) {
  return {
    for (final entry in data.entries)
      entry.key: _decodeLocalValue(entry.key, entry.value),
  };
}

dynamic _decodeLocalValue(String key, dynamic value) {
  if (value == null) return null;
  if (taskDateFields.contains(key) && value is String) {
    return DateTime.tryParse(value)?.toLocal() ?? value;
  }
  return value;
}

Map<String, dynamic> localTaskDataToFirestore(Map<String, dynamic> data) {
  return {
    for (final entry in data.entries)
      entry.key: _toFirestoreValue(entry.key, entry.value),
  };
}

dynamic _normalizeLocalValue(dynamic value) {
  if (value is FieldValue) {
    return DateTime.now().toUtc().toIso8601String();
  }
  if (value is Timestamp) {
    return value.toDate().toUtc().toIso8601String();
  }
  if (value is DateTime) {
    return value.toUtc().toIso8601String();
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): _normalizeLocalValue(entry.value),
    };
  }
  if (value is Iterable && value is! String) {
    return [for (final item in value) _normalizeLocalValue(item)];
  }
  return value;
}

dynamic _toFirestoreValue(String key, dynamic value) {
  if (value == null) return null;
  if (taskDateFields.contains(key) && value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return Timestamp.fromDate(parsed.toUtc());
  }
  if (value is DateTime) return Timestamp.fromDate(value.toUtc());
  return value;
}

Map<String, dynamic> _stringifyKeys(Map<dynamic, dynamic> value) {
  return {
    for (final entry in value.entries)
      entry.key.toString(): entry.value is Map
          ? _stringifyKeys(Map<dynamic, dynamic>.from(entry.value as Map))
          : entry.value,
  };
}
