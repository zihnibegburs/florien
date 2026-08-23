import 'package:flutter/material.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/data/routine_catalog.dart';
import 'package:florien/core/models/task_usage_summary.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/task_icon/data/task_icon_lexicon.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/presentation/task_icon_badge.dart';

RoutinePresetTask _localizedRoutinePreset(
  BuildContext context,
  RoutinePresetTask task,
) {
  final title = context.l10n(task.title);
  return RoutinePresetTask(
    title: title,
    description: '',
    durationMinutes: task.durationMinutes,
    period: task.period,
    icon: task.icon,
    subtasks: [for (final step in task.subtasks) context.l10n(step)],
  );
}

class RoutineDiscoveryScreen extends StatefulWidget {
  const RoutineDiscoveryScreen({
    super.key,
    required this.onTaskSelected,
    this.frequentlyUsedTasks = const [],
    this.onFrequentlyUsedTaskSelected,
  });

  final Future<void> Function(RoutinePresetTask task, RoutineTheme theme)
  onTaskSelected;
  final List<TaskUsageSummary> frequentlyUsedTasks;
  final Future<void> Function(TaskUsageSummary summary)?
  onFrequentlyUsedTaskSelected;

  @override
  State<RoutineDiscoveryScreen> createState() => _RoutineDiscoveryScreenState();
}

