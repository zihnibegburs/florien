import 'package:flutter/material.dart' hide DayPeriod;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/todo_home_screen.dart';

const _todoTask = TaskModel(
  id: 'todo-focus-task',
  title: 'Okuma odağı',
  color: '#6C5CE7',
  icon: 'task',
  durationMinutes: 12,
  status: TaskStatus.pending,
  sortOrder: 0,
  isInbox: true,
  priority: TaskPriority.none,
);

class _TodoTaskInboxNotifier extends InboxNotifier {
  @override
  Future<List<TaskModel>> build() async => const [_todoTask];
}

class _EmptyInboxNotifier extends InboxNotifier {
  @override
  Future<List<TaskModel>> build() async => const [];
}

class _EmptyListsNotifier extends TodoListsNotifier {
  @override
  Future<List<TodoListDefinition>> build() async => const [];
}

void main() {
  test('local time maps tasks to morning, daytime and evening', () {
    expect(dayPeriodForLocalTime(DateTime(2026, 8, 14, 8)), DayPeriod.morning);
    expect(dayPeriodForLocalTime(DateTime(2026, 8, 14, 14)), DayPeriod.daytime);
    expect(dayPeriodForLocalTime(DateTime(2026, 8, 14, 21)), DayPeriod.evening);
  });

  testWidgets('todo task starts focus with its duration and icon', (
    tester,
  ) async {
    TaskModel? startedTask;
    await _pumpHome(
      tester,
      inboxOverride: _TodoTaskInboxNotifier.new,
      dailyTasks: const [],
      onStarted: (task) => startedTask = task,
    );

    await tester.tap(find.text(_todoTask.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Görevi başlat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    _expectActiveTaskFocus(tester, title: _todoTask.title, remaining: '12:00');
    expect(startedTask?.id, _todoTask.id);
  });

  testWidgets('daily task starts focus with its duration and icon', (
    tester,
  ) async {
    final dailyTask = TaskModel(
      id: 'daily-focus-task',
      title: 'Günlük yürüyüş',
      color: '#00A8A8',
      icon: 'task',
      durationMinutes: 30,
      scheduledAt: DateTime.now(),
      status: TaskStatus.pending,
      sortOrder: 0,
      isInbox: false,
      dayPeriod: DayPeriod.morning,
    );
    await _pumpHome(
      tester,
      inboxOverride: _EmptyInboxNotifier.new,
      dailyTasks: [dailyTask],
    );

    await tester.tap(find.text('Günlük'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(dailyTask.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Görevi başlat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    _expectActiveTaskFocus(tester, title: dailyTask.title, remaining: '30:00');

    await tester.tap(find.text('Günlük'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(ValueKey('daily-task-progress-${dailyTask.id}')),
      findsOneWidget,
    );
    final status = tester.widget<Text>(
      find.byKey(ValueKey('daily-task-status-${dailyTask.id}')),
    );
    expect(status.data, matches(RegExp(r'^\d{2}:\d{2}$')));
    expect(status.data, isNot('30 dk'));
  });

  testWidgets('focus tab shows the earliest active scheduled task', (
    tester,
  ) async {
    final now = DateTime.now();
    final first = TaskModel(
      id: 'scheduled-focus-first',
      title: 'Önce başlayan plan',
      color: '#EAA4C4',
      icon: 'task',
      durationMinutes: 40,
      scheduledAt: now.subtract(const Duration(minutes: 10)),
      status: TaskStatus.pending,
      sortOrder: 1,
      isInbox: false,
      isTimed: true,
      dayPeriod: DayPeriod.morning,
    );
    final second = TaskModel(
      id: 'scheduled-focus-second',
      title: 'Sonra başlayan plan',
      color: '#6C5CE7',
      icon: 'task',
      durationMinutes: 40,
      scheduledAt: now.subtract(const Duration(minutes: 5)),
      status: TaskStatus.pending,
      sortOrder: 0,
      isInbox: false,
      isTimed: true,
      dayPeriod: DayPeriod.morning,
    );
    await _pumpHome(
      tester,
      inboxOverride: _EmptyInboxNotifier.new,
      dailyTasks: [second, first],
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Odaklan'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('active-timer')), findsOneWidget);
    expect(find.text(first.title), findsOneWidget);
    expect(find.text(second.title), findsNothing);
  });

  testWidgets('standalone focus becomes a progressing daily task', (
    tester,
  ) async {
    final dailyTasks = <TaskModel>[];
    int? createdDuration;
    await _pumpHome(
      tester,
      inboxOverride: _EmptyInboxNotifier.new,
      dailyTasks: dailyTasks,
      onStandaloneFocusStarted: (minutes) async {
        createdDuration = minutes;
        final now = DateTime.now();
        final task = TaskModel(
          id: 'standalone-focus-task',
          title: 'Odaklan',
          color: '#6C5CE7',
          icon: 'timer',
          durationMinutes: minutes,
          scheduledAt: now,
          status: TaskStatus.inProgress,
          sortOrder: 0,
          isInbox: false,
          isTimed: true,
          dayPeriod: dayPeriodForLocalTime(now),
        );
        dailyTasks.add(task);
        return FocusTaskLaunch(
          taskId: task.id,
          title: task.title,
          durationMinutes: task.durationMinutes,
          icon: task.icon,
          color: task.color,
          startedAt: now,
          endsAt: now.add(Duration(minutes: minutes)),
        );
      },
    );

    await tester.tap(find.text('Odaklan'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Başla'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(createdDuration, 5);
    _expectActiveTaskFocus(tester, title: 'Odaklan', remaining: '5:00');

    await tester.tap(find.text('Günlük'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('standalone-focus-task')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('daily-task-progress-standalone-focus-task')),
      findsOneWidget,
    );
    final status = tester.widget<Text>(
      find.byKey(const ValueKey('daily-task-status-standalone-focus-task')),
    );
    expect(status.data, matches(RegExp(r'^\d{2}:\d{2}$')));
  });

  testWidgets('compact bottom banner opens the planner AI chat', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      inboxOverride: _EmptyInboxNotifier.new,
      dailyTasks: const [],
    );

    expect(tester.getSize(find.byType(NavigationBar)).height, 64);
    await tester.tap(find.byKey(const ValueKey('planner-ai-chat-button')));
    await tester.pumpAndSettle();

    expect(find.text('Plan Asistanı'), findsOneWidget);
    expect(find.byKey(const ValueKey('planner-ai-input')), findsOneWidget);
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required InboxNotifier Function() inboxOverride,
  required List<TaskModel> dailyTasks,
  ValueChanged<TaskModel>? onStarted,
  Future<FocusTaskLaunch> Function(int)? onStandaloneFocusStarted,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        inboxProvider.overrideWith(inboxOverride),
        todoListsProvider.overrideWith(_EmptyListsNotifier.new),
        dailyTimelineProvider.overrideWith(
          (ref, date) async => TimelineModel(date: date, tasks: dailyTasks),
        ),
        startTaskFocusProvider.overrideWithValue((task) async {
          onStarted?.call(task);
        }),
        if (onStandaloneFocusStarted != null)
          createStandaloneFocusTaskProvider.overrideWithValue(
            onStandaloneFocusStarted,
          ),
        completeFocusedTaskProvider.overrideWithValue((_) async {}),
      ],
      child: MaterialApp(
        theme: FlorienTheme.light,
        home: const TodoHomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectActiveTaskFocus(
  WidgetTester tester, {
  required String title,
  required String remaining,
}) {
  final activeTitle = tester.widget<Text>(
    find.byKey(const ValueKey('active-focus-title')),
  );
  expect(activeTitle.data, title);
  expect(find.text(remaining), findsOneWidget);
  expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  expect(find.byKey(const ValueKey('active-focus-task-icon')), findsOneWidget);
}
