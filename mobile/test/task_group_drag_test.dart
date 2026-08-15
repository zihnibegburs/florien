import 'package:flutter/material.dart' hide DayPeriod;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/daily_planner_tab.dart';

void main() {
  testWidgets('daily task shrinks and moves between time groups', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final task = TaskModel(
      id: 'drag-daily-task',
      title: 'Sürüklenecek günlük görev',
      color: '#6C5CE7',
      icon: 'task',
      durationMinutes: 20,
      scheduledAt: DateTime.now(),
      status: TaskStatus.pending,
      sortOrder: 0,
      isInbox: false,
      dayPeriod: DayPeriod.morning,
    );
    DayPeriod? movedPeriod;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyTimelineProvider.overrideWith(
            (ref, date) async => TimelineModel(date: date, tasks: [task]),
          ),
          dailyTaskGroupMoverProvider.overrideWithValue((
            movedTask,
            period,
            date,
          ) async {
            expect(movedTask.id, task.id);
            movedPeriod = period;
          }),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: DailyPlannerTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text(task.title)),
    );
    await tester.pump(const Duration(milliseconds: 350));
    final feedback = tester.widget<Opacity>(
      find.byKey(ValueKey('daily-drag-feedback-${task.id}')),
    );
    expect(feedback.opacity, .72);

    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('daily-drop-evening'))),
    );
    await tester.pump(const Duration(milliseconds: 180));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(movedPeriod, DayPeriod.evening);
  });
}
