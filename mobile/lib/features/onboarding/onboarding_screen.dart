import 'dart:async';

import 'package:florien/core/storage/onboarding_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_logo.dart';
import 'package:florien/features/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _onboardingQuestions = [
  _OnboardingQuestion(
    id: 'ONB-Q1',
    title: 'Gün içinde en sık hangisini yaşıyorsun?',
    answers: [
      _OnboardingChoice(
        id: 'mind_overload',
        label: 'Yapacaklarım kafamda birbirine giriyor',
      ),
      _OnboardingChoice(
        id: 'start_unclear',
        label: 'Nereden başlayacağımı bulamıyorum',
      ),
      _OnboardingChoice(
        id: 'switch_tasks',
        label: 'Bir şeye başlayıp başka bir şeye geçiyorum',
      ),
      _OnboardingChoice(
        id: 'time_blind',
        label: 'Zamanın nasıl geçtiğini anlamıyorum',
      ),
      _OnboardingChoice(
        id: 'multiple',
        label: 'Bunlardan birkaçı birden oluyor',
      ),
    ],
  ),
  _OnboardingQuestion(
    id: 'ONB-Q2',
    title: 'Bir işe başlaman gerektiğinde genelde ne yapıyorsun?',
    answers: [
      _OnboardingChoice(id: 'feels_big', label: 'Gözümde büyütüyorum'),
      _OnboardingChoice(
        id: 'waits_right_time',
        label: 'Doğru zamanı bekliyorum',
      ),
      _OnboardingChoice(
        id: 'small_task_avoidance',
        label: 'Başka küçük işlerle oyalanıyorum',
      ),
      _OnboardingChoice(id: 'last_minute', label: 'Son ana kadar erteliyorum'),
      _OnboardingChoice(id: 'varies', label: 'Duruma göre değişiyor'),
    ],
  ),
  _OnboardingQuestion(
    id: 'ONB-Q3',
    title: 'DEHB konusunda hangisi seni daha iyi anlatıyor?',
    answers: [
      _OnboardingChoice(id: 'diagnosed', label: 'DEHB tanısı aldım'),
      _OnboardingChoice(id: 'suspect', label: 'DEHB olabileceğimi düşünüyorum'),
      _OnboardingChoice(
        id: 'other_neurodiversity',
        label: 'Başka bir nöroçeşitliliğim var',
      ),
      _OnboardingChoice(
        id: 'none',
        label: 'Kendimi bunlardan biriyle tanımlamıyorum',
      ),
      _OnboardingChoice(id: 'unsure', label: 'Emin değilim'),
    ],
  ),
  _OnboardingQuestion(
    id: 'ONB-Q4',
    title: 'Yaptığın planlar genelde nasıl gidiyor?',
    answers: [
      _OnboardingChoice(
        id: 'starts_then_stops',
        label: 'Birkaç gün iyi gidiyor, sonra bırakıyorum',
      ),
      _OnboardingChoice(
        id: 'feels_big',
        label: 'Daha başlarken gözümde büyüyor',
      ),
      _OnboardingChoice(
        id: 'gives_up_after_slip',
        label: 'Bir şey aksayınca tamamen vazgeçiyorum',
      ),
      _OnboardingChoice(
        id: 'forgets_plan',
        label: 'Planı unutup akışına bırakıyorum',
      ),
      _OnboardingChoice(
        id: 'multiple',
        label: 'Bunlardan birkaçı birden oluyor',
      ),
    ],
  ),
  _OnboardingQuestion(
    id: 'ONB-Q5',
    title: 'Zaman konusunda en çok nerede zorlanıyorsun?',
    answers: [
      _OnboardingChoice(
        id: 'duration_unclear',
        label: 'Bir işin ne kadar süreceğini kestiremiyorum',
      ),
      _OnboardingChoice(
        id: 'still_late',
        label: 'Saate baksam da yine yetişemiyorum',
      ),
      _OnboardingChoice(
        id: 'loses_track',
        label: 'Bir işe dalınca diğerlerini unutuyorum',
      ),
      _OnboardingChoice(
        id: 'day_disappears',
        label: 'Günün nasıl bittiğini anlamıyorum',
      ),
      _OnboardingChoice(id: 'varies', label: 'Duruma göre değişiyor'),
    ],
  ),
  _OnboardingQuestion(
    id: 'ONB-Q6',
    title: 'Planlarını sürdüremedin. Ertesi gün kendine nasıl davranıyorsun?',
    answers: [
      _OnboardingChoice(id: 'self_critical', label: 'Kendime yükleniyorum'),
      _OnboardingChoice(
        id: 'start_over',
        label: 'Her şeye baştan başlamam gerektiğini düşünüyorum',
      ),
      _OnboardingChoice(id: 'quit_planning', label: 'Plan yapmayı bırakıyorum'),
      _OnboardingChoice(
        id: 'cannot_recover',
        label: 'Nasıl toparlanacağımı bulamıyorum',
      ),
      _OnboardingChoice(
        id: 'multiple',
        label: 'Bunlardan birkaçı birden oluyor',
      ),
    ],
  ),
  _OnboardingQuestion(
    id: 'ONB-Q7',
    title: 'Şu an en çok neye ihtiyacın var?',
    answers: [
      _OnboardingChoice(
        id: 'know_start',
        label: 'Nereden başlayacağımı bilmek',
      ),
      _OnboardingChoice(id: 'clear_head', label: 'Kafamı biraz toparlamak'),
      _OnboardingChoice(id: 'easier_day', label: 'Günü daha kolay geçirmek'),
      _OnboardingChoice(id: 'sustain', label: 'Başladığım şeyi sürdürebilmek'),
      _OnboardingChoice(id: 'unsure', label: 'Henüz bilmiyorum'),
    ],
  ),
];

