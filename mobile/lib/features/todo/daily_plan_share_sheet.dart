import 'package:flutter/material.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_soft_overlay.dart';
import 'package:share_plus/share_plus.dart';

Future<void> showDailyPlanShareSheet(
  BuildContext context, {
  required DateTime date,
  required List<TaskModel> tasks,
}) => showFlorienBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: false,
  shape: const RoundedRectangleBorder(),
  builder: (_) => _DailyPlanShareSheet(date: date, tasks: tasks),
);

class _DailyPlanShareSheet extends StatefulWidget {
  const _DailyPlanShareSheet({required this.date, required this.tasks});

  final DateTime date;
  final List<TaskModel> tasks;

  @override
  State<_DailyPlanShareSheet> createState() => _DailyPlanShareSheetState();
}

class _DailyPlanShareSheetState extends State<_DailyPlanShareSheet> {
  late final Set<String> _selectedTaskIds = {
    for (final task in widget.tasks) task.id,
  };
  var _showPreview = false;
  var _isSharing = false;

  List<TaskModel> get _selectedTasks => widget.tasks
      .where((task) => _selectedTaskIds.contains(task.id))
      .toList(growable: false);

  void _toggleTask(TaskModel task, bool selected) {
    setState(() {
      if (selected) {
        _selectedTaskIds.add(task.id);
      } else {
        _selectedTaskIds.remove(task.id);
      }
    });
  }

  void _toggleAll() {
    setState(() {
      if (_selectedTaskIds.length == widget.tasks.length) {
        _selectedTaskIds.clear();
      } else {
        _selectedTaskIds
          ..clear()
          ..addAll(widget.tasks.map((task) => task.id));
      }
    });
  }

  Future<void> _share() async {
    if (_selectedTasks.isEmpty || _isSharing) return;
    setState(() => _isSharing = true);
    try {
      await Share.share(
        _shareText(),
        subject: '${_formattedDate(widget.date)} planım',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paylaşım ekranı açılamadı.')),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  String _shareText() {
    final buffer = StringBuffer('Florien • ${_formattedDate(widget.date)}');
    buffer.writeln('\n\nBugünün planı');
    for (final task in _selectedTasks) {
      final marker = task.isCompleted ? '✓' : '○';
      final state = task.isCompleted ? 'Tamamlandı' : 'Planlandı';
      buffer.writeln('$marker ${task.title} · $state');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final palette = context.palette;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.only(bottom: keyboard),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .84,
          ),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: palette.border, width: 2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _showPreview
                ? _buildPreview(context)
                : _buildSelection(context),
          ),
        ),
      ),
    );
  }

  Widget _buildSelection(BuildContext context) {
    final palette = context.palette;
    final allSelected = _selectedTaskIds.length == widget.tasks.length;
    return Column(
      key: const ValueKey('daily-share-selection'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHandle(color: palette.border),
        const SizedBox(height: 12),
        _SheetHeader(
          icon: Icons.ios_share_rounded,
          title: 'Gününü paylaş',
          subtitle:
              '${_formattedDate(widget.date)} için paylaşılacak görevleri seç.',
          onClose: () => Navigator.pop(context),
        ),
        const SizedBox(height: 14),
        if (widget.tasks.isEmpty)
          const _ShareEmptyState()
        else ...[
          Row(
            children: [
              Text(
                '${_selectedTaskIds.length} görev seçildi',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _toggleAll,
                icon: Icon(
                  allSelected
                      ? Icons.remove_done_rounded
                      : Icons.done_all_rounded,
                  size: 17,
                ),
                label: Text(allSelected ? 'Temizle' : 'Tümünü seç'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final task = widget.tasks[index];
                final selected = _selectedTaskIds.contains(task.id);
                return _SelectableTaskTile(
                  task: task,
                  selected: selected,
                  onChanged: (value) => _toggleTask(task, value),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('daily-share-continue'),
            onPressed: _selectedTasks.isEmpty
                ? null
                : () => setState(() => _showPreview = true),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Önizlemeye geç'),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    final palette = context.palette;
    final completed = _selectedTasks.where((task) => task.isCompleted).length;
    final planned = _selectedTasks.length - completed;
    return Column(
      key: const ValueKey('daily-share-preview'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHandle(color: palette.border),
        const SizedBox(height: 12),
        _SheetHeader(
          icon: Icons.auto_awesome_rounded,
          title: 'Paylaşım önizlemesi',
          subtitle: 'Planın karşı tarafta böyle görünecek.',
          onClose: () => Navigator.pop(context),
          onBack: () => setState(() => _showPreview = false),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.aiSurface,
              borderRadius: BorderRadius.circular(FlorienRadius.lg),
              border: Border.all(
                color: palette.border,
                width: FlorienBorders.thin,
              ),
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: FlorienColors.primary,
                        borderRadius: BorderRadius.circular(FlorienRadius.sm),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        color: FlorienColors.onPrimary,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _formattedDate(widget.date),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _SummaryPill(
                      label: '$planned planlandı',
                      color: FlorienColors.primary,
                    ),
                    if (completed > 0)
                      _SummaryPill(
                        label: '$completed tamamlandı',
                        color: FlorienColors.mint,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final task in _selectedTasks) ...[
                  _PreviewTaskTile(task: task),
                  const SizedBox(height: 7),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('daily-share-submit'),
            onPressed: _isSharing ? null : _share,
            icon: _isSharing
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
            label: Text(_isSharing ? 'Açılıyor…' : 'Paylaş'),
          ),
        ),
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
    ),
  );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onClose,
    this.onBack,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (onBack != null)
        IconButton(
          tooltip: 'Seçime dön',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        )
      else
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: context.palette.primaryMuted,
            borderRadius: BorderRadius.circular(FlorienRadius.sm),
            border: Border.all(color: context.palette.border),
          ),
          child: Icon(icon, size: 20),
        ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Kapat',
        onPressed: onClose,
        icon: const Icon(Icons.close_rounded),
      ),
    ],
  );
}

class _SelectableTaskTile extends StatelessWidget {
  const _SelectableTaskTile({
    required this.task,
    required this.selected,
    required this.onChanged,
  });

  final TaskModel task;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final stateColor = task.isCompleted
        ? FlorienColors.mint
        : palette.primaryMuted;
    return Material(
      color: selected ? stateColor : palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FlorienRadius.md),
        side: BorderSide(color: palette.border, width: FlorienBorders.thin),
      ),
      child: CheckboxListTile(
        value: selected,
        onChanged: (value) => onChanged(value ?? false),
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(task.isCompleted ? 'Tamamlandı' : 'Planlandı'),
        secondary: Icon(
          task.isCompleted
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: palette.textSecondary,
        ),
      ),
    );
  }
}

class _PreviewTaskTile extends StatelessWidget {
  const _PreviewTaskTile({required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = task.isCompleted ? FlorienColors.mint : palette.surface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(FlorienRadius.sm),
        border: Border.all(color: palette.border, width: FlorienBorders.thin),
      ),
      child: Row(
        children: [
          Icon(
            task.isCompleted
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                decoration: task.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            task.isCompleted ? 'Bitti' : 'Planlı',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(
        color: context.palette.border,
        width: FlorienBorders.thin,
      ),
    ),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _ShareEmptyState extends StatelessWidget {
  const _ShareEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        Icon(
          Icons.event_available_outlined,
          size: 42,
          color: context.palette.textSecondary,
        ),
        const SizedBox(height: 10),
        Text(
          'Bugün için paylaşılacak görev yok.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

String _formattedDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${_weekdayNames[date.weekday - 1]}';

const _weekdayNames = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

const _monthNames = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];
