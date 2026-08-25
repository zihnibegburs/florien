import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:florien/core/storage/task_collection.dart';

class FirestoreTaskCollection implements TaskCollection {
  FirestoreTaskCollection(this._col);

  final CollectionReference<Map<String, dynamic>> _col;

  /// One billed collection read to warm Firestore persistence for this session.
  Future<void> hydrateFromServer() async {
    try {
      await _col.get(const GetOptions(source: Source.server));
    } catch (_) {}
  }

  @override
  TaskDocRef doc([String? id]) =>
      FirestoreTaskDocRef(id == null ? _col.doc() : _col.doc(id));

  @override
  TaskQuery where(
    String field, {
    Object? isEqualTo,
    Object? isLessThan,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Iterable<Object?>? whereIn,
    bool? isNull,
  }) => FirestoreTaskQuery(
    _applyWhere(
      _col,
      field,
      isEqualTo: isEqualTo,
      isLessThan: isLessThan,
      isGreaterThan: isGreaterThan,
      isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
      whereIn: whereIn,
      isNull: isNull,
    ),
  );

  @override
  Future<TaskQuerySnapshot> get({bool fromServer = false}) async {
    final snapshot = await _getQuery(_col, fromServer: fromServer);
    return _wrapQuerySnapshot(snapshot);
  }

  @override
  TaskWriteBatch newBatch() => FirestoreTaskWriteBatch(_col.firestore);

  @override
  TaskQuery query() => FirestoreTaskQuery(_col);

  @override
  Future<void> clearAll() async {
    var batch = _col.firestore.batch();
    var ops = 0;
    final snapshot = await _col.get(const GetOptions(source: Source.server));
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      ops++;
      if (ops >= 400) {
        await batch.commit();
        batch = _col.firestore.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
  }

  @override
  Future<int> countDocuments() async {
    final snapshot = await _getQuery(_col, fromServer: false);
    return snapshot.docs.length;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getRaw({
    bool fromServer = false,
  }) => _getQuery(_col, fromServer: fromServer);
}

class FirestoreTaskQuery implements TaskQuery {
  FirestoreTaskQuery(this._query);

  final Query<Map<String, dynamic>> _query;

  @override
  TaskQuery where(
    String field, {
    Object? isEqualTo,
    Object? isLessThan,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Iterable<Object?>? whereIn,
    bool? isNull,
  }) => FirestoreTaskQuery(
    _applyWhere(
      _query,
      field,
      isEqualTo: isEqualTo,
      isLessThan: isLessThan,
      isGreaterThan: isGreaterThan,
      isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
      whereIn: whereIn,
      isNull: isNull,
    ),
  );

  @override
  TaskQuery orderBy(String field, {bool descending = false}) =>
      FirestoreTaskQuery(_query.orderBy(field, descending: descending));

  @override
  TaskQuery limit(int limit) => FirestoreTaskQuery(_query.limit(limit));

  @override
  Future<TaskQuerySnapshot> get({bool fromServer = false}) async {
    final snapshot = await _getQuery(_query, fromServer: fromServer);
    return _wrapQuerySnapshot(snapshot);
  }

  @override
  TaskAggregateQuery count() => FirestoreTaskAggregateQuery(_query);
}

class FirestoreTaskAggregateQuery implements TaskAggregateQuery {
  FirestoreTaskAggregateQuery(this._query);

  final Query<Map<String, dynamic>> _query;

  @override
  Future<TaskAggregateQuerySnapshot> get() async {
    // Prefer the persistence cache over a billed aggregation query.
    try {
      final cached = await _query.get(const GetOptions(source: Source.cache));
      return TaskAggregateQuerySnapshot(cached.docs.length);
    } on FirebaseException {
      final snapshot = await _query.get(
        const GetOptions(source: Source.server),
      );
      return TaskAggregateQuerySnapshot(snapshot.docs.length);
    }
  }
}

class FirestoreTaskDocRef implements TaskDocRef {
  FirestoreTaskDocRef(this.reference);

  final DocumentReference<Map<String, dynamic>> reference;

  @override
  String get id => reference.id;

  @override
  Future<TaskDocumentSnapshot> get({bool fromServer = false}) async {
    final snapshot = await _getDocument(reference, fromServer: fromServer);
    return TaskDocumentSnapshot(id: snapshot.id, data: snapshot.data());
  }

  @override
  Future<void> set(Map<String, dynamic> data) => reference.set(data);

  @override
  Future<void> update(Map<String, dynamic> data) => reference.update(data);

  @override
  Future<void> delete() => reference.delete();
}

class FirestoreTaskWriteBatch implements TaskWriteBatch {
  FirestoreTaskWriteBatch(FirebaseFirestore db) : _batch = db.batch();

  final WriteBatch _batch;

  DocumentReference<Map<String, dynamic>> _ref(TaskDocRef ref) {
    if (ref is FirestoreTaskDocRef) return ref.reference;
    throw StateError('Firestore batch requires Firestore document refs');
  }

  @override
  void set(TaskDocRef ref, Map<String, dynamic> data) {
    _batch.set(_ref(ref), data);
  }

  @override
  void update(TaskDocRef ref, Map<String, dynamic> data) {
    _batch.update(_ref(ref), data);
  }

  @override
  void delete(TaskDocRef ref) {
    _batch.delete(_ref(ref));
  }

  @override
  Future<void> commit() => _batch.commit();
}

Query<Map<String, dynamic>> _applyWhere(
  Query<Map<String, dynamic>> query,
  String field, {
  Object? isEqualTo,
  Object? isLessThan,
  Object? isGreaterThan,
  Object? isGreaterThanOrEqualTo,
  Iterable<Object?>? whereIn,
  bool? isNull,
}) {
  if (isEqualTo != null) return query.where(field, isEqualTo: isEqualTo);
  if (isLessThan != null) return query.where(field, isLessThan: isLessThan);
  if (isGreaterThan != null) {
    return query.where(field, isGreaterThan: isGreaterThan);
  }
  if (isGreaterThanOrEqualTo != null) {
    return query.where(field, isGreaterThanOrEqualTo: isGreaterThanOrEqualTo);
  }
  if (whereIn != null) {
    return query.where(field, whereIn: whereIn.toList());
  }
  if (isNull != null) return query.where(field, isNull: isNull);
  return query;
}

Future<QuerySnapshot<Map<String, dynamic>>> _getQuery(
  Query<Map<String, dynamic>> query, {
  required bool fromServer,
}) async {
  if (fromServer) {
    return query.get(const GetOptions(source: Source.server));
  }
  try {
    return await query.get(const GetOptions(source: Source.cache));
  } on FirebaseException {
    return query.get(const GetOptions(source: Source.server));
  }
}

Future<DocumentSnapshot<Map<String, dynamic>>> _getDocument(
  DocumentReference<Map<String, dynamic>> reference, {
  required bool fromServer,
}) async {
  if (fromServer) {
    return reference.get(const GetOptions(source: Source.server));
  }
  try {
    return await reference.get(const GetOptions(source: Source.cache));
  } on FirebaseException {
    return reference.get(const GetOptions(source: Source.server));
  }
}

TaskQuerySnapshot _wrapQuerySnapshot(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) {
  return TaskQuerySnapshot([
    for (final doc in snapshot.docs)
      TaskQueryDocument(
        id: doc.id,
        data: doc.data(),
        reference: FirestoreTaskDocRef(doc.reference),
      ),
  ]);
}
