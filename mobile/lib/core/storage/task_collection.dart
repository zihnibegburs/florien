import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared document/query surface for local (Hive) and Firestore task backends.
///
/// Free users never touch Firestore; Premium users go through Firestore with
/// cache-first reads. [TaskRepository] talks only to this API.
abstract class TaskCollection {
  TaskDocRef doc([String? id]);

  TaskQuery where(
    String field, {
    Object? isEqualTo,
    Object? isLessThan,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Iterable<Object?>? whereIn,
    bool? isNull,
  });

  Future<TaskQuerySnapshot> get({bool fromServer = false});

  TaskWriteBatch newBatch();

  TaskQuery query();

  Future<void> clearAll();

  Future<int> countDocuments();
}

abstract class TaskQuery {
  TaskQuery where(
    String field, {
    Object? isEqualTo,
    Object? isLessThan,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Iterable<Object?>? whereIn,
    bool? isNull,
  });

  TaskQuery orderBy(String field, {bool descending = false});

  TaskQuery limit(int limit);

  Future<TaskQuerySnapshot> get({bool fromServer = false});

  TaskAggregateQuery count();
}

abstract class TaskAggregateQuery {
  Future<TaskAggregateQuerySnapshot> get();
}

class TaskAggregateQuerySnapshot {
  const TaskAggregateQuerySnapshot(this.count);

  final int? count;
}

abstract class TaskDocRef {
  String get id;

  Future<TaskDocumentSnapshot> get({bool fromServer = false});

  Future<void> set(Map<String, dynamic> data);

  Future<void> update(Map<String, dynamic> data);

  Future<void> delete();
}

abstract class TaskWriteBatch {
  void set(TaskDocRef ref, Map<String, dynamic> data);

  void update(TaskDocRef ref, Map<String, dynamic> data);

  void delete(TaskDocRef ref);

  Future<void> commit();
}

class TaskQuerySnapshot {
  const TaskQuerySnapshot(this.docs);

  final List<TaskQueryDocument> docs;

  bool get isEmpty => docs.isEmpty;

  bool get isNotEmpty => docs.isNotEmpty;
}

class TaskQueryDocument {
  const TaskQueryDocument({
    required this.id,
    required Map<String, dynamic> data,
    required this.reference,
  }) : _data = data;

  final String id;
  final Map<String, dynamic> _data;
  final TaskDocRef reference;

  Map<String, dynamic> data() => Map<String, dynamic>.from(_data);
}

class TaskDocumentSnapshot {
  const TaskDocumentSnapshot({required this.id, Map<String, dynamic>? data})
    : _data = data;

  final String id;
  final Map<String, dynamic>? _data;

  bool get exists => _data != null;

  Map<String, dynamic>? data() =>
      _data == null ? null : Map<String, dynamic>.from(_data);
}

class TaskFilter {
  const TaskFilter({
    required this.field,
    this.isEqualTo,
    this.isLessThan,
    this.isGreaterThan,
    this.isGreaterThanOrEqualTo,
    this.whereIn,
    this.isNull,
  });

  final String field;
  final Object? isEqualTo;
  final Object? isLessThan;
  final Object? isGreaterThan;
  final Object? isGreaterThanOrEqualTo;
  final Iterable<Object?>? whereIn;
  final bool? isNull;
}

class TaskOrder {
  const TaskOrder(this.field, {this.descending = false});

  final String field;
  final bool descending;
}

const _idAlphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

final _idRandom = Random.secure();

/// Firestore-style 20-character document ids so upgrades keep stable keys.
String generateTaskId() {
  final buffer = StringBuffer();
  for (var i = 0; i < 20; i++) {
    buffer.write(_idAlphabet[_idRandom.nextInt(_idAlphabet.length)]);
  }
  return buffer.toString();
}

const taskDateFields = {
  'scheduledAt',
  'startedAt',
  'completedAt',
  'alarmAt',
  'createdAt',
  'updatedAt',
};

int? comparableTaskValue(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.millisecondsSinceEpoch;
  if (value is DateTime) return value.toUtc().millisecondsSinceEpoch;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc().millisecondsSinceEpoch;
  }
  if (value is num) return value.toInt();
  return null;
}

bool matchesTaskFilter(Map<String, dynamic> data, TaskFilter filter) {
  final raw = data[filter.field];
  if (filter.isNull != null) {
    return filter.isNull! ? raw == null : raw != null;
  }
  if (filter.whereIn != null) {
    return filter.whereIn!.any((candidate) => _valuesEqual(raw, candidate));
  }
  if (filter.isEqualTo != null) {
    return _valuesEqual(raw, filter.isEqualTo);
  }
  final left = comparableTaskValue(raw);
  if (filter.isLessThan != null) {
    final right = comparableTaskValue(filter.isLessThan);
    if (left == null || right == null) return false;
    return left < right;
  }
  if (filter.isGreaterThan != null) {
    final right = comparableTaskValue(filter.isGreaterThan);
    if (left == null || right == null) return false;
    return left > right;
  }
  if (filter.isGreaterThanOrEqualTo != null) {
    final right = comparableTaskValue(filter.isGreaterThanOrEqualTo);
    if (left == null || right == null) return false;
    return left >= right;
  }
  return true;
}

int compareTaskValues(Object? a, Object? b) {
  final left = comparableTaskValue(a);
  final right = comparableTaskValue(b);
  if (left != null && right != null) return left.compareTo(right);
  return '${a ?? ''}'.compareTo('${b ?? ''}');
}

bool _valuesEqual(Object? left, Object? right) {
  if (identical(left, right) || left == right) return true;
  final leftEpoch = comparableTaskValue(left);
  final rightEpoch = comparableTaskValue(right);
  if (leftEpoch != null && rightEpoch != null) return leftEpoch == rightEpoch;
  return false;
}

List<MapEntry<String, Map<String, dynamic>>> applyTaskQuery({
  required Map<String, Map<String, dynamic>> docs,
  required List<TaskFilter> filters,
  TaskOrder? order,
  int? limit,
}) {
  var entries = docs.entries.where((entry) {
    return filters.every((filter) => matchesTaskFilter(entry.value, filter));
  }).toList();
  if (order != null) {
    entries.sort((a, b) {
      final compared = compareTaskValues(
        a.value[order.field],
        b.value[order.field],
      );
      return order.descending ? -compared : compared;
    });
  }
  if (limit != null && entries.length > limit) {
    entries = entries.sublist(0, limit);
  }
  return entries;
}
