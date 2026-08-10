import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/liquid_glass.dart';

class DayProgressCard extends ConsumerWidget {
  const DayProgressCard({super.key, required this.tasks});

  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final total = tasks.length;
    final completed = tasks.where((t) => t.isCompleted).length;
    final active = tasks.where((t) => t.isActive).length;
    final progress = total == 0 ? 0.0 : completed / total;

    return LiquidGlass(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      borderRadius: BorderRadius.circular(24),
      blur: false,
      padding: const EdgeInsets.all(16),
      tintColor: context.palette.surface,
      tintOpacity: 1,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.palette.primaryMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              progress >= 1 ? Icons.done_all_rounded : Icons.today_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total == 0 ? s.dayEmpty : s.tasksCompleted(completed, total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  active > 0
                      ? s.oneTaskActive
                      : total == 0
                      ? s.addFirstTaskHint
                      : s.tasksRemaining(total - completed),
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: Theme.of(context).colorScheme.primary,
                    backgroundColor: context.palette.surfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (active > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: FlorienColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_arrow_rounded,
                    size: 16,
                    color: FlorienColors.success,
                  ),
                  Text(
                    s.active,
                    style: const TextStyle(
                      color: FlorienColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              total == 0 ? '—' : '${(progress * 100).round()}%',
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
