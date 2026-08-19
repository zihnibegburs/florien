import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/services/planner_ai_service.dart';
import 'package:florien/core/services/speech_input_service.dart';
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

class _FakeSpeechInput implements SpeechInput {
  bool _isListening = false;
  void Function(String text)? _onText;
  void Function(bool isListening)? _onListeningChanged;
  void Function(double soundLevel)? _onSoundLevelChanged;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> start({
    required void Function(String text) onText,
    required void Function(bool isListening) onListeningChanged,
    required void Function(String message) onError,
    void Function(double soundLevel)? onSoundLevelChanged,
  }) async {
    _onText = onText;
    _onListeningChanged = onListeningChanged;
    _onSoundLevelChanged = onSoundLevelChanged;
    _isListening = true;
    onListeningChanged(true);
    return true;
  }

  @override
  Future<void> stop() async {
    _isListening = false;
    _onListeningChanged?.call(false);
  }

  @override
  Future<void> dispose() => stop();

  void emitText(String text) => _onText?.call(text);

  void emitSoundLevel(double level) => _onSoundLevelChanged?.call(level);
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

  testWidgets('voice input stays inline and appends transcript', (
    tester,
  ) async {
    final speechInput = _FakeSpeechInput();
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
          home: PlannerAiChatScreen(speechInput: speechInput),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('planner-ai-voice')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('planner-ai-inline-voice-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('planner-ai-inline-voice-animation')),
      findsOneWidget,
    );
    expect(find.text('Plan Asistanı'), findsOneWidget);

    speechInput.emitSoundLevel(-8);
    speechInput.emitText('Yarın yürüyüş yapacağım');
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Yarın yürüyüş yapacağım'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('planner-ai-inline-voice-accept')),
    );
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('planner-ai-input')),
    );
    expect(input.controller?.text, 'Yarın yürüyüş yapacağım');
    expect(
      find.byKey(const ValueKey('planner-ai-inline-voice-panel')),
      findsNothing,
    );
  });
}
