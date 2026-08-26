import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/services/planner_ai_service.dart';
import 'package:florien/core/services/speech_input_service.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_ai_animation.dart';
import 'package:florien/features/premium/premium_membership.dart';
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
  Completer<void>? _stopGate;
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
    final stopGate = _stopGate;
    if (stopGate != null) {
      await stopGate.future;
      _stopGate = null;
    }
    _isListening = false;
    _onListeningChanged?.call(false);
  }

  @override
  Future<void> dispose() => stop();

  void emitText(String text) => _onText?.call(text);

  void emitSoundLevel(double level) => _onSoundLevelChanged?.call(level);

  void delayNextStop() => _stopGate = Completer<void>();

  void completeStop() => _stopGate?.complete();
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

class _PremiumMembershipNotifier extends PremiumMembershipNotifier {
  @override
  Future<PremiumMembership> build() async => PremiumMembership(
    storeAvailable: false,
    isPremium: true,
    premiumUntil: DateTime.now().add(const Duration(days: 30)),
  );
}

class _FreeQuotaExhaustedPremiumNotifier extends PremiumMembershipNotifier {
  static final membership = PremiumMembership(
    storeAvailable: false,
    aiChatUsage: AiChatUsage(usedThisMonth: 3, limitThisMonth: 3),
  );

  @override
  Future<PremiumMembership> build() async => membership;

  @override
  Future<void> refreshEntitlement() async {
    state = AsyncData(membership);
  }
}

void main() {
  setUp(_AiInboxNotifier.addedTasks.clear);

  testWidgets('exhausted free quota locks input and opens premium on tap', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannerAiGatewayProvider.overrideWithValue(_FakePlannerAiGateway()),
          inboxProvider.overrideWith(_AiInboxNotifier.new),
          premiumMembershipProvider.overrideWith(
            _FreeQuotaExhaustedPremiumNotifier.new,
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const PlannerAiChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ne yapmak istiyorsun?'), findsOneWidget);
    expect(
      find.text(
        'Ücretsiz mesaj hakkın bitti. Sınırsız AI sohbet için Premium gerekli.',
      ),
      findsNothing,
    );
    expect(find.textContaining('ücretsiz AI mesaj hakkın'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('planner-ai-input')));
    await tester.pumpAndSettle();

    expect(find.text('Florien Premium'), findsWidgets);
    expect(find.byKey(const ValueKey('planner-ai-voice')), findsNothing);
  });

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
          premiumMembershipProvider.overrideWith(
            _PremiumMembershipNotifier.new,
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const PlannerAiChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('planner-ai-voice')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('planner-ai-mode-switcher')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('planner-ai-header-image')),
      findsOneWidget,
    );

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
          premiumMembershipProvider.overrideWith(
            _PremiumMembershipNotifier.new,
          ),
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
    await tester.pump(const Duration(milliseconds: 320));

    expect(
      find.byKey(const ValueKey('planner-ai-inline-voice-area')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('planner-ai-text-input-mode')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('planner-ai-mode-switcher')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('planner-ai-inline-voice-animation')),
      findsOneWidget,
    );
    final listeningAnimation = tester.widget<FlorienAiAnimation>(
      find.byKey(const ValueKey('planner-ai-inline-voice-animation')),
    );
    expect(listeningAnimation.assetName, florienListeningAnimationAsset);
    expect(listeningAnimation.tintColor, FlorienColors.aiAccent);
    expect(listeningAnimation.size, 176);
    expect(
      find.byKey(const ValueKey('florien-listening-lottie')),
      findsOneWidget,
    );
    expect(
      tester
          .getCenter(
            find.byKey(const ValueKey('planner-ai-inline-voice-animation')),
          )
          .dy,
      lessThan(
        tester
            .getCenter(
              find.byKey(const ValueKey('planner-ai-inline-voice-accept')),
            )
            .dy,
      ),
    );
    expect(find.text('Florien AI'), findsWidgets);

    speechInput.emitSoundLevel(-8);
    speechInput.emitText('Yarın yürüyüş yapacağım');
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Yarın yürüyüş yapacağım'), findsOneWidget);
    speechInput.delayNextStop();
    await tester.tap(
      find.byKey(const ValueKey('planner-ai-inline-voice-accept')),
    );
    await tester.pump();

    expect(find.text('Ekleniyor'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('planner-ai-inline-voice-area')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('planner-ai-inline-voice-accept')),
      findsOneWidget,
    );

    speechInput.completeStop();
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('planner-ai-input')),
    );
    expect(input.controller?.text, 'Yarın yürüyüş yapacağım');
    expect(
      find.byKey(const ValueKey('planner-ai-inline-voice-area')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('planner-ai-text-input-mode')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('planner-ai-mode-switcher')),
      findsOneWidget,
    );
  });

  testWidgets('chat composer caps input at 1000 characters', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannerAiGatewayProvider.overrideWithValue(_FakePlannerAiGateway()),
          inboxProvider.overrideWith(_AiInboxNotifier.new),
          premiumMembershipProvider.overrideWith(
            _PremiumMembershipNotifier.new,
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const PlannerAiChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey('planner-ai-input'));
    expect(
      tester.widget<TextField>(input).maxLength,
      plannerAiChatMaxCharacters,
    );

    await tester.enterText(input, 'a' * (plannerAiChatMaxCharacters + 80));
    await tester.pump();

    expect(
      tester.widget<TextField>(input).controller?.text.runes.length,
      plannerAiChatMaxCharacters,
    );
    expect(find.byKey(const ValueKey('planner-ai-char-count')), findsOneWidget);
    expect(
      find.text('$plannerAiChatMaxCharacters / $plannerAiChatMaxCharacters'),
      findsOneWidget,
    );
  });

  testWidgets('AI mode chips follow the app language', (tester) async {
    ActiveLanguage.code = 'en';
    addTearDown(() => ActiveLanguage.code = 'tr');
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannerAiGatewayProvider.overrideWithValue(_FakePlannerAiGateway()),
          inboxProvider.overrideWith(_AiInboxNotifier.new),
          premiumMembershipProvider.overrideWith(
            _PremiumMembershipNotifier.new,
          ),
          stringsProvider.overrideWithValue(const S('en')),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const PlannerAiChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('planner-ai-mode-focus')), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('Odak'), findsNothing);
  });
}
