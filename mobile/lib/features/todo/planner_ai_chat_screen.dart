import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/services/planner_ai_service.dart';
import 'package:florien/core/theme/florien_theme.dart';
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _PlannerChatMessage(
            role: 'assistant',
            text:
                'Şu anda plan asistanına bağlanamadım. Biraz sonra tekrar deneyebilir misin?',
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: IconButton(
          tooltip: 'Kapat',
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: context.palette.surfaceMuted,
          ),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      title: const Text('Plan Asistanı'),
      centerTitle: true,
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              key: const ValueKey('planner-ai-message-list'),
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
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
          _ChatComposer(
            controller: _controller,
            enabled: !_sending,
            onSend: () => unawaited(_send()),
          ),
        ],
      ),
    ),
  );
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
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser
              ? context.palette.surfaceMuted
              : FlorienColors.primary.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isUser
                ? context.palette.border
                : FlorienColors.primary.withValues(alpha: .2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message.text, style: const TextStyle(fontSize: 15.5)),
            if (message.tasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final task in message.tasks) ...[
                _SuggestedTaskCard(task: task),
                const SizedBox(height: 7),
              ],
              const SizedBox(height: 5),
              if (message.decision == _ProposalDecision.pending)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReject,
                        child: const Text('Reddet'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('planner-ai-approve'),
                        onPressed: onApprove,
                        child: const Text('To-do’ya ekle'),
                      ),
                    ),
                  ],
                )
              else
                _ProposalStatus(decision: message.decision),
            ],
          ],
        ),
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
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: context.palette.border),
    ),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: FlorienColors.primary.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.task_alt_rounded,
            size: 18,
            color: FlorienColors.primary,
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
            color: approved ? Colors.green : context.palette.textSecondary,
          ),
        const SizedBox(width: 6),
        Text(
          saving
              ? 'Ekleniyor'
              : approved
              ? 'Eklendi'
              : 'Reddedildi',
        ),
      ],
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      key: const ValueKey('planner-ai-typing'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FlorienColors.primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 3, 5, 3),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('planner-ai-input'),
              controller: controller,
              enabled: enabled,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Ne yapmak istiyorsun?',
                border: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          IconButton.filled(
            key: const ValueKey('planner-ai-send'),
            tooltip: 'Gönder',
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
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
