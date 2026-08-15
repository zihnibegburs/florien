import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/presentation/realtime_task_icon_controller.dart';
import 'package:florien/features/task_icon/presentation/task_icon_badge.dart';

class TodoDetailScreen extends ConsumerStatefulWidget {
  const TodoDetailScreen({
    super.key,
    required this.initialTitle,
    required this.initialDuration,
    required this.todoListId,
    this.taskId,
    this.initialDescription = '',
    this.initialSubtasks = const [],
    this.initialIcon = 'other',
  });

  final String initialTitle;
  final String? taskId;
  final int initialDuration;
  final String? todoListId;
  final String initialDescription;
  final List<String> initialSubtasks;
  final String initialIcon;

  bool get isEditing => taskId != null;

  @override
  ConsumerState<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends ConsumerState<TodoDetailScreen> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late final _notes = TextEditingController(text: widget.initialDescription);
  final _subtask = TextEditingController();
  late final List<String> _subtasks = [...widget.initialSubtasks];
  late int _duration = widget.initialDuration;
  late String? _todoListId = widget.todoListId;
  late bool _subtasksExpanded = widget.initialSubtasks.isNotEmpty;
  late bool _notesExpanded = widget.initialDescription.trim().isNotEmpty;
  bool _saving = false;
  bool _generatingSubtasks = false;
  late final RealtimeTaskIconController _taskIcon = RealtimeTaskIconController(
    initialCategory: widget.initialIcon,
  );

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle.trim().isNotEmpty) {
      _taskIcon.onTaskChanged(widget.initialTitle);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _subtask.dispose();
    _taskIcon.dispose();
    super.dispose();
  }

  void _addSubtask() {
    final value = _subtask.text.trim();
    if (value.isEmpty) return;
    if (_subtasks.length >= TaskModel.userSubtaskLimit) {
      _showSubtaskLimitWarning();
      return;
    }
    setState(() {
      _subtasks.add(value);
      _subtask.clear();
    });
  }

  void _showSubtaskLimitWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('En fazla 30 alt görev ekleyebilirsin.')),
    );
  }

  void _onTitleChanged(String value) {
    _taskIcon.onTaskChanged(value);
    setState(() {});
  }

  Future<void> _generateSubtasks() async {
    final title = _title.text.trim();
    if (title.isEmpty ||
        _generatingSubtasks ||
        _subtasks.length >= TaskModel.userSubtaskLimit) {
      return;
    }

    setState(() => _generatingSubtasks = true);
    try {
      final generated = await ref
          .read(taskBreakdownServiceProvider)
          .generateSubtasks(title);
      if (!mounted || _title.text.trim().isEmpty) return;
      final existing = _subtasks.map((item) => item.toLowerCase()).toSet();
      final remaining = TaskModel.userSubtaskLimit - _subtasks.length;
      final additions = generated
          .where((item) => existing.add(item.toLowerCase()))
          .take(math.min(TaskModel.aiSubtaskLimit, remaining))
          .toList();
      setState(() {
        _subtasks.addAll(additions);
        _subtasksExpanded = true;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _generatingSubtasks = false);
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      _taskIcon.onTaskChanged(title);
      final notifier = ref.read(inboxProvider.notifier);
      final description = _notes.text.trim().isEmpty
          ? null
          : _notes.text.trim();
      if (widget.taskId case final taskId?) {
        await notifier.updateDetailedWithIcon(
          id: taskId,
          title: title,
          description: description,
          durationMinutes: _duration,
          todoListId: _todoListId,
          subtasks: _subtasks,
          icon: _taskIcon.value.category.storageName,
        );
      } else {
        await notifier.addDetailedWithIcon(
          title: title,
          description: description,
          durationMinutes: _duration,
          todoListId: _todoListId,
          subtasks: _subtasks,
          icon: _taskIcon.value.category.storageName,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(todoListsProvider).valueOrNull ?? const [];
    var listName = 'To-do';
    if (_todoListId != null) {
      for (final list in lists) {
        if (list.id == _todoListId) {
          listName = list.name;
          break;
        }
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Görevi düzenle' : 'Görev ekle'),
        leading: IconButton(
          tooltip: 'Kapat',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Kaydediliyor...' : 'To-do’yu kaydet'),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          18,
          14,
          18,
          MediaQuery.viewInsetsOf(context).bottom + 32,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.palette.primaryMuted,
              borderRadius: BorderRadius.circular(FlorienRadius.lg),
              border: Border.all(
                color: context.palette.border,
                width: FlorienBorders.thin,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.checklist_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.isEditing
                          ? 'To-do görevini düzenle'
                          : 'Aklındaki işi yakala',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('todo-detail-title'),
                  controller: _title,
                  onChanged: _onTitleChanged,
                  autofocus: widget.initialTitle.trim().isEmpty,
                  textCapitalization: TextCapitalization.sentences,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Ne yapman gerekiyor?',
                    filled: true,
                    fillColor: context.palette.surface,
                    prefixIcon: ValueListenableBuilder(
                      valueListenable: _taskIcon,
                      builder: (_, result, _) =>
                          TaskIconBadge.forResult(result, size: 34),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                if (lists.isNotEmpty) ...[
                  ListTile(
                    leading: const _DetailIcon(
                      Icons.format_list_bulleted_rounded,
                    ),
                    title: const Text('Liste'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ValuePill(label: listName),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    onTap: () => _pickList(lists),
                  ),
                  const Divider(height: 1),
                ],
                ListTile(
                  leading: const _DetailIcon(Icons.timer_outlined),
                  title: const Text('Süre'),
                  trailing: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.palette.surface,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: context.palette.border,
                        width: FlorienBorders.thin,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButton<int>(
                        value: _duration,
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(FlorienRadius.md),
                        items: [5, 10, 15, 30, 45, 60, 90, 120]
                            .map(
                              (minutes) => DropdownMenuItem(
                                value: minutes,
                                child: Text(_durationLabel(minutes)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _duration = value);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TodoFormSectionHeader(
                    key: const ValueKey('todo-subtasks-section-toggle'),
                    icon: Icons.account_tree_outlined,
                    title: 'Alt görevler',
                    subtitle: _subtasks.isEmpty
                        ? 'Küçük adımlar başlatmayı kolaylaştırır.'
                        : 'Adımları dilediğin sırayla düzenleyebilirsin.',
                    color: FlorienColors.aiLavender,
                    trailing:
                        _title.text.trim().isNotEmpty &&
                            _subtasks.length < TaskModel.userSubtaskLimit
                        ? IconButton.filledTonal(
                            key: const ValueKey('todo-ai-subtasks-button'),
                            tooltip: 'AI ile alt görev oluştur',
                            onPressed: _generatingSubtasks
                                ? null
                                : _generateSubtasks,
                            icon: _generatingSubtasks
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome_rounded),
                          )
                        : null,
                    expanded: _subtasksExpanded,
                    onTap: () =>
                        setState(() => _subtasksExpanded = !_subtasksExpanded),
                  ),
                  if (_subtasksExpanded) ...[
                    const SizedBox(height: 12),
                    for (var index = 0; index < _subtasks.length; index++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.circle_outlined, size: 18),
                        title: Text(_subtasks[index]),
                        trailing: IconButton(
                          tooltip: 'Sil',
                          onPressed: () =>
                              setState(() => _subtasks.removeAt(index)),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('todo-detail-subtask-input'),
                            controller: _subtask,
                            onSubmitted: (_) => _addSubtask(),
                            decoration: const InputDecoration(
                              hintText: 'Yeni alt görev',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Alt görev ekle',
                          onPressed: _addSubtask,
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TodoFormSectionHeader(
                    key: const ValueKey('todo-notes-section-toggle'),
                    icon: Icons.notes_rounded,
                    title: 'Notlar',
                    subtitle: 'Hatırlamak istediğin ayrıntılar.',
                    color: FlorienColors.softPink,
                    expanded: _notesExpanded,
                    onTap: () =>
                        setState(() => _notesExpanded = !_notesExpanded),
                  ),
                  if (_notesExpanded) ...[
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('todo-detail-notes'),
                      controller: _notes,
                      minLines: 4,
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Notlarını buraya yaz…',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickList(List<TodoListDefinition> lists) async {
    const defaultList = '__default_todo_list__';
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            Text('Liste seç', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.checklist_rounded),
              title: const Text('To-do'),
              trailing: _todoListId == null
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.pop(context, defaultList),
            ),
            for (final list in lists)
              ListTile(
                leading: const Icon(Icons.list_alt_rounded),
                title: Text(list.name),
                trailing: _todoListId == list.id
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, list.id),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _todoListId = selected == defaultList ? null : selected);
  }
}

class _TodoFormSectionHeader extends StatelessWidget {
  const _TodoFormSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.trailing,
    this.expanded,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget? trailing;
  final bool? expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(FlorienRadius.md),
        border: Border.all(
          color: context.palette.border,
          width: FlorienBorders.thin,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
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
          ?trailing,
          if (expanded case final expanded?)
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
            ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(FlorienRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FlorienRadius.md),
        child: content,
      ),
    );
  }
}

class _DetailIcon extends StatelessWidget {
  const _DetailIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: FlorienColors.primaryLight,
      borderRadius: BorderRadius.circular(FlorienRadius.sm),
      border: Border.all(
        color: context.palette.border,
        width: FlorienBorders.thin,
      ),
    ),
    child: Icon(icon, size: 18, color: FlorienColors.onPrimary),
  );
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(
        color: context.palette.border,
        width: FlorienBorders.thin,
      ),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
}

String _durationLabel(int minutes) => switch (minutes) {
  60 => '1 saat',
  90 => '1,5 saat',
  120 => '2 saat',
  _ => '$minutes dk',
};
