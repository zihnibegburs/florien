import 'package:flutter/material.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_duration_picker.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/task_icon/presentation/task_icon_badge.dart';

class PlannerAiTodoCard extends ConsumerStatefulWidget {
  const PlannerAiTodoCard({super.key, required this.onFocusTask});

  final ValueChanged<TaskModel> onFocusTask;

  @override
  ConsumerState<PlannerAiTodoCard> createState() => _PlannerAiTodoCardState();
}

class _PlannerAiTodoCardState extends ConsumerState<PlannerAiTodoCard> {
  static const _pageSize = 3;
  int _visibleCount = _pageSize;

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(inboxProvider);
    return inbox.when(
      loading: () => _AiToolCardShell(
        title: context.l10n('To-do'),
        icon: Icons.check_circle_outline_rounded,
        kicker: context.l10n('Yükleniyor'),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, _) => _AiToolCardShell(
        title: context.l10n('To-do'),
        icon: Icons.check_circle_outline_rounded,
        kicker: 'Hata',
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(context.l10n('To-do listesi yüklenemedi.')),
        ),
      ),
      data: (tasks) {
        final openCount = tasks.where((task) => !task.isCompleted).length;
        final visibleCount = _visibleCount.clamp(0, tasks.length);
        final visible = tasks.take(visibleCount).toList();
        final hasMore = visibleCount < tasks.length;
        return _AiToolCardShell(
          key: const ValueKey('planner-ai-todo-card'),
          title: context.l10n('To-do'),
          icon: Icons.check_circle_outline_rounded,
          kicker: context.l10n('{count} açık görev', {'count': '$openCount'}),
          onExpand: hasMore
              ? () => setState(() => _visibleCount += _pageSize)
              : null,
          expandLabel: context.l10n('Daha fazlasını göster'),
          child: visible.isEmpty
              ? Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 18),
                  child: Text(
                    context.l10n('Henüz görev yok. Ne yapmak istediğini yaz.'),
                  ),
                )
              : Column(
                  children: [
                    for (final task in visible)
                      _AiTaskRow(
                        task: task,
                        primaryLabel: task.isCompleted
                            ? context.l10n('Tamamlandı')
                            : florienDurationLabel(task.durationMinutes),
                        onFocus: task.isCompleted
                            ? null
                            : () => widget.onFocusTask(task),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class PlannerAiDailyCard extends ConsumerStatefulWidget {
  const PlannerAiDailyCard({super.key, required this.onFocusTask});

  final ValueChanged<TaskModel> onFocusTask;

  @override
  ConsumerState<PlannerAiDailyCard> createState() => _PlannerAiDailyCardState();
}

class _PlannerAiDailyCardState extends ConsumerState<PlannerAiDailyCard> {
  static const _pageSize = 3;
  int _visibleCount = _pageSize;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(dailyTimelineProvider(_today));
    return timeline.when(
      loading: () => _AiToolCardShell(
        title: context.l10n('Bugün'),
        icon: Icons.calendar_today_outlined,
        kicker: context.l10n('Yükleniyor'),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, _) => _AiToolCardShell(
        title: context.l10n('Bugün'),
        icon: Icons.calendar_today_outlined,
        kicker: 'Hata',
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(context.l10n('Günlük plan yüklenemedi.')),
        ),
      ),
      data: (day) {
        final tasks = day.tasks;
        final visibleCount = _visibleCount.clamp(0, tasks.length);
        final visible = tasks.take(visibleCount).toList();
        final hasMore = visibleCount < tasks.length;
        return _AiToolCardShell(
          key: const ValueKey('planner-ai-daily-card'),
          title: context.l10n('Bugün'),
          icon: Icons.calendar_today_outlined,
          kicker: context.l10n('{count} görev', {'count': '${tasks.length}'}),
          onExpand: hasMore
              ? () => setState(() => _visibleCount += _pageSize)
              : null,
          expandLabel: context.l10n('Daha fazlasını göster'),
          child: visible.isEmpty
              ? Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 18),
                  child: Text(context.l10n('Bugün için planlanmış görev yok.')),
                )
              : Column(
                  children: [
                    for (final task in visible)
                      _AiTaskRow(
                        task: task,
                        primaryLabel: _dailyPrimaryLabel(task),
                        onFocus: task.isCompleted
                            ? null
                            : () => widget.onFocusTask(task),
                      ),
                  ],
                ),
        );
      },
    );
  }

  String _dailyPrimaryLabel(TaskModel task) {
    if (task.isCompleted) return context.l10n('Tamamlandı');
    final start = task.scheduledAt;
    if (start == null) return 'Saat yok';
    final hh = start.hour.toString().padLeft(2, '0');
    final mm = start.minute.toString().padLeft(2, '0');
    return '$hh.$mm';
  }
}

class _AiToolCardShell extends StatelessWidget {
  const _AiToolCardShell({
    super.key,
    required this.title,
    required this.icon,
    required this.kicker,
    required this.child,
    this.onExpand,
    this.expandLabel,
  });

  final String title;
  final IconData icon;
  final String kicker;
  final Widget child;
  final VoidCallback? onExpand;
  final String? expandLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF303034),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFF8D919B), width: 1.25),
        boxShadow: const [
          BoxShadow(color: Color(0xFF9DD8FF), offset: Offset(-1, 0)),
          BoxShadow(color: Color(0xFFFFF45C), offset: Offset(1, 0)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: context.palette.textPrimary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  kicker,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: context.palette.border.withValues(alpha: 0.45),
          ),
          child,
          if (onExpand != null && expandLabel != null) ...[
            Divider(
              height: 1,
              color: context.palette.border.withValues(alpha: 0.45),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton(
                  onPressed: onExpand,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.palette.textPrimary,
                    backgroundColor: const Color(0xFF38383D),
                    side: BorderSide(color: context.palette.border),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(expandLabel!),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AiTaskRow extends StatelessWidget {
  const _AiTaskRow({
    required this.task,
    required this.primaryLabel,
    this.onFocus,
  });

  final TaskModel task;
  final String primaryLabel;
  final VoidCallback? onFocus;

  @override
  Widget build(BuildContext context) {
    final done = task.isCompleted;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.palette.border.withValues(alpha: 0.45),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? FlorienColors.mint : context.palette.selection,
            ),
          ),
          const SizedBox(width: 9),
          TaskIconBadge.forTask(icon: task.icon, size: 28),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  primaryLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.25,
                    color: context.palette.textSecondary,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
          if (done)
            Icon(
              Icons.check_rounded,
              size: 16,
              color: context.palette.textSecondary,
            )
          else if (onFocus != null)
            SizedBox(
              height: 34,
              child: OutlinedButton(
                onPressed: onFocus,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.palette.textPrimary,
                  side: BorderSide(color: context.palette.border),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(context.l10n('Odaklan')),
              ),
            ),
        ],
      ),
    );
  }
}
