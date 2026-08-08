import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mimio/core/l10n/app_strings.dart';
import 'package:mimio/core/models/models.dart';
import 'package:mimio/features/providers.dart';
import 'package:mimio/features/timeline/home_tab.dart';
import 'package:mimio/features/timeline/task_completion_helper.dart';

Future<void> startTaskAndOpenFocus(
  BuildContext context,
  WidgetRef ref,
  String taskId,
) async {
  final s = ref.read(stringsProvider);
  try {
    await ref.read(timelineProvider.notifier).startTask(taskId);
    ref.read(homeTabProvider.notifier).state = HomeTab.focus;
    if (!context.mounted) return;
    // Prefer the Focus tab; close any overlay routes (e.g. /focus).
    final router = GoRouter.of(context);
    if (router.state.matchedLocation != '/home') {
      router.go('/home');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.friendlyTaskActionError(e)),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }
}

Future<void> toggleFocusPause(
  BuildContext context,
  WidgetRef ref,
  FocusSessionModel session,
) async {
  final s = ref.read(stringsProvider);
  try {
    if (session.isStandalone) {
      if (session.isActive) {
        await ref.read(focusSessionProvider.notifier).pause();
      } else {
        await ref.read(focusSessionProvider.notifier).resume();
      }
    } else if (session.isActive) {
      await ref.read(timelineProvider.notifier).pauseTask(session.taskId);
    } else {
      await ref.read(timelineProvider.notifier).resumeTask(session.taskId);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.friendlyTaskActionError(e)),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }
}

Future<void> finishFocusSession(
  BuildContext context,
  WidgetRef ref,
  FocusSessionModel session, {
  VoidCallback? onDone,
}) async {
  final s = ref.read(stringsProvider);
  try {
    if (session.isStandalone) {
      await ref.read(focusSessionProvider.notifier).clearSession();
      onDone?.call();
      return;
    }

    final completed =
        await ref.read(timelineProvider.notifier).completeTask(session.taskId);
    if (!context.mounted) return;
    await handleTaskCompleted(context, ref, completed, completed);
    onDone?.call();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.friendlyTaskActionError(e)),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }
}
