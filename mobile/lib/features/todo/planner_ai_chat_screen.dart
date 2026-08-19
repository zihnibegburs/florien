import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/services/planner_ai_service.dart';
import 'package:florien/core/services/speech_input_service.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_ai.dart';
import 'package:florien/core/widgets/florien_ai_animation.dart';
import 'package:florien/core/widgets/florien_buttons.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/services/task_icon_classifier.dart';

class PlannerAiChatScreen extends ConsumerStatefulWidget {
  const PlannerAiChatScreen({super.key, this.speechInput});

  final SpeechInput? speechInput;

  @override
  ConsumerState<PlannerAiChatScreen> createState() =>
      _PlannerAiChatScreenState();
}

class _PlannerAiChatScreenState extends ConsumerState<PlannerAiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_PlannerChatMessage>[
    _PlannerChatMessage(
      role: 'assistant',
      text:
          'Merhaba! Yapmak istediklerini anlat; onları net, uygulanabilir görevlere dönüştüreyim.',
    ),
  ];
  late final SpeechInput _speechInput;
  bool _sending = false;
  bool _voicePanelOpen = false;
  bool _isListening = false;
  double _soundLevel = 0.12;
  String _voiceTranscript = '';
  String? _voiceError;
  int _voiceSession = 0;

  @override
  void initState() {
    super.initState();
    _speechInput = widget.speechInput ?? SpeechInputService();
  }

  @override
  void dispose() {
    unawaited(_speechInput.dispose());
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openVoiceInput() async {
    FocusScope.of(context).unfocus();
    if (!_voicePanelOpen) {
      setState(() {
        _voicePanelOpen = true;
        _voiceTranscript = '';
        _voiceError = null;
        _soundLevel = 0.12;
      });
    }
    await _startVoiceListening();
  }

  Future<void> _startVoiceListening() async {
    if (_isListening) return;
    final session = ++_voiceSession;
    if (!_voicePanelOpen) {
      setState(() => _voicePanelOpen = true);
    }
    setState(() => _voiceError = null);

    final started = await _speechInput.start(
      onText: (text) {
        if (!mounted || !_voicePanelOpen || session != _voiceSession) return;
        setState(() => _voiceTranscript = text);
      },
      onListeningChanged: (isListening) {
        if (!mounted || !_voicePanelOpen || session != _voiceSession) return;
        setState(() => _isListening = isListening);
      },
      onError: (message) {
        if (!mounted || !_voicePanelOpen || session != _voiceSession) return;
        setState(() {
          _isListening = false;
          _voiceError = message;
        });
      },
      onSoundLevelChanged: (level) {
        if (!mounted || !_voicePanelOpen || session != _voiceSession) return;
        final normalized = level < 0
            ? ((level + 55) / 55).clamp(0.08, 1.0)
            : (level / 18).clamp(0.08, 1.0);
        setState(() => _soundLevel = normalized.toDouble());
      },
    );

    if (!mounted || !_voicePanelOpen || session != _voiceSession) {
      if (started) await _speechInput.stop();
      return;
    }
    if (!started) setState(() => _isListening = false);
  }

  Future<void> _toggleVoiceListening() async {
    if (_isListening) {
      ++_voiceSession;
      await _speechInput.stop();
      if (!mounted || !_voicePanelOpen) return;
      setState(() => _isListening = false);
      return;
    }
    await _startVoiceListening();
  }

  Future<void> _closeVoiceInput() async {
    ++_voiceSession;
    await _speechInput.stop();
    if (!mounted) return;
    setState(() {
      _voicePanelOpen = false;
      _isListening = false;
      _voiceTranscript = '';
      _voiceError = null;
      _soundLevel = 0.12;
    });
  }

  Future<void> _acceptVoiceInput() async {
    final spokenText = _voiceTranscript.trim();
    if (spokenText.isEmpty) return;
    ++_voiceSession;
    await _speechInput.stop();
    if (!mounted) return;

    final existingText = _controller.text.trim();
    final text = existingText.isEmpty
        ? spokenText
        : '$existingText $spokenText';
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {
      _voicePanelOpen = false;
      _isListening = false;
      _voiceTranscript = '';
      _voiceError = null;
      _soundLevel = 0.12;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    FocusScope.of(context).unfocus();
    _controller.clear();
    setState(() {
      _messages.add(_PlannerChatMessage(role: 'user', text: text));
      _sending = true;
    });
    _scrollToBottom();

    try {
      final conversation = _messages
          .map(
            (message) =>
                PlannerChatTurn(role: message.role, content: message.text),
          )
          .toList(growable: false);
      final reply = await ref.read(plannerAiGatewayProvider).send(conversation);
      if (!mounted) return;
      setState(() {
        _messages.add(
          _PlannerChatMessage(
            role: 'assistant',
            text: reply.message,
            tasks: reply.tasks,
          ),
        );
      });
    } catch (error, stackTrace) {
      debugPrint('Planner AI chat failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _messages.add(
          _PlannerChatMessage(
            role: 'assistant',
            text: error is PlannerAiException
                ? error.message
                : 'Şu anda plan asistanına bağlanamadım. Biraz sonra tekrar deneyebilir misin?',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _approveTasks(int messageIndex) async {
    final message = _messages[messageIndex];
    if (message.tasks.isEmpty ||
        message.decision != _ProposalDecision.pending) {
      return;
    }
    setState(() => message.decision = _ProposalDecision.saving);
    try {
      for (final task in message.tasks) {
        final classification = await TaskIconClassifier.instance.classify(
          task.title,
          includeDebugCandidates: false,
        );
        await ref
            .read(inboxProvider.notifier)
            .addToInbox(
              title: task.title,
              durationMinutes: task.durationMinutes,
              icon: classification.category.storageName,
            );
      }
      if (!mounted) return;
      setState(() {
        message.decision = _ProposalDecision.approved;
        _messages.add(
          _PlannerChatMessage(
            role: 'assistant',
            text:
                '${message.tasks.length} görev To-do listene eklendi. İstersen yeni bir plan daha hazırlayabiliriz.',
          ),
        );
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => message.decision = _ProposalDecision.pending);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Görevler To-do listesine eklenemedi.')),
      );
    }
  }

  void _rejectTasks(int messageIndex) {
    final message = _messages[messageIndex];
    if (message.decision != _ProposalDecision.pending) return;
    setState(() {
      message.decision = _ProposalDecision.rejected;
      _messages.add(
        _PlannerChatMessage(
          role: 'assistant',
          text:
              'Tamam, bu taslakları eklemedim. Planı birlikte değiştirebiliriz.',
        ),
      );
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FlorienTheme.dark,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: context.palette.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            toolbarHeight: 78,
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            title: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: context.palette.surface.withValues(alpha: 0.46),
                borderRadius: BorderRadius.circular(FlorienRadius.pill),
                border: Border.all(
                  color: context.palette.textPrimary.withValues(alpha: 0.82),
                  width: FlorienBorders.thin,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: context.palette.textPrimary,
                      foregroundColor: context.palette.background,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Expanded(child: Center(child: Text('Plan Asistanı'))),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: FlorienColors.aiGradient,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.palette.border,
                        width: FlorienBorders.thin,
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: FlorienAiAnimation(
                        size: 36,
                        speed: 0.8,
                        semanticLabel: 'Florien AI',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    key: const ValueKey('planner-ai-message-list'),
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                    itemCount: _messages.length + (_sending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const _TypingBubble();
                      }
                      final message = _messages[index];
                      return _ChatMessageBubble(
                        message: message,
                        onApprove: () => unawaited(_approveTasks(index)),
                        onReject: () => _rejectTasks(index),
                      );
                    },
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _voicePanelOpen
                      ? _InlineVoiceCapturePanel(
                          isListening: _isListening,
                          soundLevel: _soundLevel,
                          transcript: _voiceTranscript,
                          error: _voiceError,
                          onToggleListening: () =>
                              unawaited(_toggleVoiceListening()),
                          onClose: () => unawaited(_closeVoiceInput()),
                          onAccept: () => unawaited(_acceptVoiceInput()),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('planner-ai-voice-panel-closed'),
                        ),
                ),
                FlorienAiInput(
                  controller: _controller,
                  enabled: !_sending,
                  onSend: () => unawaited(_send()),
                  inputKey: const ValueKey('planner-ai-input'),
                  sendKey: const ValueKey('planner-ai-send'),
                  voiceKey: const ValueKey('planner-ai-voice'),
                  isListening: _voicePanelOpen,
                  onVoiceTap: () {
                    if (_voicePanelOpen) {
                      unawaited(_closeVoiceInput());
                    } else {
                      unawaited(_openVoiceInput());
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineVoiceCapturePanel extends StatelessWidget {
  const _InlineVoiceCapturePanel({
    required this.isListening,
    required this.soundLevel,
    required this.transcript,
    required this.error,
    required this.onToggleListening,
    required this.onClose,
    required this.onAccept,
  });

  final bool isListening;
  final double soundLevel;
  final String transcript;
  final String? error;
  final VoidCallback onToggleListening;
  final VoidCallback onClose;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final hasTranscript = transcript.trim().isNotEmpty;
    final status =
        error ??
        (isListening
            ? 'Konuş, seni dinliyorum…'
            : hasTranscript
            ? 'Metni ekleyebilir veya dinlemeye devam edebilirsin.'
            : 'Hazır olduğunda dinlemeyi başlat.');

    return Padding(
      key: const ValueKey('planner-ai-inline-voice-panel'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(1.4),
        decoration: BoxDecoration(
          gradient: FlorienColors.aiGradient,
          borderRadius: BorderRadius.circular(FlorienRadius.xl),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(FlorienRadius.xl - 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isListening ? 'Sesli konuşma açık' : 'Sesli konuşma',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('planner-ai-inline-voice-close'),
                    tooltip: 'Sesli konuşmayı kapat',
                    visualDensity: VisualDensity.compact,
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: isListening
                        ? 'Dinlemeyi durdur'
                        : 'Dinlemeyi başlat',
                    child: InkWell(
                      key: const ValueKey('planner-ai-inline-voice-toggle'),
                      onTap: onToggleListening,
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: FlorienAiAnimation(
                          key: const ValueKey(
                            'planner-ai-inline-voice-animation',
                          ),
                          size: 82,
                          animate: isListening,
                          speed: florienAiVoiceAnimationSpeed(
                            isListening: isListening,
                            soundLevel: soundLevel,
                          ),
                          semanticLabel: isListening
                              ? 'Florien AI dinliyor'
                              : 'Florien AI dinlemeye hazır',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasTranscript ? transcript : status,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: error == null
                                ? context.palette.textPrimary
                                : context.palette.error,
                            fontSize: 14,
                            fontWeight: hasTranscript
                                ? FontWeight.w700
                                : FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                        if (hasTranscript) ...[
                          const SizedBox(height: 3),
                          Text(
                            status,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey(
                        'planner-ai-inline-voice-listen-toggle',
                      ),
                      onPressed: onToggleListening,
                      icon: Icon(
                        isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        size: 18,
                      ),
                      label: Text(isListening ? 'Durdur' : 'Dinle'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('planner-ai-inline-voice-accept'),
                      onPressed: hasTranscript ? onAccept : null,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Metni ekle'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ProposalDecision { pending, saving, approved, rejected }

class _PlannerChatMessage {
  _PlannerChatMessage({
    required this.role,
    required this.text,
    this.tasks = const [],
  });

  final String role;
  final String text;
  final List<PlannerTaskSuggestion> tasks;
  _ProposalDecision decision = _ProposalDecision.pending;
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.message,
    required this.onApprove,
    required this.onReject,
  });

  final _PlannerChatMessage message;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return FlorienAiMessageBubble(
      isUser: isUser,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message.text,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          if (message.tasks.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final task in message.tasks) ...[
              _SuggestedTaskCard(task: task),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 6),
            if (message.decision == _ProposalDecision.pending)
              Row(
                children: [
                  Expanded(
                    child: FlorienSecondaryButton(
                      label: 'Reddet',
                      onPressed: onReject,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: FilledButton(
                        key: const ValueKey('planner-ai-approve'),
                        onPressed: onApprove,
                        child: const Text('To-do’ya ekle'),
                      ),
                    ),
                  ),
                ],
              )
            else
              _ProposalStatus(decision: message.decision),
          ],
        ],
      ),
    );
  }
}

class _SuggestedTaskCard extends StatelessWidget {
  const _SuggestedTaskCard({required this.task});

  final PlannerTaskSuggestion task;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('planner-ai-task-${task.title}'),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: context.palette.surfaceMuted,
      borderRadius: BorderRadius.circular(FlorienRadius.md),
      border: Border.all(
        color: context.palette.border,
        width: FlorienBorders.thin,
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: FlorienColors.primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: context.palette.border,
              width: FlorienBorders.thin,
            ),
          ),
          child: const Icon(
            Icons.task_alt_rounded,
            size: 18,
            color: FlorienColors.onPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                'To-do • ${_durationLabel(task.durationMinutes)}',
                style: TextStyle(
                  color: context.palette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProposalStatus extends StatelessWidget {
  const _ProposalStatus({required this.decision});

  final _ProposalDecision decision;

  @override
  Widget build(BuildContext context) {
    final saving = decision == _ProposalDecision.saving;
    final approved = decision == _ProposalDecision.approved;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (saving)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(
            approved ? Icons.check_circle_rounded : Icons.cancel_outlined,
            size: 18,
            color: approved
                ? FlorienColors.mint
                : context.palette.textSecondary,
          ),
        const SizedBox(width: 6),
        Text(
          saving
              ? 'Ekleniyor'
              : approved
              ? 'Eklendi'
              : 'Reddedildi',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) => FlorienAiMessageBubble(
    child: SizedBox(
      key: const ValueKey('planner-ai-typing'),
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: FlorienColors.primary,
      ),
    ),
  );
}

String _durationLabel(int minutes) {
  if (minutes < 60) return '$minutes dk';
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  if (remaining == 0) return '$hours sa';
  return '$hours sa $remaining dk';
}
