import 'package:flutter/material.dart';
import 'package:florien/core/data/routine_catalog.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/task_icon/presentation/task_icon_badge.dart';

class RoutineDiscoveryScreen extends StatefulWidget {
  const RoutineDiscoveryScreen({super.key, required this.onTaskSelected});

  final Future<void> Function(RoutinePresetTask task, RoutineTheme theme)
  onTaskSelected;

  @override
  State<RoutineDiscoveryScreen> createState() => _RoutineDiscoveryScreenState();
}

class _RoutineDiscoveryScreenState extends State<RoutineDiscoveryScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _selectTask(RoutinePresetTask task, RoutineTheme theme) async {
    await widget.onTaskSelected(task, theme);
    if (mounted) Navigator.of(context).pop();
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
                      task.title.toLowerCase().contains(query) ||
                      task.description.toLowerCase().contains(query),
                )
                .toList(),
          ),
        )
        .where((entry) => entry.tasks.isNotEmpty)
        .toList();

    return Scaffold(
      key: const ValueKey('routine-discovery-screen'),
      backgroundColor: context.palette.background,
      appBar: AppBar(title: const Text('Rutinleri keşfet')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: [
          Text(
            'Bugün için hazır',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Hazır görevleri seç, sonra kendi gününe göre düzenle.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const ValueKey('routine-search-field'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Hazır görev ara',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Aramayı temizle',
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          if (visibleThemes.isEmpty)
            _EmptySearchState(query: _search.text.trim())
          else
            for (final entry in visibleThemes) ...[
              _ThemeHeader(theme: entry.theme),
              const SizedBox(height: 10),
              for (final task in entry.tasks) ...[
                _PresetTaskCard(
                  task: task,
                  theme: entry.theme,
                  onTap: () => _selectTask(task, entry.theme),
                ),
                if (task != entry.tasks.last) const SizedBox(height: 8),
              ],
              const SizedBox(height: 24),
            ],
        ],
      ),
    );
  }
}

class _ThemeHeader extends StatelessWidget {
  const _ThemeHeader({required this.theme});

  final RoutineTheme theme;

  @override
  Widget build(BuildContext context) {
    final color = FlorienColors.fromHex(theme.color);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: .34),
          context.palette.surface,
        ),
        borderRadius: BorderRadius.circular(FlorienRadius.lg),
        border: Border.all(
          color: context.palette.border,
          width: FlorienBorders.thin,
        ),
      ),
      child: Row(
        children: [
          TaskIconBadge.forTask(icon: theme.icon, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  theme.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  theme.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetTaskCard extends StatelessWidget {
  const _PresetTaskCard({
    required this.task,
    required this.theme,
    required this.onTap,
  });

  final RoutinePresetTask task;
  final RoutineTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(FlorienRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FlorienRadius.md),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FlorienRadius.md),
            border: Border.all(
              color: context.palette.border,
              width: FlorienBorders.thin,
            ),
          ),
          child: Row(
            children: [
              TaskIconBadge.forTask(icon: task.icon, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${task.durationMinutes} dk · Hazır şablon',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.palette.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: context.palette.surfaceMuted,
      borderRadius: BorderRadius.circular(FlorienRadius.lg),
    ),
    child: Text(
      '“$query” için hazır görev bulunamadı.',
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: context.palette.textSecondary),
    ),
  );
}
