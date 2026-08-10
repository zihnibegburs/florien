import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/storage/adhd_settings_storage.dart';
import 'package:florien/features/focus/widgets/break_timer_sheet.dart';
import 'package:florien/features/focus/widgets/celebration_dialog.dart';
import 'package:florien/features/focus/widgets/reward_timer_sheet.dart';
import 'package:florien/features/providers.dart';

Future<void> handleTaskCompleted(
  BuildContext context,
  WidgetRef ref,
  TaskModel task,
  TaskModel completed,
) async {
  final s = ref.read(stringsProvider);
  final prefs = ref.read(adhdPreferencesProvider).valueOrNull ?? const AdhdPreferences();

  if (completed.hasReward) {
    await showTaskCelebration(ref, completed, context);
    if (!context.mounted) return;
    if (prefs.rewardTimerMinutes > 0) {
      await showRewardTimerSheet(
        context,
        s,
        reward: completed.reward!,
        minutes: prefs.rewardTimerMinutes,
      );
    }
  }

  if (!context.mounted) return;

  if (prefs.breakAfterFocus) {
    await showBreakTimerSheet(context, s, minutes: prefs.breakDurationMinutes);
  }

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(s.taskCompletedUndo),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: s.undo,
        onPressed: () async {
          try {
            await ref.read(timelineProvider.notifier).uncompleteTask(task.id);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(s.friendlyTaskActionError(e)), backgroundColor: Colors.red.shade400),
              );
            }
          }
        },
      ),
    ),
  );
}
