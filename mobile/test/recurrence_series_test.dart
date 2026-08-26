import 'package:florien/core/models/models.dart';
import 'package:florien/core/models/recurrence.dart';
import 'package:florien/core/repositories/repositories.dart';
import 'package:florien/core/storage/local_task_collection.dart';
import 'package:florien/core/utils/recurrence_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(resetLocalTaskMemoryForTest);

  test(
    'daily series is visible on a far-away date without extra copies',
    () async {
      final repository = TaskRepository(
        LocalTaskCollection.memory('series-far'),
      );
      final created = await repository.createTask(
        title: 'İlaç',
        scheduledAt: DateTime(2026, 8, 26, 8),
        recurrence: const RecurrenceSelection(type: RecurrenceType.daily),
        dayPeriod: DayPeriod.morning,
      );

      expect(created.recurrenceSeriesId, created.id);
      expect(created.isSeriesMaster, isTrue);

      final all = await LocalTaskCollection.memory('series-far').get();
      expect(all.docs, hasLength(1));

      final far = await repository.getTimeline(DateTime(2030, 3, 12));
      expect(far.tasks, hasLength(1));
      expect(far.tasks.single.title, 'İlaç');
      expect(far.tasks.single.isVirtualOccurrence, isTrue);
      expect(far.tasks.single.recurrenceType, RecurrenceType.daily);
    },
  );

  test(
    'this / future / all update and delete keep a short series chain',
    () async {
      final store = LocalTaskCollection.memory('series-scope');
      final repository = TaskRepository(store);
      final created = await repository.createTask(
        title: 'Koşu',
        scheduledAt: DateTime(2026, 8, 26, 8),
        recurrence: const RecurrenceSelection(type: RecurrenceType.daily),
        dayPeriod: DayPeriod.morning,
      );
      final weekLater = RecurrenceOccurrence.id(
        created.id,
        DateTime(2026, 9, 2),
      );

      await repository.updateRecurringTask(
        id: weekLater,
        scope: RecurrenceScope.future,
        title: 'Akşam koşusu',
        dayPeriod: DayPeriod.evening,
        scheduledAt: DateTime(2026, 9, 2, 19),
      );

      final firstDay = await repository.getTimeline(DateTime(2026, 8, 27));
      expect(firstDay.tasks.single.title, 'Koşu');
      expect(firstDay.tasks.single.dayPeriod, DayPeriod.morning);

      final splitDay = await repository.getTimeline(DateTime(2026, 9, 2));
      expect(splitDay.tasks.single.title, 'Akşam koşusu');
      expect(splitDay.tasks.single.dayPeriod, DayPeriod.evening);

      await repository.updateRecurringTask(
        id: splitDay.tasks.single.id,
        scope: RecurrenceScope.future,
        title: 'Gece koşusu',
      );
      final again = await repository.getTimeline(DateTime(2026, 9, 2));
      expect(again.tasks.single.title, 'Gece koşusu');

      await repository.completeTask(again.tasks.single.id);
      final completed = await repository.getTimeline(DateTime(2026, 9, 2));
      expect(completed.tasks.single.isCompleted, isTrue);
      expect(completed.tasks.single.isVirtualOccurrence, isFalse);

      await repository.deleteTask(
        RecurrenceOccurrence.id(created.id, DateTime(2026, 8, 28)),
        scope: RecurrenceScope.thisOccurrence,
      );
      final skipped = await repository.getTimeline(DateTime(2026, 8, 28));
      expect(skipped.tasks, isEmpty);
      expect(
        (await repository.getTimeline(DateTime(2026, 8, 29))).tasks,
        isNotEmpty,
      );
    },
  );

  test(
    'this occurrence title stays on that day and does not spawn a series',
    () async {
      final store = LocalTaskCollection.memory('series-this-title');
      final repository = TaskRepository(store);
      final created = await repository.createTask(
        title: 'İlaç',
        scheduledAt: DateTime(2026, 8, 26, 8),
        recurrence: const RecurrenceSelection(type: RecurrenceType.daily),
        dayPeriod: DayPeriod.morning,
      );
      final todayId = RecurrenceOccurrence.id(
        created.id,
        DateTime(2026, 8, 26),
      );

      await repository.updateRecurringTask(
        id: todayId,
        scope: RecurrenceScope.thisOccurrence,
        title: 'Vitamin',
        dayPeriod: DayPeriod.morning,
        scheduledAt: DateTime(2026, 8, 26, 8),
        recurrence: const RecurrenceSelection(type: RecurrenceType.daily),
      );

      final docs = await store.get();
      expect(docs.docs, hasLength(2));
      final override = docs.docs
          .map((doc) => TaskModel.fromFirestore(doc.id, doc.data()))
          .firstWhere((task) => task.id != created.id);
      expect(override.title, 'Vitamin');
      expect(override.isSeriesMaster, isFalse);
      expect(override.recurrenceType, RecurrenceType.none);
      expect(override.recurrenceException, RecurrenceExceptionKind.override);
      expect(override.occurrenceDate, '2026-08-26');
      expect(override.recurrenceOwnedFields, contains('title'));
      expect(override.recurrenceOwnedFields, isNot(contains('dayPeriod')));
      expect(override.recurrenceOwnedFields, isNot(contains('scheduledAt')));

      final today = await repository.getTimeline(DateTime(2026, 8, 26));
      expect(today.tasks, hasLength(1));
      expect(today.tasks.single.title, 'Vitamin');
      expect(today.tasks.single.isVirtualOccurrence, isFalse);

      final tomorrow = await repository.getTimeline(DateTime(2026, 8, 27));
      expect(tomorrow.tasks, hasLength(1));
      expect(tomorrow.tasks.single.title, 'İlaç');
      expect(tomorrow.tasks.single.isVirtualOccurrence, isTrue);
    },
  );

  test('series breakdown writes the same subtasks onto every day', () async {
    final store = LocalTaskCollection.memory('series-subtasks');
    final repository = TaskRepository(store);
    final created = await repository.createTask(
      title: 'Koşu',
      scheduledAt: DateTime(2026, 8, 26, 8),
      recurrence: const RecurrenceSelection(type: RecurrenceType.daily),
      dayPeriod: DayPeriod.morning,
    );
    await repository.replaceSubtasksForSeries(
      id: RecurrenceOccurrence.id(created.id, DateTime(2026, 8, 28)),
      titles: const ['Isınma', 'Koşu'],
    );

    final startDay = await repository.getTimeline(DateTime(2026, 8, 26));
    expect(startDay.tasks, hasLength(1));
    expect(startDay.tasks.single.subtasks.map((subtask) => subtask.title), [
      'Isınma',
      'Koşu',
    ]);

    final nextDay = await repository.getTimeline(DateTime(2026, 8, 27));
    expect(nextDay.tasks.single.subtasks.map((subtask) => subtask.title), [
      'Isınma',
      'Koşu',
    ]);

    await repository.updateRecurringTask(
      id: RecurrenceOccurrence.id(created.id, DateTime(2026, 8, 26)),
      scope: RecurrenceScope.thisOccurrence,
      title: 'Sabah koşusu',
    );
    await repository.replaceSubtasksForSeries(
      id: RecurrenceOccurrence.id(created.id, DateTime(2026, 8, 27)),
      titles: const ['Isınma', 'Koşu', 'Esneme'],
    );

    final renamed = await repository.getTimeline(DateTime(2026, 8, 26));
    expect(renamed.tasks.single.title, 'Sabah koşusu');
    expect(renamed.tasks.single.subtasks.map((subtask) => subtask.title), [
      'Isınma',
      'Koşu',
      'Esneme',
    ]);
  });

  test('all group move also moves a renamed occurrence', () async {
    final store = LocalTaskCollection.memory('series-group-all');
    final repository = TaskRepository(store);
    final created = await repository.createTask(
      title: 'Koşu',
      scheduledAt: DateTime(2026, 8, 26, 19),
      recurrence: const RecurrenceSelection(type: RecurrenceType.daily),
      dayPeriod: DayPeriod.evening,
    );
    await repository.updateRecurringTask(
      id: RecurrenceOccurrence.id(created.id, DateTime(2026, 8, 26)),
      scope: RecurrenceScope.thisOccurrence,
      title: 'Sabah koşusu',
    );

    await repository.updateRecurringTask(
      id: RecurrenceOccurrence.id(created.id, DateTime(2026, 8, 27)),
      scope: RecurrenceScope.all,
      dayPeriod: DayPeriod.morning,
      scheduledAt: DateTime(2026, 8, 27, 8),
    );

    final renamed = await repository.getTimeline(DateTime(2026, 8, 26));
    expect(renamed.tasks.single.title, 'Sabah koşusu');
    expect(renamed.tasks.single.dayPeriod, DayPeriod.morning);

    final other = await repository.getTimeline(DateTime(2026, 8, 27));
    expect(other.tasks.single.title, 'Koşu');
    expect(other.tasks.single.dayPeriod, DayPeriod.morning);
  });

  test('this group move of a renamed occurrence stays on that day', () async {
    final store = LocalTaskCollection.memory('series-group-this');
    final repository = TaskRepository(store);
    final created = await repository.createTask(
      title: 'Koşu',
      scheduledAt: DateTime(2026, 8, 26, 19),
      recurrence: const RecurrenceSelection(type: RecurrenceType.daily),
      dayPeriod: DayPeriod.evening,
    );
    await repository.updateRecurringTask(
      id: RecurrenceOccurrence.id(created.id, DateTime(2026, 8, 26)),
      scope: RecurrenceScope.thisOccurrence,
      title: 'Sabah koşusu',
    );

    await repository.updateRecurringTask(
      id: RecurrenceOccurrence.id(created.id, DateTime(2026, 8, 26)),
      scope: RecurrenceScope.thisOccurrence,
      dayPeriod: DayPeriod.morning,
      scheduledAt: DateTime(2026, 8, 26, 8),
    );

    final renamed = await repository.getTimeline(DateTime(2026, 8, 26));
    expect(renamed.tasks.single.title, 'Sabah koşusu');
    expect(renamed.tasks.single.dayPeriod, DayPeriod.morning);
    expect(renamed.tasks.single.hasUniqueOccurrenceTitle, isTrue);

    final other = await repository.getTimeline(DateTime(2026, 8, 27));
    expect(other.tasks.single.title, 'Koşu');
    expect(other.tasks.single.dayPeriod, DayPeriod.evening);
  });

  test('all group move unpins a leaked this-occurrence group', () async {
    final store = LocalTaskCollection.memory('series-group-all-unpin');
    final repository = TaskRepository(store);
    final created = await repository.createTask(
      title: 'Koşu',
      scheduledAt: DateTime(2026, 8, 26, 19),
      recurrence: const RecurrenceSelection(type: RecurrenceType.daily),
      dayPeriod: DayPeriod.evening,
    );
    await repository.updateRecurringTask(
      id: RecurrenceOccurrence.id(created.id, DateTime(2026, 8, 26)),
      scope: RecurrenceScope.thisOccurrence,
      title: 'Sabah koşusu',
    );
    final override = (await store.get()).docs
        .map((doc) => TaskModel.fromFirestore(doc.id, doc.data()))
        .firstWhere((task) => task.id != created.id);
    await store.doc(override.id).update({
      'recurrenceOwnedFields': ['title', 'dayPeriod', 'scheduledAt'],
    });

    await repository.updateRecurringTask(
      id: RecurrenceOccurrence.id(created.id, DateTime(2026, 8, 27)),
      scope: RecurrenceScope.all,
      dayPeriod: DayPeriod.morning,
      scheduledAt: DateTime(2026, 8, 27, 8),
    );

    final renamed = await repository.getTimeline(DateTime(2026, 8, 26));
    expect(renamed.tasks.single.title, 'Sabah koşusu');
    expect(renamed.tasks.single.dayPeriod, DayPeriod.morning);
  });

  test('all title update keeps a this-occurrence name', () async {
    final store = LocalTaskCollection.memory('series-all-keeps-this-title');
    final repository = TaskRepository(store);
    final created = await repository.createTask(
      title: 'Koşu',
      scheduledAt: DateTime(2026, 8, 26, 8),
      recurrence: const RecurrenceSelection(type: RecurrenceType.daily),
      dayPeriod: DayPeriod.morning,
    );
    await repository.updateRecurringTask(
      id: RecurrenceOccurrence.id(created.id, DateTime(2026, 8, 26)),
      scope: RecurrenceScope.thisOccurrence,
      title: 'Sabah koşusu',
    );
    await repository.updateRecurringTask(
      id: RecurrenceOccurrence.id(created.id, DateTime(2026, 8, 27)),
      scope: RecurrenceScope.all,
      title: 'Antrenman',
    );

    expect(
      (await repository.getTimeline(DateTime(2026, 8, 26))).tasks.single.title,
      'Sabah koşusu',
    );
    expect(
      (await repository.getTimeline(DateTime(2026, 8, 27))).tasks.single.title,
      'Antrenman',
    );
  });

  test('future split moves later exceptions onto the new series', () async {
    final store = LocalTaskCollection.memory('series-future-exception');
    final repository = TaskRepository(store);
    final created = await repository.createTask(
      title: 'İlaç',
      scheduledAt: DateTime(2026, 8, 26, 8),
      recurrence: const RecurrenceSelection(type: RecurrenceType.daily),
      dayPeriod: DayPeriod.morning,
    );
    await repository.updateRecurringTask(
      id: RecurrenceOccurrence.id(created.id, DateTime(2026, 8, 28)),
      scope: RecurrenceScope.thisOccurrence,
      title: 'Vitamin',
    );
    await repository.updateRecurringTask(
      id: RecurrenceOccurrence.id(created.id, DateTime(2026, 8, 27)),
      scope: RecurrenceScope.future,
      title: 'Akşam ilacı',
      dayPeriod: DayPeriod.evening,
    );

    final renamed = await repository.getTimeline(DateTime(2026, 8, 28));
    expect(renamed.tasks, hasLength(1));
    expect(renamed.tasks.single.title, 'Vitamin');
    expect(renamed.tasks.single.dayPeriod, DayPeriod.evening);

    final splitDay = await repository.getTimeline(DateTime(2026, 8, 27));
    expect(splitDay.tasks, hasLength(1));
    expect(splitDay.tasks.single.title, 'Akşam ilacı');
  });

  test(
    'subtask tick on one day does not complete the series template',
    () async {
      final store = LocalTaskCollection.memory('series-subtask-tick');
      final repository = TaskRepository(store);
      final created = await repository.createTask(
        title: 'Koşu',
        scheduledAt: DateTime(2026, 8, 26, 8),
        recurrence: const RecurrenceSelection(type: RecurrenceType.daily),
        dayPeriod: DayPeriod.morning,
      );
      await repository.replaceSubtasksForSeries(
        id: created.id,
        titles: const ['Isınma', 'Koşu'],
      );
      final today = await repository.getTimeline(DateTime(2026, 8, 26));
      final warming = today.tasks.single.subtasks.first;
      await repository.toggleSubtask(
        parentId: today.tasks.single.id,
        subtaskId: warming.id,
      );

      final ticked = await repository.getTimeline(DateTime(2026, 8, 26));
      expect(ticked.tasks.single.subtasks.first.isCompleted, isTrue);
      expect(ticked.tasks.single.isCompleted, isFalse);

      final tomorrow = await repository.getTimeline(DateTime(2026, 8, 27));
      expect(tomorrow.tasks.single.isVirtualOccurrence, isTrue);
      expect(
        tomorrow.tasks.single.subtasks.every((subtask) => !subtask.isCompleted),
        isTrue,
      );
    },
  );

  test('turning a one-off into a daily series stamps series ids', () async {
    final store = LocalTaskCollection.memory('series-promote');
    final repository = TaskRepository(store);
    final created = await repository.createTask(
      title: 'İlaç',
      scheduledAt: DateTime(2026, 8, 26, 8),
      dayPeriod: DayPeriod.morning,
    );
    await repository.updateTask(
      id: created.id,
      recurrence: const RecurrenceSelection(type: RecurrenceType.daily),
    );

    final updated = await repository.getTaskById(created.id);
    expect(updated?.recurrenceSeriesId, created.id);
    expect(updated?.recurrenceRootId, created.id);
    expect(updated?.isSeriesMaster, isTrue);

    final next = await repository.getTimeline(DateTime(2026, 8, 27));
    expect(next.tasks.single.isVirtualOccurrence, isTrue);
    expect(next.tasks.single.title, 'İlaç');
  });

  test('completing a virtual id materializes only that day', () async {
    final store = LocalTaskCollection.memory('series-complete-virtual');
    final repository = TaskRepository(store);
    final created = await repository.createTask(
      title: 'İlaç',
      scheduledAt: DateTime(2026, 8, 26, 8),
      recurrence: const RecurrenceSelection(type: RecurrenceType.daily),
      dayPeriod: DayPeriod.morning,
    );
    await repository.completeTask(
      RecurrenceOccurrence.id(created.id, DateTime(2026, 8, 27)),
    );

    final done = await repository.getTimeline(DateTime(2026, 8, 27));
    expect(done.tasks.single.isCompleted, isTrue);
    expect(done.tasks.single.isVirtualOccurrence, isFalse);

    final next = await repository.getTimeline(DateTime(2026, 8, 28));
    expect(next.tasks.single.isCompleted, isFalse);
    expect(next.tasks.single.isVirtualOccurrence, isTrue);
  });

  test('occursOn has no horizon', () {
    final start = DateTime(2026, 8, 26);
    final farWeekly = start.add(const Duration(days: 7 * 470));
    expect(
      RecurrenceGenerator.occursOn(
        date: farWeekly,
        start: start,
        type: RecurrenceType.weekly,
      ),
      isTrue,
    );
    expect(
      RecurrenceGenerator.occursOn(
        date: farWeekly.add(const Duration(days: 1)),
        start: start,
        type: RecurrenceType.weekly,
      ),
      isFalse,
    );
  });
}
