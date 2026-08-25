import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:florien/core/models/recurrence.dart';
import 'package:florien/core/repositories/repositories.dart';
import 'package:florien/core/storage/local_task_collection.dart';
import 'package:florien/core/storage/task_collection.dart';
import 'package:florien/core/storage/task_storage_mode.dart';
import 'package:florien/core/storage/task_storage_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    resetLocalTaskMemoryForTest();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'local store serves inbox, timeline, and completion without Firestore',
    () async {
      final store = LocalTaskCollection.memory('repo');
      final repository = TaskRepository(store);

      final inbox = await repository.createTask(
        title: 'Çamaşır',
        isInbox: true,
      );
      expect(inbox.isInbox, isTrue);

      final planned = await repository.createTask(
        title: 'Kahvaltı',
        scheduledAt: DateTime(2026, 8, 25, 9),
        durationMinutes: 20,
      );
      await repository.completeTask(planned.id);

      expect(await repository.getInbox(), hasLength(1));
      final timeline = await repository.getTimeline(DateTime(2026, 8, 25));
      expect(timeline.tasks, hasLength(1));
      expect(timeline.tasks.single.isCompleted, isTrue);

      final counts = await repository.getCompletionCounts(
        DateTime(2026, 8, 25),
      );
      expect(counts.today, 1);
    },
  );

  test('upgrade copies local tasks in a batch and clears Hive', () async {
    final local = LocalTaskCollection.memory('upgrade-local');
    final cloud = LocalTaskCollection.memory('upgrade-cloud');
    final repository = TaskRepository(local);
    final created = await repository.createTask(
      title: 'Yerel görev',
      isInbox: true,
    );

    await migrateLocalToCloud(local: local, cloud: cloud);

    expect(local.isEmpty, isTrue);
    expect(cloud.documents.containsKey(created.id), isTrue);
    expect(cloud.documents[created.id]?['title'], 'Yerel görev');
  });

  test('downgrade copies cloud tasks into local storage', () async {
    final local = LocalTaskCollection.memory('down-local');
    final cloud = LocalTaskCollection.memory('down-cloud');
    await cloud.put('cloud-1', {
      'title': 'Bulut görevi',
      'color': '#4F52B2',
      'icon': 'task',
      'durationMinutes': 30,
      'status': 'PENDING',
      'sortOrder': 0,
      'isInbox': true,
      'createdAt': DateTime.utc(2026, 8, 25).toIso8601String(),
      'updatedAt': DateTime.utc(2026, 8, 25).toIso8601String(),
    });

    final imported = await migrateCloudToLocal(cloud: cloud, local: local);
    expect(imported, isTrue);
    expect(local.documents['cloud-1']?['title'], 'Bulut görevi');
  });

  test('router stays on local for free users and never opens cloud', () async {
    final local = LocalTaskCollection.memory('free-local');
    var cloudReads = 0;
    final cloud = _CountingCollection(
      LocalTaskCollection.memory('free-cloud'),
      onGet: () => cloudReads++,
    );
    await local.put('local-1', {
      'title': 'Sadece cihaz',
      'status': 'PENDING',
      'sortOrder': 0,
      'isInbox': true,
      'color': '#4F52B2',
      'icon': 'task',
      'durationMinutes': 15,
    });

    final router = TaskStorageRouter(
      uid: 'user-1',
      profileId: 'primary',
      openLocal: () async => local,
      cloud: cloud,
      isPremium: () => false,
      modeStore: TaskStorageModeStore(),
    );
    await TaskStorageModeStore().save(
      uid: 'user-1',
      profileId: 'primary',
      mode: TaskStorageMode.local,
    );

    final active = await router.resolve();
    expect(identical(active, local), isTrue);
    expect(cloudReads, 0);
    expect((await active.get()).docs.single.id, 'local-1');
  });

  test('router upgrades local tasks when premium becomes active', () async {
    final local = LocalTaskCollection.memory('prem-local');
    final cloud = LocalTaskCollection.memory('prem-cloud');
    await local.put('task-1', {
      'title': 'Taşınacak',
      'status': 'PENDING',
      'sortOrder': 0,
      'isInbox': true,
      'color': '#4F52B2',
      'icon': 'task',
      'durationMinutes': 15,
    });
    await TaskStorageModeStore().save(
      uid: 'user-2',
      profileId: 'primary',
      mode: TaskStorageMode.local,
    );

    var premium = false;
    final router = TaskStorageRouter(
      uid: 'user-2',
      profileId: 'primary',
      openLocal: () async => local,
      cloud: cloud,
      isPremium: () => premium,
      modeStore: TaskStorageModeStore(),
    );

    expect(identical(await router.resolve(), local), isTrue);

    premium = true;
    final active = await router.resolve();
    expect(identical(active, cloud), isTrue);
    expect(local.isEmpty, isTrue);
    expect(cloud.documents['task-1']?['title'], 'Taşınacak');
    expect(
      await TaskStorageModeStore().load(uid: 'user-2', profileId: 'primary'),
      TaskStorageMode.cloud,
    );
  });

  test(
    'local queries compare Timestamp filters against stored ISO dates',
    () async {
      final store = LocalTaskCollection.memory('query');
      final day = DateTime.utc(2026, 8, 25, 8);
      await store.put('a', {
        'title': 'Sabah',
        'scheduledAt': day.toIso8601String(),
        'status': 'PENDING',
        'isInbox': false,
        'parentTaskId': null,
      });
      final snapshot = await store
          .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(day))
          .where(
            'scheduledAt',
            isLessThan: Timestamp.fromDate(day.add(const Duration(days: 1))),
          )
          .get();
      expect(snapshot.docs, hasLength(1));
    },
  );

  test('recurring create stays on the local backend', () async {
    final repository = TaskRepository(LocalTaskCollection.memory('recur'));
    final task = await repository.createTask(
      title: 'İlaç',
      scheduledAt: DateTime(2026, 8, 25, 8),
      recurrence: const RecurrenceSelection(type: RecurrenceType.daily),
    );
    expect(task.recurrenceSeriesId, task.id);
    final all = await repository.getFrequentlyUsedTasks(limit: 20);
    expect(all, isNotEmpty);
  });
}

class _CountingCollection implements TaskCollection {
  _CountingCollection(this._inner, {this.onGet});

  final LocalTaskCollection _inner;
  final void Function()? onGet;

  @override
  Future<void> clearAll() => _inner.clearAll();

  @override
  Future<int> countDocuments() => _inner.countDocuments();

  @override
  TaskDocRef doc([String? id]) => _inner.doc(id);

  @override
  Future<TaskQuerySnapshot> get({bool fromServer = false}) {
    onGet?.call();
    return _inner.get(fromServer: fromServer);
  }

  @override
  TaskWriteBatch newBatch() => _inner.newBatch();

  @override
  TaskQuery query() => _inner.query();

  @override
  TaskQuery where(
    String field, {
    Object? isEqualTo,
    Object? isLessThan,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Iterable<Object?>? whereIn,
    bool? isNull,
  }) {
    onGet?.call();
    return _inner.where(
      field,
      isEqualTo: isEqualTo,
      isLessThan: isLessThan,
      isGreaterThan: isGreaterThan,
      isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
      whereIn: whereIn,
      isNull: isNull,
    );
  }
}
