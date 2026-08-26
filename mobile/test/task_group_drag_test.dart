import 'package:flutter/material.dart' hide DayPeriod;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/models/recurrence.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/daily_planner_tab.dart';

void main() {
  testWidgets('daily task shrinks and moves between time groups', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final task = _dailyTask(
      id: 'drag-daily-task',
      title: 'Sürüklenecek günlük görev',
    );
    DayPeriod? movedPeriod;
    await _pumpPlanner(
      tester,
      task: task,
      onMove:
          (
            movedTask,
            period,
            _, {
            scope = RecurrenceScope.thisOccurrence,
          }) async {
            expect(movedTask.id, task.id);
            movedPeriod = period;
          },
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text(task.title)),
    );
    await tester.pump(const Duration(milliseconds: 350));
    final feedback = tester.widget<Opacity>(
      find.byKey(ValueKey('daily-drag-feedback-${task.id}')),
    );
    expect(feedback.opacity, .72);

    await _dropOnEvening(tester, gesture);
    expect(movedPeriod, DayPeriod.evening);
    expect(
      find.byKey(const ValueKey('daily-recurrence-scope-sheet')),
      findsNothing,
    );
  });

  testWidgets('unchanged repeating task asks before a group move', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateTime.now();
    final task = _dailyTask(
      id: RecurrenceOccurrence.id('series-1', today),
      title: 'Tekrarlayan koşu',
      recurrenceType: RecurrenceType.daily,
      recurrenceSeriesId: 'series-1',
      occurrenceDate: RecurrenceOccurrence.dateKey(today),
    );
    RecurrenceScope? movedScope;
    DayPeriod? movedPeriod;
    await _pumpPlanner(
      tester,
      task: task,
      onMove:
          (
            movedTask,
            period,
            _, {
            scope = RecurrenceScope.thisOccurrence,
          }) async {
            movedPeriod = period;
            movedScope = scope;
          },
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text(task.title)),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await _dropOnEvening(tester, gesture);

    expect(find.text('Görevi taşı'), findsOneWidget);
    expect(movedPeriod, isNull);
    await tester.tap(find.text('Bunu taşı'));
    await tester.pumpAndSettle();
    expect(movedPeriod, DayPeriod.evening);
    expect(movedScope, RecurrenceScope.thisOccurrence);
  });

  testWidgets('renamed repeating task moves only itself without asking', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateTime.now();
    final task = _dailyTask(
      id: 'renamed-occurrence',
      title: 'Sabah koşusu',
      recurrenceSeriesId: 'series-1',
      recurrenceRootId: 'series-1',
      occurrenceDate: RecurrenceOccurrence.dateKey(today),
      recurrenceException: RecurrenceExceptionKind.override,
      recurrenceOwnedFields: const [RecurrencePatch.title],
    );
    RecurrenceScope? movedScope;
    DayPeriod? movedPeriod;
    await _pumpPlanner(
      tester,
      task: task,
      onMove:
          (
            movedTask,
            period,
            _, {
            scope = RecurrenceScope.thisOccurrence,
          }) async {
            movedPeriod = period;
            movedScope = scope;
          },
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text(task.title)),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await _dropOnEvening(tester, gesture);

    expect(find.text('Görevi taşı'), findsNothing);
    expect(movedPeriod, DayPeriod.evening);
    expect(movedScope, RecurrenceScope.thisOccurrence);
  });
}

TaskModel _dailyTask({
  required String id,
  required String title,
  RecurrenceType recurrenceType = RecurrenceType.none,
  String? recurrenceSeriesId,
  String? recurrenceRootId,
  String? occurrenceDate,
  RecurrenceExceptionKind recurrenceException = RecurrenceExceptionKind.none,
  List<String>? recurrenceOwnedFields,
}) => TaskModel(
  id: id,
  title: title,
  color: '#6C5CE7',
  icon: 'task',
  durationMinutes: 20,
  scheduledAt: DateTime.now(),
  status: TaskStatus.pending,
  sortOrder: 0,
  isInbox: false,
  dayPeriod: DayPeriod.morning,
  recurrenceType: recurrenceType,
  recurrenceSeriesId: recurrenceSeriesId,
  recurrenceRootId: recurrenceRootId,
  occurrenceDate: occurrenceDate,
  recurrenceException: recurrenceException,
  recurrenceOwnedFields: recurrenceOwnedFields,
);

Future<void> _pumpPlanner(
  WidgetTester tester, {
  required TaskModel task,
  required DailyTaskGroupMover onMove,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dailyTimelineProvider.overrideWith(
          (ref, date) async => TimelineModel(date: date, tasks: [task]),
        ),
        dailyTaskGroupMoverProvider.overrideWithValue(onMove),
      ],
      child: MaterialApp(
        theme: FlorienTheme.light,
        home: const Scaffold(body: DailyPlannerTab()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _dropOnEvening(WidgetTester tester, TestGesture gesture) async {
  await gesture.moveTo(
    tester.getCenter(find.byKey(const ValueKey('daily-drop-evening'))),
  );
  await tester.pump(const Duration(milliseconds: 180));
  await gesture.up();
  await tester.pumpAndSettle();
}
