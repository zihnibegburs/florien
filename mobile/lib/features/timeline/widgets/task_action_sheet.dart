import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/models/recurrence.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/core/widgets/florien_soft_overlay.dart';
import 'package:florien/features/timeline/widgets/delete_task_dialog.dart';
import 'package:florien/features/timeline/widgets/edit_task_sheet.dart';
import 'package:florien/features/timeline/widgets/subtask_breakdown_sheet.dart';

void showTaskActionSheet({
  required BuildContext context,
  required WidgetRef ref,
  required TaskModel task,
  required DateTime selectedDate,
  required Future<void> Function() onStart,
  required Future<void> Function() onPause,
  required Future<void> Function() onComplete,
  required Future<void> Function(DeleteRecurrenceScope scope) onDelete,
  Future<void> Function()? onUncomplete,
  VoidCallback? onFocus,
}) {
  final s = ref.read(stringsProvider);
  final session = ref.read(focusSessionProvider).valueOrNull;
  final isFocused = session?.taskId == task.id;
  final isActive = isFocused && (session?.isActive ?? false);
  final isPaused = isFocused && (session?.isPaused ?? false);
  final isSubtask = task.parentTaskId != null;
  final canBreakdown = !isSubtask && !task.hasSubtasks && !task.isCompleted;

  showFlorienBottomSheet(
    context: context,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: FlorienColors.fromHex(task.color),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.taskOptions,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          task.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (!task.isCompleted && !isFocused)
              _ActionTile(
                icon: Icons.play_arrow_rounded,
                label: s.startTask,
                color: FlorienColors.fromHex(task.color),
                onTap: () async {
                  Navigator.pop(ctx);
                  await onStart();
                },
              ),
            if (isActive || isPaused) ...[
              if (onFocus != null)
                _ActionTile(
                  icon: Icons.timer_rounded,
                  label: s.goToFocus,
                  color: FlorienColors.primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    onFocus();
                  },
                ),
              if (isActive)
                _ActionTile(
                  icon: Icons.pause_rounded,
                  label: s.pause,
                  color: FlorienColors.warning,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await onPause();
                  },
                ),
              if (isPaused)
                _ActionTile(
                  icon: Icons.play_arrow_rounded,
                  label: s.resume,
                  color: FlorienColors.fromHex(task.color),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await onPause();
                  },
                ),
            ],
            if (!task.isCompleted)
              _ActionTile(
                icon: Icons.check_rounded,
                label: s.complete,
                color: FlorienColors.success,
                onTap: () async {
                  Navigator.pop(ctx);
                  await onComplete();
                },
              ),
            if (task.isCompleted && onUncomplete != null)
              _ActionTile(
                icon: Icons.undo_rounded,
                label: s.undoComplete,
                color: FlorienColors.warning,
                onTap: () async {
                  Navigator.pop(ctx);
                  await onUncomplete();
                },
              ),
            _ActionTile(
              icon: Icons.edit_outlined,
              label: s.edit,
              onTap: () {
                Navigator.pop(ctx);
                showFlorienBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => EditTaskSheet(
                    task: task,
                    selectedDate: selectedDate,
                    showAiBreakdown: false,
                  ),
                );
              },
            ),
            if (canBreakdown)
              _ActionTile(
                icon: Icons.auto_awesome_rounded,
                label: s.splitSubtasks,
                color: FlorienColors.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  showFlorienBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => SubtaskBreakdownSheet(
                      task: task,
                      selectedDate: selectedDate,
                    ),
                  );
                },
              ),
            _ActionTile(
              icon: Icons.delete_outline_rounded,
              label: s.delete,
              color: Colors.red.shade400,
              destructive: true,
              onTap: () async {
                final scope = await showDeleteTaskDialog(context: ctx, s: s, task: task);
                if (scope != null && ctx.mounted) {
                  Navigator.pop(ctx);
                  await onDelete(scope);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? context.palette.textPrimary;

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: destructive ? Colors.red.shade400 : context.palette.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}
