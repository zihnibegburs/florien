import 'package:flutter/material.dart' hide DayPeriod;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/services/planner_ai_service.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/premium/premium_membership.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/daily_planner_tab.dart';
import 'package:florien/features/todo/task_breakdown_action.dart';
import 'package:florien/features/todo/todo_list_tab.dart';

const _todoTask = TaskModel(
  id: 'todo-task',
  title: 'Sunum hazırla',
  color: '#6C5CE7',
  icon: 'task',
  durationMinutes: 15,
  status: TaskStatus.pending,
  sortOrder: 0,
  isInbox: true,
);

const _dailyTask = TaskModel(
  id: 'daily-task',
  title: 'Günlük deneme görevi',
  color: '#6C5CE7',
  icon: 'task',
  durationMinutes: 15,
  scheduledAt: null,
  status: TaskStatus.pending,
  sortOrder: 0,
  isInbox: false,
  dayPeriod: DayPeriod.daytime,
);

const _dailySubtask = TaskModel(
  id: 'daily-subtask',
  title: 'Hazırlık yap',
  color: '#6C5CE7',
  icon: 'task',
  durationMinutes: 5,
  status: TaskStatus.pending,
  sortOrder: 0,
  isInbox: false,
  parentTaskId: 'daily-parent',
);

const _dailyParent = TaskModel(
  id: 'daily-parent',
  title: 'Alt görevli günlük iş',
  color: '#6C5CE7',
  icon: 'task',
  durationMinutes: 15,
  status: TaskStatus.pending,
  sortOrder: 0,
  isInbox: false,
  dayPeriod: DayPeriod.daytime,
  subtasks: [_dailySubtask],
);

class _TodoInboxNotifier extends InboxNotifier {
  @override
  Future<List<TaskModel>> build() async => const [_todoTask];
}

class _EmptyListsNotifier extends TodoListsNotifier {
  @override
  Future<List<TodoListDefinition>> build() async => const [];
}

class _FakeTaskBreakdownService implements TaskBreakdownService {
  _FakeTaskBreakdownService([
    this.titles = const ['İlk adımı hazırla', 'Başla'],
  ]);

  final List<String> titles;
  String? lastTitle;
  Object? error;

  @override
  Future<List<String>> generateSubtasks(String title) async {
    lastTitle = title;
    final thrown = error;
    if (thrown != null) throw thrown;
    return titles;
  }
}

class _ActivePremiumMembershipNotifier extends PremiumMembershipNotifier {
  @override
  Future<PremiumMembership> build() async =>
      const PremiumMembership(storeAvailable: false, isPremium: true);
}

class _NonPremiumMembershipNotifier extends PremiumMembershipNotifier {
  @override
  Future<PremiumMembership> build() async =>
      const PremiumMembership(storeAvailable: false);
}

