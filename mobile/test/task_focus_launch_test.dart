import 'package:flutter/material.dart' hide DayPeriod;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/utils/task_icons.dart';
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
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required InboxNotifier Function() inboxOverride,
  required List<TaskModel> dailyTasks,
  ValueChanged<TaskModel>? onStarted,
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
  expect(find.byKey(const ValueKey('active-focus-title')), findsOneWidget);
  expect(find.text(title), findsOneWidget);
  expect(find.text(remaining), findsOneWidget);
  expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  final icon = tester.widget<Icon>(
    find.byKey(const ValueKey('active-focus-task-icon')),
  );
  expect(icon.icon, TaskIcons.defaultIcon);
  expect(icon.size, 112);
}
