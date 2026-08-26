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
