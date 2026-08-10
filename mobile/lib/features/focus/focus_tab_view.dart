import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/focus/focus_session_actions.dart';
import 'package:florien/features/focus/widgets/focus_timer_widget.dart';
import 'package:florien/features/focus/widgets/body_doubling_panel.dart';
import 'package:florien/features/focus/widgets/start_focus_sheet.dart';
import 'package:florien/features/providers.dart';

class FocusTabView extends ConsumerWidget {
  const FocusTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(focusSessionProvider);
    final timeline = ref.watch(timelineProvider).valueOrNull;
    final s = ref.watch(stringsProvider);

    return sessionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(s.errorPrefix(e))),
      data: (session) {
        if (session == null) {
          return _NoActiveFocus(tasks: timeline?.tasks ?? [], s: s);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
          children: [
            const BodyDoublingPanel(),
            const SizedBox(height: 16),
            FocusTimerWidget(session: session, size: 248, interactive: true),
            const SizedBox(height: 24),
            Text(
              session.title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: session.isPaused
                        ? FlorienColors.warning
                        : FlorienColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  session.isPaused ? s.paused : s.focusModeOn,
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => toggleFocusPause(context, ref, session),
                    icon: Icon(
                      session.isActive
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(session.isActive ? s.pause : s.continueLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => finishFocusSession(context, ref, session),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(s.finish),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlorienColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _NoActiveFocus extends ConsumerWidget {
  const _NoActiveFocus({required this.tasks, required this.s});

  final List<TaskModel> tasks;
  final S s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(focusSessionProvider).valueOrNull?.taskId;
    final pending = tasks
        .where((t) => !t.isCompleted && t.id != activeId)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 120),
      children: [
        Align(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.self_improvement_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          s.focusModeOff,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          s.focusModeHint,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: () => showStartFocusSheet(context, ref),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(s.startFocus),
        ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(
            s.quickStart,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...pending.take(3).map((task) {
            final color = FlorienColors.fromHex(task.color);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: context.palette.border),
                ),
                tileColor: context.palette.surface,
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(Icons.play_arrow_rounded, color: color),
                ),
                title: Text(
                  task.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => startTaskAndOpenFocus(context, ref, task.id),
              ),
            );
          }),
        ],
      ],
    );
  }
}
