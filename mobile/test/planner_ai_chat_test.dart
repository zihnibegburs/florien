import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/services/planner_ai_service.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/planner_ai_chat_screen.dart';

class _FakePlannerAiGateway implements PlannerAiGateway {
  @override
  Future<PlannerAiReply> send(List<PlannerChatTurn> conversation) async {
    expect(conversation.last.content, 'Bugün koşup kitap okuyacağım');
    return const PlannerAiReply(
      message: 'Bunu iki net göreve ayırdım.',
      tasks: [
        PlannerTaskSuggestion(title: 'Koşuya çık', durationMinutes: 30),
        PlannerTaskSuggestion(title: 'Kitap oku', durationMinutes: 20),
      ],
    );
  }
}

class _AiInboxNotifier extends InboxNotifier {
  static final addedTasks = <TaskModel>[];

  @override
  Future<List<TaskModel>> build() async => addedTasks;

  @override
  Future<TaskModel> addToInbox({
    required String title,
    String? description,
    int durationMinutes = 30,
    String color = '#4F52B2',
    String? icon,
    EnergyLevel? energyLevel,
    String? motivation,
    TaskPriority priority = TaskPriority.none,
    String? todoListId,
  }) async {
    final task = TaskModel(
      id: 'ai-task-${addedTasks.length}',
      title: title,
      description: description,
      color: color,
      icon: icon ?? 'task',
      durationMinutes: durationMinutes,
      status: TaskStatus.pending,
      sortOrder: addedTasks.length,
      isInbox: true,
      energyLevel: energyLevel,
      motivation: motivation,
      priority: priority,
      todoListId: todoListId,
    );
    addedTasks.add(task);
    state = AsyncData([...addedTasks]);
    return task;
  }
}

void main() {
  setUp(_AiInboxNotifier.addedTasks.clear);

  testWidgets('AI suggestions are saved only after user approval', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannerAiGatewayProvider.overrideWithValue(_FakePlannerAiGateway()),
          inboxProvider.overrideWith(_AiInboxNotifier.new),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const PlannerAiChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('planner-ai-voice')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('planner-ai-input')),
      'Bugün koşup kitap okuyacağım',
    );
    await tester.tap(find.byKey(const ValueKey('planner-ai-send')));
    await tester.pumpAndSettle();

    expect(find.text('Bunu iki net göreve ayırdım.'), findsOneWidget);
    expect(find.text('Koşuya çık'), findsOneWidget);
    expect(find.text('Kitap oku'), findsOneWidget);
    expect(_AiInboxNotifier.addedTasks, isEmpty);

    await tester.tap(find.byKey(const ValueKey('planner-ai-approve')));
    await tester.pumpAndSettle();

    expect(_AiInboxNotifier.addedTasks.map((task) => task.title), [
      'Koşuya çık',
      'Kitap oku',
    ]);
    expect(find.text('Eklendi'), findsOneWidget);
  });
}
