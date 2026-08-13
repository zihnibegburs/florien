import 'package:flutter/material.dart' hide DayPeriod;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/daily_planner_tab.dart';
import 'package:florien/features/todo/todo_list_tab.dart';

const _todoTask = TaskModel(
  id: 'drag-todo-task',
  title: 'Sürüklenecek yapılacak',
  color: '#6C5CE7',
  icon: 'task',
  durationMinutes: 15,
  status: TaskStatus.pending,
  sortOrder: 0,
  isInbox: true,
  priority: TaskPriority.high,
);

class _DragInboxNotifier extends InboxNotifier {
  TaskPriority? movedPriority;

  @override
  Future<List<TaskModel>> build() async => const [_todoTask];

  @override
  Future<void> updatePriority(String id, TaskPriority priority) async {
    expect(id, _todoTask.id);
    movedPriority = priority;
    state = AsyncData([_todoTask.copyWith(priority: priority)]);
  }
}

class _EmptyListsNotifier extends TodoListsNotifier {
  @override
  Future<List<TodoListDefinition>> build() async => const [];
}

void main() {
  testWidgets('todo task shrinks and moves between priority groups', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final inbox = _DragInboxNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxProvider.overrideWith(() => inbox),
          todoListsProvider.overrideWith(_EmptyListsNotifier.new),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: TodoListTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text(_todoTask.title)),
    );
    await tester.pump(const Duration(milliseconds: 350));
    final feedback = tester.widget<Opacity>(
      find.byKey(ValueKey('todo-drag-feedback-${_todoTask.id}')),
    );
    expect(feedback.opacity, .72);

    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('todo-drop-low'))),
    );
    await tester.pump(const Duration(milliseconds: 180));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(inbox.movedPriority, TaskPriority.low);
  });

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
