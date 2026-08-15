import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/services/planner_ai_service.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_ai.dart';
import 'package:florien/core/widgets/florien_buttons.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/services/task_icon_classifier.dart';

class PlannerAiChatScreen extends ConsumerStatefulWidget {
  const PlannerAiChatScreen({super.key});

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
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: IconButton(
                tooltip: 'Kapat',
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: context.palette.surface,
                  foregroundColor: context.palette.textPrimary,
                  side: BorderSide(
                    color: context.palette.border,
                    width: FlorienBorders.thin,
                  ),
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: FlorienColors.aiGradient,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.palette.border,
                      width: FlorienBorders.thin,
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: FlorienColors.onPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Plan Asistanı'),
              ],
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
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
                FlorienAiInput(
                  controller: _controller,
                  enabled: !_sending,
                  onSend: () => unawaited(_send()),
                  inputKey: const ValueKey('planner-ai-input'),
                  sendKey: const ValueKey('planner-ai-send'),
                ),
              ],
            ),
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
            color: approved ? FlorienColors.mint : context.palette.textSecondary,
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
