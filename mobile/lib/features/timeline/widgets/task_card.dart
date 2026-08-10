import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/utils/task_icons.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/liquid_glass.dart';
import 'package:florien/features/providers.dart';

typedef SubtaskAction = void Function(TaskModel subtask);

class TaskCard extends ConsumerWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onStart,
    this.onPause,
    this.onComplete,
    this.onCancel,
    this.onDelete,
    this.onSubtaskTap,
    this.onSubtaskStart,
    this.onSubtaskPause,
    this.onSubtaskComplete,
    this.onSubtaskCancel,
  });

  final TaskModel task;
  final VoidCallback? onTap;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;
  final Future<void> Function()? onDelete;
  final SubtaskAction? onSubtaskTap;
  final SubtaskAction? onSubtaskStart;
  final SubtaskAction? onSubtaskPause;
  final SubtaskAction? onSubtaskComplete;
  final SubtaskAction? onSubtaskCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final session = ref.watch(focusSessionProvider).valueOrNull;
    final isFocused = session?.taskId == task.id;
    final isActive = isFocused && (session?.isActive ?? false);
    final isPaused = isFocused && (session?.isPaused ?? false);
    final color = FlorienColors.fromHex(task.color);
    final timeFormat = DateFormat('HH:mm');
    final startTime = task.scheduledAt != null
        ? timeFormat.format(task.scheduledAt!.toLocal())
        : '--:--';
    final endTime = task.scheduledAt != null
        ? timeFormat.format(task.endTime.toLocal())
        : '--:--';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: _SwipeToDelete(
        onDelete: onDelete,
        deleteLabel: s.delete,
        child: LiquidGlass(
          blur: false,
          borderRadius: BorderRadius.circular(20),
          tintOpacity: 1,
          boxShadow: isActive || isPaused
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : LiquidGlassTokens.elevation(context),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(18),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onTap,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 14,
                                        color: color,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '$startTime – $endTime',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        s.minutesShort(task.durationMinutes),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.palette.textSecondary,
                                        ),
                                      ),
                                      if (task.energyLevel != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: FlorienColors.warning
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            s.energyLabel(task.energyLevel!),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: FlorienColors.warning,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (task.hasSubtasks) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: FlorienColors.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            s.stepsProgress(
                                              task.completedSubtaskCount,
                                              task.subtasks.length,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: FlorienColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      if (onTap != null)
                                        Icon(
                                          Icons.more_horiz_rounded,
                                          size: 18,
                                          color: context.palette.textSecondary
                                              .withValues(alpha: 0.6),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      _CompletionRadio(
                                        isCompleted: task.isCompleted,
                                        accentColor: color,
                                        onTap: !task.isCompleted
                                            ? onComplete
                                            : null,
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
                                        ),
                                        child: Icon(
                                          TaskIcons.iconForTask(
                                            title: task.title,
                                            icon: task.icon,
                                          ),
                                          color: color,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          task.title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: task.isCompleted
                                                ? context.palette.textSecondary
                                                : context.palette.textPrimary,
                                            decoration: task.isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (task.hasMotivation &&
                                      !task.isCompleted) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.lightbulb_outline_rounded,
                                          size: 14,
                                          color: context.palette.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            task.motivation!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  context.palette.textSecondary,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (task.hasReward && !task.isCompleted) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.card_giftcard_rounded,
                                          size: 14,
                                          color: const Color(
                                            0xFFE6A800,
                                          ).withValues(alpha: 0.9),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            task.reward!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFB8860B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (task.hasSubtasks) ...[
                          const SizedBox(height: 8),
                          ...task.subtasks.map(
                            (sub) => _SubtaskRow(
                              subtask: sub,
                              parentColor: color,
                              s: s,
                              focusSession: session,
                              onTap: onSubtaskTap != null
                                  ? () => onSubtaskTap!(sub)
                                  : null,
                              onStart: onSubtaskStart != null
                                  ? () => onSubtaskStart!(sub)
                                  : null,
                              onPause: onSubtaskPause != null
                                  ? () => onSubtaskPause!(sub)
                                  : null,
                              onComplete: onSubtaskComplete != null
                                  ? () => onSubtaskComplete!(sub)
                                  : null,
                              onCancel: onSubtaskCancel != null
                                  ? () => onSubtaskCancel!(sub)
                                  : null,
                            ),
                          ),
                        ],
                        if ((isActive || isPaused) && !task.hasSubtasks) ...[
                          const SizedBox(height: 8),
                          _ActiveControls(
                            pauseLabel: isPaused ? s.continueLabel : s.pause,
                            finishLabel: s.finish,
                            cancelLabel: s.cancel,
                            onPause: onPause,
                            onComplete: onComplete,
                            onCancel: onCancel,
                          ),
                        ] else if (!task.isCompleted &&
                            !task.hasSubtasks &&
                            !isFocused) ...[
                          const SizedBox(height: 8),
                          _ActionChip(
                            label: s.start,
                            icon: Icons.play_arrow_rounded,
                            color: color,
                            onTap: onStart,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({
    required this.subtask,
    required this.parentColor,
    required this.s,
    this.focusSession,
    this.onTap,
    this.onStart,
    this.onPause,
    this.onComplete,
    this.onCancel,
  });

  final TaskModel subtask;
  final Color parentColor;
  final S s;
  final FocusSessionModel? focusSession;
  final VoidCallback? onTap;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final subColor = FlorienColors.fromHex(subtask.color);
    final isFocused = focusSession?.taskId == subtask.id;
    final isActive = isFocused && (focusSession?.isActive ?? false);
    final isPaused = isFocused && (focusSession?.isPaused ?? false);
    final timeFormat = DateFormat('HH:mm');
    final timeLabel = subtask.scheduledAt != null
        ? timeFormat.format(subtask.scheduledAt!.toLocal())
        : '';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? context.palette.textPrimary.withValues(alpha: 0.06)
            : subColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive || isPaused
              ? subColor.withValues(alpha: 0.6)
              : context.palette.border,
        ),
      ),
      child: Row(
        children: [
          _CompletionRadio(
            isCompleted: subtask.isCompleted,
            accentColor: subColor,
            size: 20,
            onTap: !subtask.isCompleted && !isFocused ? onComplete : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subtask.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: subtask.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: subtask.isCompleted
                              ? context.palette.textSecondary
                              : context.palette.textPrimary,
                        ),
                      ),
                      if (timeLabel.isNotEmpty)
                        Text(
                          '$timeLabel · ${s.minutesShort(subtask.durationMinutes)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.palette.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isActive || isPaused) ...[
            _MiniAction(
              icon: Icons.pause_rounded,
              color: FlorienColors.warning,
              onTap: onPause,
            ),
            const SizedBox(width: 4),
            _MiniAction(
              icon: Icons.close_rounded,
              color: FlorienColors.accent,
              onTap: onCancel,
            ),
            const SizedBox(width: 4),
            _MiniAction(
              icon: Icons.check_rounded,
              color: FlorienColors.success,
              onTap: onComplete,
            ),
          ] else if (!subtask.isCompleted && !isFocused) ...[
            _MiniAction(
              icon: Icons.play_arrow_rounded,
              color: parentColor,
              onTap: onStart,
            ),
          ],
          if (onTap != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onTap,
              child: Icon(
                Icons.more_horiz_rounded,
                size: 16,
                color: context.palette.textSecondary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompletionRadio extends StatelessWidget {
  const _CompletionRadio({
    required this.isCompleted,
    required this.accentColor,
    this.size = 22,
    this.onTap,
  });

  final bool isCompleted;
  final Color accentColor;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isCompleted
        ? FlorienColors.success
        : accentColor.withValues(alpha: 0.5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: SizedBox(
              width: size,
              height: size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? FlorienColors.success : Colors.transparent,
                  border: Border.all(color: borderColor, width: 1.8),
                ),
                child: isCompleted
                    ? Icon(
                        Icons.check_rounded,
                        size: size * 0.62,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.icon, required this.color, this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _ActiveControls extends StatelessWidget {
  const _ActiveControls({
    required this.pauseLabel,
    required this.finishLabel,
    required this.cancelLabel,
    this.onPause,
    this.onComplete,
    this.onCancel,
  });

  final String pauseLabel;
  final String finishLabel;
  final String cancelLabel;
  final VoidCallback? onPause;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onPause,
            icon: const Icon(Icons.pause_rounded, size: 18),
            label: Text(pauseLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: FlorienColors.warning,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: Text(cancelLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: FlorienColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onComplete,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(finishLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: FlorienColors.success,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeToDelete extends StatefulWidget {
  const _SwipeToDelete({
    required this.child,
    required this.deleteLabel,
    this.onDelete,
  });

  final Widget child;
  final String deleteLabel;
  final Future<void> Function()? onDelete;

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete>
    with SingleTickerProviderStateMixin {
  static const _actionWidth = 76.0;
  static const _borderRadius = 18.0;
  static const _dragResistance = 1.8;
  static const _openThreshold = 0.55;

  late final AnimationController _controller;
  late final Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _offset = Tween<double>(
      begin: 0,
      end: -_actionWidth,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() => _controller.forward();

  void _close() => _controller.reverse();

  Future<void> _handleDelete() async {
    await widget.onDelete?.call();
    if (mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onDelete == null) return widget.child;

    final cardRadius = BorderRadius.circular(_borderRadius);
    final surfaceColor = LiquidGlassTokens.tint(context, opacity: 1.0);

    return ClipRRect(
      borderRadius: cardRadius,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (_controller.value <= 0) return const SizedBox.shrink();
              return Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Material(
                      color: Colors.red.shade400,
                      child: InkWell(
                        onTap: _handleDelete,
                        child: SizedBox(
                          width: _actionWidth,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.deleteLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              _controller.value =
                  (_controller.value -
                          details.delta.dx / (_actionWidth * _dragResistance))
                      .clamp(0.0, 1.0);
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity > 500) {
                _close();
              } else if (_controller.value > _openThreshold ||
                  velocity < -650) {
                _open();
              } else {
                _close();
              }
            },
            child: AnimatedBuilder(
              animation: _offset,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_offset.value, 0),
                  child: ClipRRect(
                    borderRadius: cardRadius,
                    clipBehavior: Clip.antiAlias,
                    child: ColoredBox(color: surfaceColor, child: child),
                  ),
                );
              },
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
