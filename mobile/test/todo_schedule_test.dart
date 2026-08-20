import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/todo_list_tab.dart';

const _task = TaskModel(
  id: 'schedule-task',
  title: 'Planlanacak görev',
  color: '#6C5CE7',
  icon: 'task',
  durationMinutes: 15,
  status: TaskStatus.pending,
  sortOrder: 0,
  isInbox: true,
  priority: TaskPriority.none,
);

class _ScheduleInboxNotifier extends InboxNotifier {
  DateTime? scheduledAt;

  @override
  Future<List<TaskModel>> build() async => const [_task];

  @override
  Future<void> scheduleTask(String id, DateTime scheduledAt) async {
    expect(id, _task.id);
    this.scheduledAt = scheduledAt;
    state = const AsyncData([]);
  }
}

class _EmptyListsNotifier extends TodoListsNotifier {
  @override
  Future<List<TodoListDefinition>> build() async => const [];
}

void main() {
  testWidgets('schedule shortcut moves todo task to tomorrow at noon', (
    tester,
  ) async {
    final notifier = _ScheduleInboxNotifier();
    await _pumpTodo(tester, notifier);

    await _openSchedule(tester);
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.textContaining('Bugün ('), findsOneWidget);
    expect(find.textContaining('Yarın ('), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('schedule-sheet-list')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Bu hafta sonu ('), findsOneWidget);
    expect(find.textContaining('Gelecek hafta ('), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('schedule-sheet-list')),
      const Offset(0, 260),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Yarın ('));
    await tester.pumpAndSettle();

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect(notifier.scheduledAt?.year, tomorrow.year);
    expect(notifier.scheduledAt?.month, tomorrow.month);
    expect(notifier.scheduledAt?.day, tomorrow.day);
    expect(notifier.scheduledAt?.hour, 12);
    expect(find.text(_task.title), findsNothing);
  });

  testWidgets('calendar selection schedules todo task on selected day', (
    tester,
  ) async {
    final notifier = _ScheduleInboxNotifier();
    await _pumpTodo(tester, notifier);
    await _openSchedule(tester);

    final target = DateTime.now().add(const Duration(days: 4));
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(target);
    await tester.pump();
    await tester.tap(find.byTooltip('Tarihi onayla'));
    await tester.pumpAndSettle();

    expect(notifier.scheduledAt?.year, target.year);
    expect(notifier.scheduledAt?.month, target.month);
    expect(notifier.scheduledAt?.day, target.day);
    expect(notifier.scheduledAt?.hour, 12);
  });
}

Future<void> _pumpTodo(
  WidgetTester tester,
  _ScheduleInboxNotifier notifier,
) async {
  await tester.binding.setSurfaceSize(const Size(430, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        inboxProvider.overrideWith(() => notifier),
        todoListsProvider.overrideWith(_EmptyListsNotifier.new),
      ],
      child: MaterialApp(
        theme: FlorienTheme.light,
        home: const Scaffold(body: TodoListTab()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSchedule(WidgetTester tester) async {
  await tester.tap(find.text(_task.title));
  await tester.pumpAndSettle();
  expect(find.text('Ayrım öner'), findsOneWidget);
  await tester.tap(find.text('Tarife'));
  await tester.pumpAndSettle();
}
