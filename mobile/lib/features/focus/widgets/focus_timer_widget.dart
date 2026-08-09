import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimio/core/l10n/app_strings.dart';
import 'package:mimio/core/models/models.dart';
import 'package:mimio/core/theme/mimio_theme.dart';
import 'package:mimio/features/providers.dart';

class FocusTimerWidget extends ConsumerStatefulWidget {
  const FocusTimerWidget({
    super.key,
    required this.session,
    this.size = 220,
    this.showLabel = true,
    this.inverted = false,
    this.interactive = false,
  });

  final FocusSessionModel session;
  final double size;
  final bool showLabel;
  final bool inverted;
  final bool interactive;

  @override
  ConsumerState<FocusTimerWidget> createState() => _FocusTimerWidgetState();
}

class _FocusTimerWidgetState extends ConsumerState<FocusTimerWidget> {
  double? _dragProgress;

  void _seek(double progress) {
    setState(() => _dragProgress = progress);
    ref
        .read(focusSessionProvider.notifier)
        .seekToProgress(progress, persist: false);
  }

  void _finishSeek(double progress) {
    ref
        .read(focusSessionProvider.notifier)
        .seekToProgress(progress, persist: true);
    setState(() => _dragProgress = null);
  }

  String _remainingFormatted(FocusSessionModel session, double progress) {
    final total = session.durationMinutes * 60;
    final remaining = ((1 - progress) * total).round().clamp(0, total);
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final session = widget.interactive
        ? ref.watch(focusSessionProvider).valueOrNull ?? widget.session
        : widget.session;
    final progress = (_dragProgress ?? session.progressPercent / 100).clamp(
      0.0,
      1.0,
    );
    final compact = widget.size <= 100;
    final color = widget.inverted
        ? Colors.white
        : Theme.of(context).colorScheme.primary;
    final trackColor = widget.inverted
        ? Colors.white.withValues(alpha: 0.22)
        : context.palette.surfaceMuted;
    final textColor = widget.inverted
        ? Colors.white
        : context.palette.textPrimary;
    final subtextColor = widget.inverted
        ? Colors.white70
        : context.palette.textSecondary;
    final displayRemaining = _dragProgress == null
        ? session.remainingFormatted
        : _remainingFormatted(session, progress);

    return Container(
      width: widget.size,
      constraints: BoxConstraints(minHeight: compact ? 72 : widget.size * 0.72),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 24,
        vertical: compact ? 10 : 24,
      ),
      decoration: BoxDecoration(
        color: widget.inverted
            ? Colors.white.withValues(alpha: 0.1)
            : context.palette.surface,
        borderRadius: BorderRadius.circular(compact ? 16 : 24),
        border: Border.all(
          color: widget.inverted
              ? Colors.white.withValues(alpha: 0.18)
              : context.palette.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (session.isPaused && !compact) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: MimioColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                s.pausedUpper,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: MimioColors.warning,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            displayRemaining,
            maxLines: 1,
            style: TextStyle(
              fontSize: compact ? 18 : widget.size * 0.18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: textColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (widget.showLabel && !compact) ...[
            const SizedBox(height: 4),
            Text(
              widget.interactive ? s.timerDragHint : s.remainingTime,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: subtextColor),
            ),
          ],
          SizedBox(height: compact ? 8 : 18),
          if (widget.interactive)
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                inactiveTrackColor: trackColor,
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.1),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: progress,
                onChanged: _seek,
                onChangeEnd: _finishSeek,
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: compact ? 5 : 7,
                color: color,
                backgroundColor: trackColor,
              ),
            ),
        ],
      ),
    );
  }
}