void main() {
  testWidgets('todo menu Ayrım öner saves AI subtasks', (tester) async {
    final breakdown = _FakeTaskBreakdownService();
    TaskModel? appliedTask;
    List<String>? appliedTitles;
    await _pumpTodo(
      tester,
      breakdown: breakdown,
      onApply: (task, titles) async {
        appliedTask = task;
        appliedTitles = titles;
      },
    );

    await tester.tap(find.text(_todoTask.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ayrım öner'));
    await tester.pumpAndSettle();

    expect(breakdown.lastTitle, _todoTask.title);
    expect(appliedTask?.id, _todoTask.id);
    expect(appliedTitles, ['İlk adımı hazırla', 'Başla']);
    expect(find.text('Ayrım öner'), findsNothing);
    expect(find.text('2 küçük adım eklendi.'), findsOneWidget);
  });

  testWidgets('todo menu Ayrım öner opens Premium when locked', (tester) async {
    final breakdown = _FakeTaskBreakdownService();
    var applied = false;
    await _pumpTodo(
      tester,
      breakdown: breakdown,
      premium: false,
      onApply: (task, titles) async => applied = true,
    );

    await tester.tap(find.text(_todoTask.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ayrım öner'));
    await tester.pumpAndSettle();

    expect(find.text('Florien özellikleri'), findsOneWidget);
    expect(find.text('Alt görevler'), findsOneWidget);
    expect(applied, isFalse);
    expect(breakdown.lastTitle, isNull);
  });

  testWidgets('daily planner Ayrım öner saves AI subtasks', (tester) async {
    final breakdown = _FakeTaskBreakdownService();
    TaskModel? appliedTask;
    List<String>? appliedTitles;
    await _pumpDaily(
      tester,
      task: _dailyTask.copyWith(scheduledAt: DateTime.now()),
      breakdown: breakdown,
      onApply: (task, titles) async {
        appliedTask = task;
        appliedTitles = titles;
      },
    );

    await tester.tap(find.text(_dailyTask.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ayrım öner'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('daily-detail-title')), findsNothing);
    expect(find.text('Görevi düzenle'), findsNothing);
    expect(breakdown.lastTitle, _dailyTask.title);
    expect(appliedTask?.id, _dailyTask.id);
    expect(appliedTitles, ['İlk adımı hazırla', 'Başla']);
    expect(find.text('2 küçük adım eklendi.'), findsOneWidget);
  });

  testWidgets('daily planner hides Ayrım öner when task has subtasks', (
    tester,
  ) async {
    await _pumpDaily(
      tester,
      task: _dailyParent.copyWith(scheduledAt: DateTime.now()),
      breakdown: _FakeTaskBreakdownService(),
      onApply: (task, titles) async {},
    );

    expect(find.text('Hazırlık yap'), findsOneWidget);
    expect(find.text('0 / 1 alt görev'), findsOneWidget);

    await tester.tap(find.text(_dailyParent.title));
    await tester.pumpAndSettle();

    expect(find.text('Yeniden planla'), findsOneWidget);
    expect(find.text('Ayrım öner'), findsNothing);
  });

  testWidgets('Ayrım öner shows the AI error on the list', (tester) async {
    final breakdown = _FakeTaskBreakdownService()
      ..error = const PlannerAiException('AI alt görev üretemedi.');
    var applied = false;
    await _pumpTodo(
      tester,
      breakdown: breakdown,
      onApply: (task, titles) async => applied = true,
    );

    await tester.tap(find.text(_todoTask.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ayrım öner'));
    await tester.pumpAndSettle();

    expect(applied, isFalse);
    expect(find.text('AI alt görev üretemedi.'), findsOneWidget);
  });
}

Future<void> _pumpTodo(
  WidgetTester tester, {
  required _FakeTaskBreakdownService breakdown,
  required TaskBreakdownApplier onApply,
  bool premium = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        inboxProvider.overrideWith(_TodoInboxNotifier.new),
        todoListsProvider.overrideWith(_EmptyListsNotifier.new),
        taskBreakdownServiceProvider.overrideWithValue(breakdown),
        applyAiBreakdownProvider.overrideWithValue(onApply),
        premiumMembershipProvider.overrideWith(
          premium
              ? _ActivePremiumMembershipNotifier.new
              : _NonPremiumMembershipNotifier.new,
        ),
      ],
      child: MaterialApp(
        theme: FlorienTheme.light,
        home: const Scaffold(body: TodoListTab()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDaily(
  WidgetTester tester, {
  required TaskModel task,
  required _FakeTaskBreakdownService breakdown,
  required TaskBreakdownApplier onApply,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dailyTimelineProvider.overrideWith(
          (ref, date) async => TimelineModel(date: date, tasks: [task]),
        ),
        taskBreakdownServiceProvider.overrideWithValue(breakdown),
        applyAiBreakdownProvider.overrideWithValue(onApply),
        premiumMembershipProvider.overrideWith(
          _ActivePremiumMembershipNotifier.new,
        ),
      ],
      child: MaterialApp(
        theme: FlorienTheme.light,
        home: const Scaffold(body: DailyPlannerTab()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
