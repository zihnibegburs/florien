import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/models/achievement.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/todo_list_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pendingTask = TaskModel(
  id: 'task-1',
  title: 'Deneme görevi',
  color: '#6C5CE7',
  icon: 'task',
  durationMinutes: 15,
  status: TaskStatus.pending,
  sortOrder: 0,
  isInbox: true,
  priority: TaskPriority.high,
);

class _CompletionInboxNotifier extends InboxNotifier {
  TaskModel _task = _pendingTask;
  String? deletedId;
  String? updatedTitle;

  @override
  Future<List<TaskModel>> build() async => [_task];

  @override
  Future<void> completeTask(String id) async {
    _task = _task.copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime(2026),
    );
    state = AsyncData([_task]);
  }

  @override
  Future<void> uncompleteTask(String id) async {
    _task = _task.copyWith(
      status: TaskStatus.pending,
      clearCompletedAt: true,
      priority: TaskPriority.none,
    );
    state = AsyncData([_task]);
  }

  @override
  Future<void> deleteTask(String id) async {
    deletedId = id;
    state = const AsyncData([]);
  }

  @override
  Future<void> updateDetailedWithIcon({
    required String id,
    required String title,
    required int durationMinutes,
    TaskPriority priority = TaskPriority.none,
    required String? todoListId,
    String? icon,
    String? description,
    List<String> subtasks = const [],
  }) async {
    expect(id, _pendingTask.id);
    updatedTitle = title;
    _task = _task.copyWith(
      title: title,
      description: description,
      durationMinutes: durationMinutes,
      priority: priority,
      todoListId: todoListId,
    );
    state = AsyncData([_task]);
  }
}

class _DelayedCompletionInboxNotifier extends _CompletionInboxNotifier {
  @override
  Future<void> completeTask(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await super.completeTask(id);
  }
}

class _EmptyTodoListsNotifier extends TodoListsNotifier {
  @override
  Future<List<TodoListDefinition>> build() async => const [];
}

void main() {
  testWidgets('completed task remains visible with a line through its title', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxProvider.overrideWith(_CompletionInboxNotifier.new),
          todoListsProvider.overrideWith(_EmptyTodoListsNotifier.new),
          manualCompletionSummaryProvider.overrideWithValue(
            (_) async => const CompletionCounts(today: 3, thisWeek: 7),
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: TodoListTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('TAMAMLANDI (1)'), findsNothing);
    final taskTile = find.ancestor(
      of: find.text('Deneme görevi'),
      matching: find.byType(ListTile),
    );
    final completionButton = find.descendant(
      of: taskTile,
      matching: find.byIcon(Icons.circle_outlined),
    );

    await tester.tap(completionButton);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('task-completion-bubbles')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('completion-celebration-page')),
      findsNothing,
    );
    expect(find.text('Deneme görevi'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    expect(find.text('TAMAMLANDI (1)'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Deneme görevi')).dy,
      greaterThan(tester.getTopLeft(find.text('TAMAMLANDI (1)')).dy),
    );
    var title = tester.widget<Text>(find.text('Deneme görevi'));
    expect(title.style?.decoration, TextDecoration.lineThrough);
    expect(find.byTooltip('Tamamlanmadı olarak işaretle'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: taskTile,
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
    );
    await tester.pumpAndSettle();

    title = tester.widget<Text>(find.text('Deneme görevi'));
    expect(title.style?.decoration, TextDecoration.none);
    expect(find.text('TAMAMLANDI (1)'), findsNothing);
    expect(find.text('YAPILACAK (1)'), findsOneWidget);
    expect(find.text('YÜKSEK (0)'), findsNothing);
  });

  testWidgets(
    'completion bubbles still appear after the task moves to TAMAMLANDI',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inboxProvider.overrideWith(_DelayedCompletionInboxNotifier.new),
            todoListsProvider.overrideWith(_EmptyTodoListsNotifier.new),
            manualCompletionSummaryProvider.overrideWithValue(
              (_) async => const CompletionCounts(today: 3, thisWeek: 7),
            ),
          ],
          child: MaterialApp(
            theme: FlorienTheme.light,
            home: const Scaffold(body: TodoListTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final taskTile = find.ancestor(
        of: find.text('Deneme görevi'),
        matching: find.byType(ListTile),
      );

      await tester.tap(
        find.descendant(
          of: taskTile,
          matching: find.byIcon(Icons.circle_outlined),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('task-completion-bubbles')),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('task-completion-bubbles')),
        findsOneWidget,
      );
      expect(find.text('TAMAMLANDI (1)'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('achievement popup appears only at the completion threshold', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final catalog = await AchievementCatalog.load();
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxProvider.overrideWith(_CompletionInboxNotifier.new),
          todoListsProvider.overrideWith(_EmptyTodoListsNotifier.new),
          activeProfileScopeProvider.overrideWithValue('guest:test'),
          achievementCatalogProvider.overrideWith((ref) => catalog),
          manualCompletionSummaryProvider.overrideWithValue(
            (_) async =>
                const CompletionCounts(today: 1, thisWeek: 1, total: 1),
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: TodoListTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final taskTile = find.ancestor(
      of: find.text('Deneme görevi'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: taskTile,
        matching: find.byIcon(Icons.circle_outlined),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('task-completion-bubbles')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('achievement-celebration')),
      findsOneWidget,
    );
    expect(find.text('İlk adım'), findsOneWidget);
    await tester.tap(find.text('Harika'));
    await tester.pumpAndSettle();
  });

  testWidgets('todo delete action removes the selected task', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final inbox = _CompletionInboxNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxProvider.overrideWith(() => inbox),
          todoListsProvider.overrideWith(_EmptyTodoListsNotifier.new),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: TodoListTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(_pendingTask.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yapılacakları sil'));
    await tester.pumpAndSettle();

    expect(inbox.deletedId, _pendingTask.id);
    expect(find.text(_pendingTask.title), findsNothing);
  });

  testWidgets('todo edit action updates the existing task', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final inbox = _CompletionInboxNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxProvider.overrideWith(() => inbox),
          todoListsProvider.overrideWith(_EmptyTodoListsNotifier.new),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: TodoListTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(_pendingTask.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yapılacakları düzenle'));
    await tester.pumpAndSettle();

    expect(find.text('Görevi düzenle'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Güncellenen görev');
    await tester.tap(find.text('To-do’yu kaydet'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(inbox.updatedTitle, 'Güncellenen görev');
    expect(find.text('Güncellenen görev'), findsOneWidget);
  });
}
