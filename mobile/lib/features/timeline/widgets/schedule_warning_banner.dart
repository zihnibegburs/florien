import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/liquid_glass.dart';
import 'package:florien/core/utils/schedule_utils.dart';

class ScheduleWarningBanner extends ConsumerWidget {
  const ScheduleWarningBanner({super.key, required this.tasks});

  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final conflicts = detectScheduleConflicts(tasks);
    if (conflicts.isEmpty) return const SizedBox.shrink();

    final first = conflicts.first;
    final message = first.isTight
        ? s.scheduleTight(first.taskA.title, first.taskB.title)
        : s.scheduleOverlap(
            first.taskA.title,
            first.taskB.title,
            first.overlapMinutes,
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: LiquidGlass(
        blur: false,
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(14),
        gradient: LinearGradient(
          colors: [
            FlorienColors.warning.withValues(alpha: 0.18),
            FlorienColors.warning.withValues(alpha: 0.08),
          ],
        ),
        tintOpacity: 1,
        child: Row(
          children: [
            Icon(Icons.schedule_rounded, color: FlorienColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.scheduleWarning,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.palette.textSecondary,
                    ),
                  ),
                  if (conflicts.length > 1)
                    Text(
                      '+${conflicts.length - 1}',
                      style: TextStyle(
                        fontSize: 11,
                        color: FlorienColors.warning.withValues(alpha: 0.9),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