class _RoutineDiscoveryScreenState extends State<RoutineDiscoveryScreen> {
  final _search = TextEditingController();
  String? _expandedTheme = routineThemes.first.name;
  bool _selecting = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _selectTask(RoutinePresetTask task, RoutineTheme theme) async {
    if (_selecting) return;
    setState(() => _selecting = true);
    try {
      await widget.onTaskSelected(
        _localizedRoutinePreset(context, task),
        theme,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  Future<void> _selectFrequentlyUsedTask(TaskUsageSummary summary) async {
    final callback = widget.onFrequentlyUsedTaskSelected;
    if (callback == null || _selecting) return;
    setState(() => _selecting = true);
    try {
      await callback(summary);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  void _toggleTheme(String name) {
    setState(() => _expandedTheme = _expandedTheme == name ? null : name);
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visibleThemes = routineThemes
        .map(
          (theme) => (
            theme: theme,
            tasks: theme.tasks
                .where(
                  (task) =>
                      query.isEmpty ||
                      theme.name.toLowerCase().contains(query) ||
                      context.l10n(theme.name).toLowerCase().contains(query) ||
                      theme.description.toLowerCase().contains(query) ||
                      context
                          .l10n(theme.description)
                          .toLowerCase()
                          .contains(query) ||
                      task.title.toLowerCase().contains(query) ||
                      context.l10n(task.title).toLowerCase().contains(query) ||
                      task.description.toLowerCase().contains(query) ||
                      context
                          .l10n(task.description)
                          .toLowerCase()
                          .contains(query) ||
                      task.subtasks.any(
                        (subtask) =>
                            subtask.toLowerCase().contains(query) ||
                            context.l10n(subtask).toLowerCase().contains(query),
                      ),
                )
                .toList(),
          ),
        )
        .where((entry) => entry.tasks.isNotEmpty)
        .toList();

    return Scaffold(
      key: const ValueKey('routine-discovery-screen'),
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(context.l10n('Rutinleri keşfet'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          FlorienSpacing.screen,
          FlorienSpacing.sm,
          FlorienSpacing.screen,
          FlorienSpacing.huge,
        ),
        children: [
          TextField(
            key: const ValueKey('routine-search-field'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: context.l10n('Rutin veya kategori ara'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: context.l10n('Aramayı temizle'),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          if (query.isEmpty && widget.frequentlyUsedTasks.isNotEmpty) ...[
            const SizedBox(height: FlorienSpacing.xxl),
            _FrequentlyUsedSection(
              summaries: widget.frequentlyUsedTasks,
              onTap: _selectFrequentlyUsedTask,
            ),
          ],
          const SizedBox(height: FlorienSpacing.xxl),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n('Hazır rutinler'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                context.l10n('{count} kategori', {
                  'count': '${visibleThemes.length}',
                }),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: FlorienSpacing.md),
          if (visibleThemes.isEmpty)
            _EmptySearchState(query: _search.text.trim())
          else
            for (var index = 0; index < visibleThemes.length; index++) ...[
              _RoutineThemeAccordion(
                theme: visibleThemes[index].theme,
                tasks: visibleThemes[index].tasks,
                expanded:
                    query.isNotEmpty ||
                    _expandedTheme == visibleThemes[index].theme.name,
                onToggle: () => _toggleTheme(visibleThemes[index].theme.name),
                onTaskTap: (task) =>
                    _selectTask(task, visibleThemes[index].theme),
              ),
              if (index < visibleThemes.length - 1)
                const SizedBox(height: FlorienSpacing.sm),
            ],
        ],
      ),
    );
  }
}

class _FrequentlyUsedSection extends StatelessWidget {
  const _FrequentlyUsedSection({required this.summaries, required this.onTap});

  final List<TaskUsageSummary> summaries;
  final ValueChanged<TaskUsageSummary> onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n('En çok kullandıkların'),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: FlorienSpacing.md),
      SizedBox(
        key: const ValueKey('routine-frequently-used-slider'),
        height: 116,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: summaries.length,
          separatorBuilder: (_, _) => const SizedBox(width: FlorienSpacing.md),
          itemBuilder: (context, index) {
            final summary = summaries[index];
            return _FrequentlyUsedCard(
              summary: summary,
              onTap: () => onTap(summary),
            );
          },
        ),
      ),
    ],
  );
}

class _FrequentlyUsedCard extends StatelessWidget {
  const _FrequentlyUsedCard({required this.summary, required this.onTap});

  final TaskUsageSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final task = summary.task;
    final borderAlpha = context.isFlorienDark ? .55 : .16;
    return Semantics(
      button: true,
      label: context.l10n('{title}, {count} kez kullanıldı', {
        'title': context.l10n(task.title),
        'count': '${summary.usageCount}',
      }),
      child: Material(
        key: ValueKey('frequently-used-task-${task.id}'),
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FlorienRadius.lg),
          splashColor: FlorienColors.primary.withValues(alpha: .12),
          highlightColor: FlorienColors.primary.withValues(alpha: .06),
          child: Ink(
            width: 168,
            padding: const EdgeInsets.all(FlorienSpacing.md),
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(FlorienRadius.lg),
              border: Border.all(
                color: context.palette.border.withValues(alpha: borderAlpha),
                width: FlorienBorders.thin,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TaskIconBadge.forTask(icon: task.icon, size: 30),
                const Spacer(),
                Text(
                  context.l10n(task.title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.palette.textPrimary,
                  ),
                ),
                Text(
                  context.l10n('{count} kullanım', {
                    'count': '${summary.usageCount}',
                  }),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.palette.textSecondary,
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

class _RoutineThemeAccordion extends StatelessWidget {
  const _RoutineThemeAccordion({
    required this.theme,
    required this.tasks,
    required this.expanded,
    required this.onToggle,
    required this.onTaskTap,
  });

  final RoutineTheme theme;
  final List<RoutinePresetTask> tasks;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<RoutinePresetTask> onTaskTap;

  @override
  Widget build(BuildContext context) {
    final color = FlorienColors.fromHex(theme.color);
    return Container(
      key: ValueKey('routine-theme-${theme.name}'),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(FlorienRadius.md),
        border: Border.all(
          color: context.palette.border.withValues(
            alpha: context.isFlorienDark ? .55 : .16,
          ),
          width: FlorienBorders.thin,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FlorienSpacing.md,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(FlorienRadius.pill),
                      ),
                    ),
                    const SizedBox(width: FlorienSpacing.sm),
                    TaskIconBadge.forTask(
                      key: ValueKey('routine-theme-icon-${theme.name}'),
                      icon: theme.icon,
                      size: 28,
                    ),
                    const SizedBox(width: FlorienSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n(theme.name),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n('{count} rutin', {
                              'count': '${tasks.length}',
                            }),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: context.palette.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? .5 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: context.palette.border.withValues(
                              alpha: context.isFlorienDark ? .45 : .12,
                            ),
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: FlorienSpacing.sm,
                        vertical: FlorienSpacing.xs,
                      ),
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < tasks.length;
                            index++
                          ) ...[
                            _RoutineTaskRow(
                              task: tasks[index],
                              onTap: () => onTaskTap(tasks[index]),
                            ),
                            if (index < tasks.length - 1)
                              Divider(
                                height: 1,
                                indent: 42,
                                color: context.palette.border.withValues(
                                  alpha: context.isFlorienDark ? .35 : .09,
                                ),
                              ),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineTaskRow extends StatelessWidget {
  const _RoutineTaskRow({required this.task, required this.onTap});

  final RoutinePresetTask task;
  final VoidCallback onTap;

  String get _iconName =>
      TaskIconLexicon.match(task.title)?.storageName ?? task.icon;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context.l10n('{title}, {minutes} dakika', {
      'title': context.l10n(task.title),
      'minutes': '${task.durationMinutes}',
    }),
    child: Material(
      key: ValueKey('routine-task-${task.title}'),
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(FlorienRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FlorienRadius.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
            horizontal: FlorienSpacing.sm,
            vertical: FlorienSpacing.sm,
          ),
          child: Row(
            children: [
              TaskIconBadge.forTask(
                key: ValueKey('routine-task-icon-${task.title}'),
                icon: _iconName,
                size: 28,
              ),
              const SizedBox(width: FlorienSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n(task.title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: FlorienSpacing.sm),
              Container(
                key: ValueKey('routine-task-duration-${task.title}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: FlorienSpacing.sm,
                  vertical: FlorienSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: context.palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(FlorienRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: context.palette.textSecondary,
                    ),
                    const SizedBox(width: FlorienSpacing.xs),
                    Text(
                      context.l10n('{minutes} dk', {
                        'minutes': '${task.durationMinutes}',
                      }),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.palette.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FlorienSpacing.xxl),
    decoration: BoxDecoration(
      color: context.palette.surfaceMuted,
      borderRadius: BorderRadius.circular(FlorienRadius.lg),
    ),
    child: Text(
      context.l10n('“{query}” için hazır rutin bulunamadı.', {'query': query}),
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: context.palette.textSecondary),
    ),
  );
}
