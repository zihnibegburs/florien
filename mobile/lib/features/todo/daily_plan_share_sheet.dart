import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_logo.dart';
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
  final GlobalKey _shareCardKey = GlobalKey();
  late final Set<String> _selectedTaskIds = {
    for (final task in widget.tasks) task.id,
  };
  late final Map<String, _ShareTaskState> _taskStates = {
    for (final task in widget.tasks)
      task.id: task.isCompleted
          ? _ShareTaskState.completed
          : _ShareTaskState.planned,
  };
  _DailyShareTheme _selectedTheme = _dailyShareThemes.first;
  var _showPreview = false;
  var _isSharing = false;

  List<TaskModel> get _selectedTasks => widget.tasks
      .where((task) => _selectedTaskIds.contains(task.id))
      .toList(growable: false);

  _ShareTaskState _stateFor(TaskModel task) =>
      _taskStates[task.id] ?? _ShareTaskState.planned;

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

  void _setTaskState(TaskModel task, _ShareTaskState state) {
    setState(() => _taskStates[task.id] = state);
  }

  Future<void> _share(BuildContext anchorContext) async {
    if (_selectedTasks.isEmpty || _isSharing) return;
    setState(() => _isSharing = true);
    try {
      final shareBox = anchorContext.findRenderObject() as RenderBox?;
      final shareOrigin = shareBox != null && shareBox.hasSize
          ? shareBox.localToGlobal(Offset.zero) & shareBox.size
          : null;
      final shareFile = await _createShareImage();
      await Share.shareXFiles(
        [XFile(shareFile.path, mimeType: 'image/png', name: _shareFileName())],
        sharePositionOrigin: shareOrigin,
      );
    } catch (error, stackTrace) {
      debugPrint('Daily plan share failed: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paylaşım açılamadı. Tekrar dene.')),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<File> _createShareImage() async {
    final boundary =
        _shareCardKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Paylaşım önizlemesi hazırlanamadı.');
    }
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('Paylaşım görseli oluşturulamadı.');
    }
    final file = File(
      '${Directory.systemTemp.path}/${DateTime.now().microsecondsSinceEpoch}-${_shareFileName()}',
    );
    return file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
  }

  String _shareFileName() {
    final date = widget.date;
    return 'florien-plan-${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}.png';
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
                  shareState: _stateFor(task),
                  onChanged: (value) => _toggleTask(task, value),
                  onStateChanged: (state) => _setTaskState(task, state),
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
    final completed = _selectedTasks
        .where((task) => _stateFor(task) == _ShareTaskState.completed)
        .length;
    final incomplete = _selectedTasks
        .where((task) => _stateFor(task) == _ShareTaskState.incomplete)
        .length;
    final planned = _selectedTasks.length - completed - incomplete;
    final shareTheme = _selectedTheme;
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
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              'Görünüm',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              shareTheme.name,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.palette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ShareThemePicker(
          selectedTheme: shareTheme,
          onSelected: (theme) => setState(() => _selectedTheme = theme),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: SingleChildScrollView(
            child: RepaintBoundary(
              key: _shareCardKey,
              child: _DailyShareCard(
                date: widget.date,
                tasks: _selectedTasks,
                planned: planned,
                completed: completed,
                incomplete: incomplete,
                taskStates: _taskStates,
                shareTheme: shareTheme,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Builder(
          builder: (anchorContext) => SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('daily-share-submit'),
              onPressed: _isSharing ? null : () => _share(anchorContext),
              icon: _isSharing
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded),
              label: Text(_isSharing ? 'Açılıyor…' : 'Paylaş'),
            ),
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
    required this.shareState,
    required this.onChanged,
    required this.onStateChanged,
  });

  final TaskModel task;
  final bool selected;
  final _ShareTaskState shareState;
  final ValueChanged<bool> onChanged;
  final ValueChanged<_ShareTaskState> onStateChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FlorienRadius.md),
        side: BorderSide(color: palette.border, width: FlorienBorders.thin),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => onChanged(!selected),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      Icon(
                        shareState.icon,
                        size: 20,
                        color: selected
                            ? _shareStateColor(shareState, palette)
                            : palette.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: selected
                                    ? palette.textPrimary
                                    : palette.textSecondary,
                                fontWeight: FontWeight.w700,
                                decoration:
                                    shareState == _ShareTaskState.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (selected)
              _ShareTaskStateMenu(
                taskId: task.id,
                state: shareState,
                onSelected: onStateChanged,
              ),
            Checkbox(
              value: selected,
              onChanged: (value) => onChanged(value ?? false),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _ShareTaskStateMenu extends StatelessWidget {
  const _ShareTaskStateMenu({
    required this.taskId,
    required this.state,
    required this.onSelected,
  });

  final String taskId;
  final _ShareTaskState state;
  final ValueChanged<_ShareTaskState> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PopupMenuButton<_ShareTaskState>(
      key: ValueKey('daily-share-status-menu-$taskId'),
      tooltip: 'Paylaşım durumunu değiştir',
      initialValue: state,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final option in _ShareTaskState.values)
          PopupMenuItem<_ShareTaskState>(
            key: ValueKey('daily-share-status-${option.name}-$taskId'),
            value: option,
            child: Row(
              children: [
                Icon(
                  option.icon,
                  size: 18,
                  color: _shareStateColor(option, palette),
                ),
                const SizedBox(width: 9),
                Text(option.label),
                if (option == state) ...[
                  const Spacer(),
                  const Icon(Icons.check_rounded, size: 18),
                ],
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.shortLabel,
              style: TextStyle(
                color: _shareStateColor(state, palette),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 17,
              color: palette.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

Color _shareStateColor(_ShareTaskState state, FlorienPalette palette) =>
    switch (state) {
      _ShareTaskState.planned => palette.textSecondary,
      _ShareTaskState.completed => const Color(0xFF5E8F73),
      _ShareTaskState.incomplete => const Color(0xFFC86357),
    };

class _ShareThemePicker extends StatelessWidget {
  const _ShareThemePicker({
    required this.selectedTheme,
    required this.onSelected,
  });

  final _DailyShareTheme selectedTheme;
  final ValueChanged<_DailyShareTheme> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 68,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < _dailyShareThemes.length; index++) ...[
            if (index > 0) const SizedBox(width: 7),
            _ShareThemeOption(
              shareTheme: _dailyShareThemes[index],
              selected: selectedTheme == _dailyShareThemes[index],
              onTap: () => onSelected(_dailyShareThemes[index]),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ShareThemeOption extends StatelessWidget {
  const _ShareThemeOption({
    required this.shareTheme,
    required this.selected,
    required this.onTap,
  });

  final _DailyShareTheme shareTheme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: '${shareTheme.name} paylaşım teması',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('daily-share-theme-${shareTheme.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(FlorienRadius.sm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 76,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? context.palette.primaryMuted
                : context.palette.surfaceMuted.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(FlorienRadius.sm),
            border: Border.all(
              color: selected
                  ? context.palette.textPrimary
                  : context.palette.border,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: shareTheme.gradient == null
                        ? shareTheme.background
                        : null,
                    gradient: shareTheme.gradient,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ThemeColorDot(color: shareTheme.accent),
                        const SizedBox(width: 3),
                        _ThemeColorDot(color: shareTheme.completed),
                        const SizedBox(width: 3),
                        _ThemeColorDot(color: shareTheme.incomplete),
                        const SizedBox(width: 3),
                        _ThemeColorDot(color: shareTheme.text),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                shareTheme.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ThemeColorDot extends StatelessWidget {
  const _ThemeColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: .55)),
    ),
  );
}

class _DailyShareCard extends StatelessWidget {
  const _DailyShareCard({
    required this.date,
    required this.tasks,
    required this.planned,
    required this.completed,
    required this.incomplete,
    required this.taskStates,
    required this.shareTheme,
  });

  final DateTime date;
  final List<TaskModel> tasks;
  final int planned;
  final int completed;
  final int incomplete;
  final Map<String, _ShareTaskState> taskStates;
  final _DailyShareTheme shareTheme;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: shareTheme.gradient == null ? shareTheme.background : null,
      gradient: shareTheme.gradient,
      borderRadius: BorderRadius.circular(FlorienRadius.lg),
      border: Border.all(color: shareTheme.border, width: 1.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FlorienLogo(
              size: 44,
              backgroundBrightness: ThemeData.estimateBrightnessForColor(
                shareTheme.background,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FLORIEN',
                    style: TextStyle(
                      color: shareTheme.mutedText,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formattedDate(date),
                    style: TextStyle(
                      color: shareTheme.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 17),
        Text(
          'Günlük planım',
          style: TextStyle(
            color: shareTheme.text,
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _SummaryPill(
              label: '$planned planlandı',
              color: shareTheme.accent,
              textColor: shareTheme.text,
              borderColor: shareTheme.border,
            ),
            if (completed > 0)
              _SummaryPill(
                label: '$completed tamamlandı',
                color: shareTheme.completed,
                textColor: shareTheme.text,
                borderColor: shareTheme.border,
              ),
            if (incomplete > 0)
              _SummaryPill(
                label: '$incomplete tamamlanamadı',
                color: shareTheme.incomplete,
                textColor: shareTheme.text,
                borderColor: shareTheme.border,
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < tasks.length; index++) ...[
          _PreviewTaskTile(
            task: tasks[index],
            shareState: taskStates[tasks[index].id] ?? _ShareTaskState.planned,
            shareTheme: shareTheme,
          ),
          if (index < tasks.length - 1) const SizedBox(height: 7),
        ],
        const SizedBox(height: 16),
        Text(
          'Kendi ritminde, gerçekçi bir gün.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: shareTheme.mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _PreviewTaskTile extends StatelessWidget {
  const _PreviewTaskTile({
    required this.task,
    required this.shareState,
    required this.shareTheme,
  });

  final TaskModel task;
  final _ShareTaskState shareState;
  final _DailyShareTheme shareTheme;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
    decoration: BoxDecoration(
      color: switch (shareState) {
        _ShareTaskState.planned => shareTheme.surface.withValues(alpha: .92),
        _ShareTaskState.completed => shareTheme.completed.withValues(
          alpha: .72,
        ),
        _ShareTaskState.incomplete => shareTheme.incomplete.withValues(
          alpha: .76,
        ),
      },
      borderRadius: BorderRadius.circular(FlorienRadius.sm),
      border: Border.all(color: shareTheme.border),
    ),
    child: Row(
      children: [
        Icon(shareState.icon, size: 19, color: shareTheme.text),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: shareTheme.text,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              decoration: shareState == _ShareTaskState.completed
                  ? TextDecoration.lineThrough
                  : null,
              decorationColor: shareTheme.text,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          shareState.shortLabel,
          style: TextStyle(
            color: shareTheme.mutedText,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.color,
    required this.textColor,
    required this.borderColor,
  });

  final String label;
  final Color color;
  final Color textColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: borderColor),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

enum _ShareTaskState {
  planned(
    label: 'Planlandı',
    shortLabel: 'Planlı',
    icon: Icons.circle_outlined,
  ),
  completed(
    label: 'Tamamlandı',
    shortLabel: 'Bitti',
    icon: Icons.check_circle_rounded,
  ),
  incomplete(
    label: 'Tamamlanamadı',
    shortLabel: 'Olmadı',
    icon: Icons.cancel_outlined,
  );

  const _ShareTaskState({
    required this.label,
    required this.shortLabel,
    required this.icon,
  });

  final String label;
  final String shortLabel;
  final IconData icon;
}

class _DailyShareTheme {
  const _DailyShareTheme({
    required this.id,
    required this.name,
    required this.background,
    required this.surface,
    required this.text,
    required this.mutedText,
    required this.accent,
    required this.completed,
    required this.incomplete,
    required this.border,
    this.gradient,
  });

  final String id;
  final String name;
  final Color background;
  final Color surface;
  final Color text;
  final Color mutedText;
  final Color accent;
  final Color completed;
  final Color incomplete;
  final Color border;
  final Gradient? gradient;
}

const _dailyShareThemes = [
  _DailyShareTheme(
    id: 'florien',
    name: 'Florien',
    background: Color(0xFFFAF6ED),
    surface: Color(0xFFFFFCF7),
    text: Color(0xFF29262D),
    mutedText: Color(0xFF6F6974),
    accent: Color(0xFFF2BC52),
    completed: Color(0xFF8FB6A0),
    incomplete: Color(0xFFE98F82),
    border: Color(0xFF29262D),
  ),
  _DailyShareTheme(
    id: 'night',
    name: 'Gece',
    background: Color(0xFF19171E),
    surface: Color(0xFF302D36),
    text: Color(0xFFFFFCF7),
    mutedText: Color(0xFFC4BEC9),
    accent: Color(0xFFAAA0BE),
    completed: Color(0xFF789B88),
    incomplete: Color(0xFFE98F82),
    border: Color(0xFF514B59),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF19171E), Color(0xFF2E263D)],
    ),
  ),
  _DailyShareTheme(
    id: 'ocean',
    name: 'Okyanus',
    background: Color(0xFFDDF5F4),
    surface: Color(0xFFF4FFFF),
    text: Color(0xFF173A43),
    mutedText: Color(0xFF50727A),
    accent: Color(0xFF73C8D2),
    completed: Color(0xFF7FD0AE),
    incomplete: Color(0xFFE69B89),
    border: Color(0xFF75AAB2),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE3FAF4), Color(0xFFCDECF7)],
    ),
  ),
  _DailyShareTheme(
    id: 'sunset',
    name: 'Gün Batımı',
    background: Color(0xFFFFE9DE),
    surface: Color(0xFFFFF8F3),
    text: Color(0xFF43282E),
    mutedText: Color(0xFF855A61),
    accent: Color(0xFFF3B45F),
    completed: Color(0xFFE98F82),
    incomplete: Color(0xFFBE6977),
    border: Color(0xFFCA796E),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFF0D8), Color(0xFFFFD8D2)],
    ),
  ),
  _DailyShareTheme(
    id: 'pop',
    name: 'Pop',
    background: Color(0xFFBCA8FF),
    surface: Color(0xFFFFF8FE),
    text: Color(0xFF241B38),
    mutedText: Color(0xFF5E4E78),
    accent: Color(0xFFFFD85E),
    completed: Color(0xFF77E0BE),
    incomplete: Color(0xFFFF7C9C),
    border: Color(0xFF5E3D8B),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFB5D8), Color(0xFFB9B2FF), Color(0xFF8DE5E1)],
    ),
  ),
];

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
