import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/presentation/realtime_task_icon_controller.dart';

class TodoDetailScreen extends ConsumerStatefulWidget {
  const TodoDetailScreen({
    super.key,
    required this.initialTitle,
    required this.initialDuration,
    required this.priority,
    required this.todoListId,
    this.taskId,
    this.initialDescription = '',
    this.initialSubtasks = const [],
    this.initialIcon = 'other',
  });

  final String initialTitle;
  final String? taskId;
  final int initialDuration;
  final TaskPriority priority;
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
  late TaskPriority _priority = widget.priority;
  late String? _todoListId = widget.todoListId;
  bool _saving = false;
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
    setState(() {
      _subtasks.add(value);
      _subtask.clear();
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await _taskIcon.onTaskChanged(title);
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
          priority: _priority,
          todoListId: _todoListId,
          subtasks: _subtasks,
          icon: _taskIcon.value.category.storageName,
        );
      } else {
        await notifier.addDetailedWithIcon(
          title: title,
          description: description,
          durationMinutes: _duration,
          priority: _priority,
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filled(
              tooltip: 'Kaydet',
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          18,
          14,
          18,
          MediaQuery.viewInsetsOf(context).bottom + 32,
        ),
        children: [
          TextField(
            controller: _title,
            onChanged: _taskIcon.onTaskChanged,
            autofocus: widget.initialTitle.trim().isEmpty,
            textCapitalization: TextCapitalization.sentences,
            style: Theme.of(context).textTheme.titleLarge,
            decoration: InputDecoration(
              hintText: 'Görev başlığı',
              prefixIcon: ValueListenableBuilder(
                valueListenable: _taskIcon,
                builder: (_, result, __) => Icon(result.icon),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
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
                ListTile(
                  leading: const _DetailIcon(Icons.flag_outlined),
                  title: const Text('Öncelik'),
                  trailing: DropdownButton<TaskPriority>(
                    value: _priority,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(FlorienRadius.md),
                    items: TaskPriority.values
                        .map(
                          (priority) => DropdownMenuItem(
                            value: priority,
                            child: Text(_priorityLabel(priority)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _priority = value);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const _DetailIcon(Icons.timer_outlined),
                  title: const Text('Süre'),
                  trailing: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.palette.surfaceMuted,
                      borderRadius: BorderRadius.circular(99),
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
                  Row(
                    children: [
                      const _DetailIcon(Icons.account_tree_outlined),
                      const SizedBox(width: 10),
                      Text(
                        'Alt görevler',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      if (_subtasks.isNotEmpty)
                        _ValuePill(label: '${_subtasks.length} adet'),
                    ],
                  ),
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
                  Row(
                    children: [
                      const _DetailIcon(Icons.notes_rounded),
                      const SizedBox(width: 10),
                      Text(
                        'Notlar',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notes,
                    minLines: 4,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Notlarını buraya yaz…',
                    ),
                  ),
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

class _DetailIcon extends StatelessWidget {
  const _DetailIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
  );
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: context.palette.surfaceMuted,
      borderRadius: BorderRadius.circular(99),
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

String _priorityLabel(TaskPriority priority) => switch (priority) {
  TaskPriority.high => 'Yüksek',
  TaskPriority.medium => 'Orta',
  TaskPriority.low => 'Düşük',
  TaskPriority.none => 'Yapılacak',
};
