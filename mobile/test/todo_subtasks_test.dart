import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/todo_list_tab.dart';

const _firstSubtask = TaskModel(
  id: 'subtask-1',
  title: 'Hazırlık yap',
  color: '#6C5CE7',
  icon: 'task',
  durationMinutes: 5,
  status: TaskStatus.pending,
  sortOrder: 0,
  isInbox: false,
  parentTaskId: 'parent-task',
);

const _secondSubtask = TaskModel(
  id: 'subtask-2',
  title: 'Çalışmaya başla',
  color: '#6C5CE7',
  icon: 'task',
  durationMinutes: 10,
  status: TaskStatus.completed,
  sortOrder: 1,
  isInbox: false,
  parentTaskId: 'parent-task',
);

const _parentTask = TaskModel(
  id: 'parent-task',
  title: 'Koşu planı',
  color: '#6C5CE7',
  icon: 'task',
  durationMinutes: 15,
  status: TaskStatus.pending,
  sortOrder: 0,
  isInbox: true,
  subtasks: [_firstSubtask, _secondSubtask],
);

class _SubtaskInboxNotifier extends InboxNotifier {
  @override
  Future<List<TaskModel>> build() async => const [_parentTask];
}

class _NoCustomListsNotifier extends TodoListsNotifier {
  @override
  Future<List<TodoListDefinition>> build() async => const [];
}

void main() {
  testWidgets('subtask count is visible and arrow expands the subtasks', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxProvider.overrideWith(_SubtaskInboxNotifier.new),
          todoListsProvider.overrideWith(_NoCustomListsNotifier.new),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: TodoListTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 / 2 alt görev'), findsOneWidget);
    expect(find.text('Hazırlık yap'), findsNothing);

    await tester.tap(find.byTooltip('Alt görevleri göster'));
    await tester.pumpAndSettle();

    expect(find.text('Hazırlık yap'), findsOneWidget);
    expect(find.text('Çalışmaya başla'), findsOneWidget);
    expect(find.byTooltip('Alt görevleri gizle'), findsOneWidget);
  });

  testWidgets('subtask parent does not offer breakdown suggestion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxProvider.overrideWith(_SubtaskInboxNotifier.new),
          todoListsProvider.overrideWith(_NoCustomListsNotifier.new),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: TodoListTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Koşu planı'));
    await tester.pumpAndSettle();

    expect(find.text('Tarife'), findsOneWidget);
    expect(find.text('Ayrım öner'), findsNothing);
  });
}
