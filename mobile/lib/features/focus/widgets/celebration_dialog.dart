import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimio/core/l10n/app_strings.dart';
import 'package:mimio/core/models/models.dart';
import 'package:mimio/core/theme/mimio_theme.dart';
import 'package:mimio/core/widgets/mimio_soft_overlay.dart';
import 'package:mimio/features/providers.dart';

Future<void> showTaskCelebration(
  WidgetRef ref,
  TaskModel task,
  BuildContext context,
) {
  final s = ref.read(stringsProvider);
  final navigator = Navigator.of(context, rootNavigator: true);

  return showGeneralDialog<void>(
    context: navigator.context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: MimioOverlay.barrierColor,
    transitionDuration: MimioOverlay.transitionDuration,
    pageBuilder: (_, __, ___) {
      return _CelebrationDialog(
        event: CelebrationEvent(taskTitle: task.title, reward: task.reward),
        strings: s,
      );
    },
    transitionBuilder: (context, animation, _, child) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
      return MimioOverlay.softTransition(animation, child);
    },
  );
}

class _CelebrationDialog extends StatefulWidget {
  const _CelebrationDialog({required this.event, required this.strings});

  final CelebrationEvent event;
  final S strings;

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog> {
  late ConfettiController _controller;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
      _controller.play();
    });
    _autoDismissTimer = Timer(const Duration(seconds: 8), _close);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!animationsDisabled)
            IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _controller,
                  blastDirection: pi / 2,
                  maxBlastForce: 20,
                  minBlastForce: 8,
                  emissionFrequency: 0.05,
                  numberOfParticles: 20,
                  gravity: 0.12,
                  colors: const [
                    MimioColors.primary,
                    MimioColors.accent,
                    MimioColors.primaryLight,
                    MimioColors.warning,
                    MimioColors.success,
                  ],
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _CelebrationCard(
                event: widget.event,
                strings: widget.strings,
                onDismiss: _close,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CelebrationCard extends StatelessWidget {
  const _CelebrationCard({
    required this.event,
    required this.strings,
    required this.onDismiss,
  });

  final CelebrationEvent event;
  final S strings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: min(MediaQuery.sizeOf(context).width - 48, 360),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: MimioColors.primary.withValues(alpha: 0.18),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  MimioColors.primary.withValues(alpha: 0.15),
                  MimioColors.primaryLight.withValues(alpha: 0.25),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              event.hasReward
                  ? Icons.card_giftcard_rounded
                  : Icons.celebration_rounded,
              size: 36,
              color: MimioColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            strings.taskCompletedTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.taskCompletedSubtitle(event.taskTitle),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: context.palette.textSecondary,
              height: 1.4,
            ),
          ),
          if (event.hasReward) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFE66D).withValues(alpha: 0.35),
                    const Color(0xFFFF6B9D).withValues(alpha: 0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFFFE66D).withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFE6A800),
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        strings.yourReward,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB8860B),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    event.reward!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.palette.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.rewardReminder,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.palette.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDismiss,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(strings.awesome),
            ),
          ),
        ],
      ),
    );
  }
}