const _alwaysRestartOnboardingForTesting = true;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  int _selectionToken = 0;
  bool _initialized = false;
  bool _testSessionPrepared = false;
  bool _transitioning = false;
  bool _finishing = false;

  Future<void> _selectAnswer(
    _OnboardingQuestion question,
    _OnboardingChoice answer,
  ) async {
    if (_transitioning) return;
    final selectionToken = ++_selectionToken;
    setState(() => _transitioning = true);
    try {
      final save = ref
          .read(onboardingPreferencesProvider.notifier)
          .recordOnboardingAnswer(questionId: question.id, answerId: answer.id);
      await Future.wait([
        save,
        Future<void>.delayed(const Duration(milliseconds: 240)),
      ]);
      if (!mounted || selectionToken != _selectionToken) return;
      setState(() {
        _step = (_step + 1).clamp(0, _onboardingQuestions.length + 1);
        _transitioning = false;
      });
    } catch (_) {
      if (!mounted || selectionToken != _selectionToken) return;
      setState(() => _transitioning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yanıt kaydedilemedi. Tekrar dene.')),
      );
    }
  }

  Future<void> _finish() async {
    final preferences = ref.read(onboardingPreferencesProvider).valueOrNull;
    final allAnswered = _onboardingQuestions.every(
      (question) => preferences?.answerIdFor(question.id) != null,
    );
    if (!allAnswered || _finishing) return;
    setState(() => _finishing = true);
    try {
      await ref
          .read(onboardingPreferencesProvider.notifier)
          .completeOnboarding();
      if (mounted) context.go(_routeAfterOnboarding());
    } catch (_) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Onboarding tamamlanamadı. Tekrar dene.')),
      );
    }
  }

  void _start() => setState(() => _step = 1);

  String _routeAfterOnboarding() =>
      ref.read(authStateProvider).valueOrNull == null ? '/login' : '/todo';

  void _back() {
    _selectionToken++;
    setState(() {
      _transitioning = false;
      _step = (_step - 1).clamp(0, _onboardingQuestions.length + 1);
    });
  }

  int _initialStep(OnboardingPreferences preferences) {
    if (preferences.answers.isEmpty) return 0;
    final unansweredIndex = _onboardingQuestions.indexWhere(
      (question) => preferences.answerIdFor(question.id) == null,
    );
    return unansweredIndex == -1
        ? _onboardingQuestions.length + 1
        : unansweredIndex + 1;
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = ref.watch(onboardingPreferencesProvider);
    return Theme(
      data: FlorienTheme.dark,
      child: Builder(
        builder: (context) => onboarding.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => const Scaffold(
            body: Center(child: Text('Onboarding yüklenemedi.')),
          ),
          data: (preferences) {
            if (_alwaysRestartOnboardingForTesting && !_testSessionPrepared) {
              _testSessionPrepared = true;
              if (preferences.completed || preferences.answers.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  ref
                      .read(onboardingPreferencesProvider.notifier)
                      .restartOnboarding();
                });
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
            }
            if (preferences.completed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) context.go(_routeAfterOnboarding());
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!_initialized) {
              _initialized = true;
              _step = _initialStep(preferences);
            }
            return _OnboardingFrame(
              answeredCount: _onboardingQuestions
                  .where(
                    (question) => preferences.answerIdFor(question.id) != null,
                  )
                  .length,
              onBack: _step == 0 ? null : _back,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _content(preferences),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _content(OnboardingPreferences preferences) {
    if (_step == 0) {
      return _OpeningStep(
        key: const ValueKey('onboarding-opening'),
        onStart: _start,
      );
    }
    if (_step > _onboardingQuestions.length) {
      return _ClosingStep(
        key: const ValueKey('onboarding-closing'),
        finishing: _finishing,
        onFinish: _finish,
      );
    }

    final question = _onboardingQuestions[_step - 1];
    return _QuestionStep(
      key: ValueKey(question.id),
      question: question,
      selectedAnswerId: preferences.answerIdFor(question.id),
      interactionEnabled: !_transitioning,
      onSelected: (answer) => _selectAnswer(question, answer),
    );
  }
}

class _OnboardingFrame extends StatelessWidget {
  const _OnboardingFrame({
    required this.answeredCount,
    required this.child,
    this.onBack,
  });

  final int answeredCount;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.background,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: onBack == null
                            ? null
                            : IconButton(
                                key: const ValueKey('onboarding-back'),
                                tooltip: 'Geri',
                                onPressed: onBack,
                                style: IconButton.styleFrom(
                                  backgroundColor: context.palette.surface,
                                  foregroundColor: context.palette.textPrimary,
                                  side: BorderSide(
                                    color: context.palette.border,
                                    width: FlorienBorders.thin,
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          label:
                              'Onboarding ilerlemesi: $answeredCount / ${_onboardingQuestions.length}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              FlorienRadius.pill,
                            ),
                            child: LinearProgressIndicator(
                              minHeight: 8,
                              value:
                                  answeredCount / _onboardingQuestions.length,
                              color: FlorienColors.aiAccent,
                              backgroundColor: context.palette.surfaceMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '$answeredCount/${_onboardingQuestions.length}',
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: context.palette.textSecondary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _OpeningStep extends StatelessWidget {
  const _OpeningStep({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: FlorienColors.aiGradient,
            border: Border.all(
              color: context.palette.textPrimary,
              width: FlorienBorders.thin,
            ),
          ),
          child: const FlorienLogo(size: 92),
        ),
      ),
      const SizedBox(height: 36),
      Text(
        'Bazen plan yapmak bile yorucu gelebilir.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontSize: 34,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Seni daha iyi anlamak için birkaç kısa sorumuz var.',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: context.palette.textSecondary),
      ),
      const SizedBox(height: 40),
      FilledButton.icon(
        key: const ValueKey('onboarding-start'),
        onPressed: onStart,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('Başlayalım'),
      ),
    ],
  );
}

class _QuestionStep extends StatelessWidget {
  const _QuestionStep({
    super.key,
    required this.question,
    required this.selectedAnswerId,
    required this.interactionEnabled,
    required this.onSelected,
  });

  final _OnboardingQuestion question;
  final String? selectedAnswerId;
  final bool interactionEnabled;
  final ValueChanged<_OnboardingChoice> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 620;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question.title,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontSize: compact ? 27 : 31,
              height: 1.08,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: compact ? 18 : 28),
          Expanded(
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < question.answers.length;
                  index++
                ) ...[
                  Expanded(
                    child: _AnswerCard(
                      answer: question.answers[index],
                      selected: selectedAnswerId == question.answers[index].id,
                      enabled: interactionEnabled,
                      onTap: () => onSelected(question.answers[index]),
                    ),
                  ),
                  if (index != question.answers.length - 1)
                    SizedBox(height: compact ? 8 : 10),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.answer,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final _OnboardingChoice answer;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? FlorienColors.onPrimary
        : context.palette.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: answer.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('onboarding-answer-${answer.id}'),
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(FlorienRadius.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? FlorienColors.primary : context.palette.surface,
              borderRadius: BorderRadius.circular(FlorienRadius.md),
              border: Border.all(
                color: selected
                    ? FlorienColors.onPrimary
                    : context.palette.border,
                width: selected ? FlorienBorders.medium : FlorienBorders.thin,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    answer.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? FlorienColors.onPrimary : foreground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClosingStep extends StatelessWidget {
  const _ClosingStep({
    super.key,
    required this.finishing,
    required this.onFinish,
  });

  final bool finishing;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Center(child: FlorienLogo(size: 104)),
      const SizedBox(height: 34),
      Text(
        'Yalnız değilsin.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontSize: 36,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Her gün kusursuz gitmek zorunda değil. Florien, dağıldığında kaldığın yerden devam etmene yardım eder.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: context.palette.textSecondary,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 40),
      FilledButton.icon(
        key: const ValueKey('onboarding-finish'),
        onPressed: finishing ? null : onFinish,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: Text(finishing ? 'Hazırlanıyor…' : 'Devam et'),
      ),
    ],
  );
}

class _OnboardingQuestion {
  const _OnboardingQuestion({
    required this.id,
    required this.title,
    required this.answers,
  });

  final String id;
  final String title;
  final List<_OnboardingChoice> answers;
}

class _OnboardingChoice {
  const _OnboardingChoice({required this.id, required this.label});

  final String id;
  final String label;
}
