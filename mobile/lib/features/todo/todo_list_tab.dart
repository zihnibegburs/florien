import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/services/speech_input_service.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_soft_overlay.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/presentation/realtime_task_icon_controller.dart';
import 'package:florien/features/task_icon/presentation/task_icon_badge.dart';
import 'package:florien/features/todo/completion_celebration_screen.dart';
import 'package:florien/features/todo/todo_detail_screen.dart';

Future<void> showTodoQuickAdd({
  required BuildContext context,
  required WidgetRef ref,
  String? todoListId,
  String initialTitle = '',
  bool autofocus = true,
}) async {
  final lists = await ref.read(todoListsProvider.future);
  if (!context.mounted) return;
  final details = await showFlorienBottomSheet<_TodoQuickDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(),
    builder: (_) => _AddTodoDialog(
      todoListId: todoListId,
      lists: lists,
      initialTitle: initialTitle,
      autofocus: autofocus,
    ),
  );
  if (details != null && context.mounted) {
    await pushFlorienOverlayRoute<bool>(
      context: context,
      builder: (_) => TodoDetailScreen(
        initialTitle: details.title,
        initialDuration: details.duration,
        todoListId: details.todoListId,
        initialIcon: details.icon,
      ),
    );
  }
}

class TodoListTab extends ConsumerStatefulWidget {
  const TodoListTab({super.key});

  @override
  ConsumerState<TodoListTab> createState() => _TodoListTabState();
}

class _TodoListTabState extends ConsumerState<TodoListTab> {
  String? _selectedListId;
  bool _tasksCollapsed = false;
  bool _showDuration = true;
  bool _completedCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(inboxProvider);
    final lists = ref.watch(todoListsProvider).valueOrNull ?? const [];
    TodoListDefinition? currentList;
    if (_selectedListId != null) {
      for (final list in lists) {
        if (list.id == _selectedListId) {
          currentList = list;
          break;
        }
      }
    }
    final activeListId = currentList?.id;
    return inbox.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          const Center(child: Text('Yapılacaklar yüklenemedi.')),
      data: (tasks) {
        final visibleTasks = tasks
            .where((task) => task.todoListId == activeListId)
            .toList();
        final completedTasks = visibleTasks
            .where((task) => task.isCompleted)
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
          children: [
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ListTitle(
                          label: 'To-do',
                          selected: activeListId == null,
                          onTap: () => setState(() => _selectedListId = null),
                        ),
                        for (final list in lists)
                          _ListTitle(
                            label: list.name,
                            selected: activeListId == list.id,
                            onTap: () =>
                                setState(() => _selectedListId = list.id),
                          ),
                        _ListAddButton(onTap: () => _createList(lists)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _TodoIconButton(
                  tooltip: 'Liste seçenekleri',
                  onPressed: () => _showHeaderMenu(lists),
                  icon: Icons.more_horiz_rounded,
                  filled: false,
                ),
                const SizedBox(width: 4),
                _TodoIconButton(
                  tooltip: 'Yeni yapılacak ekle',
                  onPressed: _showAdd,
                  icon: Icons.add_rounded,
                ),
              ],
            ),
            if (currentList?.description.isNotEmpty ?? false) ...[
              const SizedBox(height: 6),
              Text(
                currentList!.description,
                style: TextStyle(color: context.palette.textSecondary),
              ),
            ],
            const SizedBox(height: 22),
            _TodoSection(
              section: _defaultSection,
              tasks: visibleTasks.where((task) => !task.isCompleted).toList(),
              collapsed: _tasksCollapsed,
              onToggle: () =>
                  setState(() => _tasksCollapsed = !_tasksCollapsed),
              onAdd: _showAdd,
              showDuration: _showDuration,
            ),
            const SizedBox(height: 16),
            if (completedTasks.isNotEmpty) ...[
              _TodoSection(
                section: _completedSection,
                tasks: completedTasks,
                collapsed: _completedCollapsed,
                onToggle: () =>
                    setState(() => _completedCollapsed = !_completedCollapsed),
                onAdd: () {},
                showDuration: _showDuration,
                allowAdd: false,
                completedTarget: true,
                onTaskDropped: (task) =>
                    _moveTaskToSection(task, completed: true),
              ),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }

  Future<void> _showAdd() async {
    await showTodoQuickAdd(
      context: context,
      ref: ref,
      todoListId: _selectedListId,
    );
  }

  Future<void> _moveTaskToSection(
    TaskModel task, {
    bool completed = false,
  }) async {
    final notifier = ref.read(inboxProvider.notifier);
    if (completed) {
      if (!task.isCompleted) await notifier.completeTask(task.id);
      return;
    }
    if (task.isCompleted) await notifier.uncompleteTask(task.id);
  }

  Future<void> _handleMenu(
    _TodoMenuAction action,
    List<TodoListDefinition> lists,
  ) async {
    switch (action) {
      case _TodoMenuAction.newList:
        final created = await _showListEditor();
        if (created != null && mounted) {
          await ref.read(todoListsProvider.notifier).save([...lists, created]);
          if (mounted) setState(() => _selectedListId = created.id);
        }
      case _TodoMenuAction.editLists:
        await pushFlorienOverlayRoute<void>(
          context: context,
          builder: (_) => _EditListsScreen(
            lists: lists,
            onSave: (updated) =>
                ref.read(todoListsProvider.notifier).save(updated),
            onEdit: _showListEditor,
          ),
        );
      case _TodoMenuAction.options:
        await _showOptionsMenu();
    }
  }

  Future<void> _createList(List<TodoListDefinition> lists) async {
    final created = await _showListEditor();
    if (created == null || !mounted) return;
    await ref.read(todoListsProvider.notifier).save([...lists, created]);
    if (mounted) setState(() => _selectedListId = created.id);
  }

  Future<void> _showHeaderMenu(List<TodoListDefinition> lists) async {
    final action = await showFlorienBottomSheet<_TodoMenuAction>(
      context: context,
      builder: (_) => _TodoHeaderMenuSheet(showDuration: _showDuration),
    );
    if (action != null && mounted) await _handleMenu(action, lists);
  }

  Future<TodoListDefinition?> _showListEditor([TodoListDefinition? existing]) =>
      showFlorienBottomSheet<TodoListDefinition>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ListEditorSheet(existing: existing),
      );

  Future<void> _showOptionsMenu() async {
    await showFlorienSoftDialog<void>(
      context: context,
      maxWidth: 340,
      builder: (_) => _TodoOptionsDialog(
        showDuration: _showDuration,
        onChanged: (value) => setState(() => _showDuration = value),
      ),
    );
  }
}

enum _TodoMenuAction { newList, editLists, options }

class _TodoHeaderMenuSheet extends StatelessWidget {
  const _TodoHeaderMenuSheet({required this.showDuration});

  final bool showDuration;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: context.palette.border, width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .78,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.palette.border,
                    borderRadius: BorderRadius.circular(FlorienRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: FlorienColors.aiLavender,
                      borderRadius: BorderRadius.circular(FlorienRadius.sm),
                      border: Border.all(color: context.palette.border),
                    ),
                    child: const Icon(Icons.tune_rounded, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'To-do düzeni',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Listelerini ve görünümü düzenle.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _TodoMenuActionCard(
                      icon: Icons.add_rounded,
                      label: 'Yeni liste',
                      color: context.palette.primaryMuted,
                      onTap: () =>
                          Navigator.pop(context, _TodoMenuAction.newList),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TodoMenuActionCard(
                      icon: Icons.edit_note_rounded,
                      label: 'Düzenleme listeleri',
                      color: context.palette.aiSurface,
                      onTap: () =>
                          Navigator.pop(context, _TodoMenuAction.editLists),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'GÖRÜNÜM',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.palette.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 8),
              _TodoMenuRow(
                icon: Icons.visibility_outlined,
                label: 'Görünüm ayarları',
                value: showDuration ? 'Süre açık' : 'Süre kapalı',
                color: FlorienColors.softPink,
                onTap: () => Navigator.pop(context, _TodoMenuAction.options),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TodoMenuActionCard extends StatelessWidget {
  const _TodoMenuActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(FlorienRadius.md),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FlorienRadius.md),
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FlorienRadius.md),
          border: Border.all(
            color: context.palette.border,
            width: FlorienBorders.thin,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 23),
            const Spacer(),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TodoMenuRow extends StatelessWidget {
  const _TodoMenuRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.surfaceMuted,
    borderRadius: BorderRadius.circular(FlorienRadius.md),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FlorienRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FlorienRadius.md),
          border: Border.all(
            color: context.palette.border,
            width: FlorienBorders.thin,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(FlorienRadius.sm),
              ),
              child: Icon(icon, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.palette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class _ListTitle extends StatelessWidget {
  const _ListTitle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FlorienRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? FlorienColors.primary : context.palette.surface,
            borderRadius: BorderRadius.circular(FlorienRadius.pill),
            border: Border.all(
              color: context.palette.border,
              width: FlorienBorders.thin,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -.3,
              color: selected
                  ? FlorienColors.onPrimary
                  : context.palette.textSecondary,
            ),
          ),
        ),
      ),
    ),
  );
}

class _ListAddButton extends StatelessWidget {
  const _ListAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Tooltip(
      message: 'Yeni liste oluştur',
      child: Material(
        color: context.palette.surfaceMuted,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.palette.border),
            ),
            child: Icon(
              Icons.playlist_add_rounded,
              size: 19,
              color: context.palette.textPrimary,
            ),
          ),
        ),
      ),
    ),
  );
}

class _ListEditorSheet extends StatefulWidget {
  const _ListEditorSheet({this.existing});
  final TodoListDefinition? existing;

  @override
  State<_ListEditorSheet> createState() => _ListEditorSheetState();
}

class _ListEditorSheetState extends State<_ListEditorSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      TodoListDefinition(
        id:
            widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        description: _description.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.surface,
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(FlorienRadius.xl),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Yeni liste' : 'Listeyi düzenle',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Liste adı'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'Tanım (isteğe bağlı)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Vazgeç'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Kaydet'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _EditListsScreen extends StatefulWidget {
  const _EditListsScreen({
    required this.lists,
    required this.onSave,
    required this.onEdit,
  });
  final List<TodoListDefinition> lists;
  final Future<void> Function(List<TodoListDefinition>) onSave;
  final Future<TodoListDefinition?> Function([TodoListDefinition?]) onEdit;

  @override
  State<_EditListsScreen> createState() => _EditListsScreenState();
}

class _EditListsScreenState extends State<_EditListsScreen> {
  late final List<TodoListDefinition> _lists = [...widget.lists];

  Future<void> _save() => widget.onSave(_lists);

  Future<void> _edit(TodoListDefinition list) async {
    final updated = await widget.onEdit(list);
    if (updated == null || !mounted) return;
    setState(() {
      final index = _lists.indexWhere((item) => item.id == list.id);
      _lists[index] = updated;
    });
    await _save();
  }

  Future<void> _delete(int index) async {
    setState(() => _lists.removeAt(index));
    await _save();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Listeleri düzenle'),
      leading: IconButton(
        tooltip: 'Geri',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    ),
    body: ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: _lists.length + 1,
      onReorder: (oldIndex, newIndex) async {
        if (oldIndex >= _lists.length) return;
        if (newIndex > oldIndex) newIndex--;
        if (newIndex >= _lists.length) newIndex = _lists.length - 1;
        setState(() {
          final item = _lists.removeAt(oldIndex);
          _lists.insert(newIndex, item);
        });
        await _save();
      },
      itemBuilder: (context, index) {
        if (index == _lists.length) {
          return Card(
            key: ValueKey('default'),
            child: const ListTile(
              title: Text(
                'To-do',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('Varsayılan liste'),
              trailing: Icon(Icons.lock_outline_rounded),
            ),
          );
        }
        final list = _lists[index];
        return Dismissible(
          key: ValueKey(list.id),
          direction: DismissDirection.startToEnd,
          background: Container(
            color: Theme.of(context).colorScheme.error,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => _delete(index),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              title: Text(
                list.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: list.description.isEmpty
                  ? const Text('Tanım yok')
                  : Text(list.description),
              trailing: const Icon(Icons.drag_handle_rounded),
              onTap: () => _edit(list),
            ),
          ),
        );
      },
    ),
  );
}

class _TodoOptionsDialog extends StatefulWidget {
  const _TodoOptionsDialog({
    required this.showDuration,
    required this.onChanged,
  });
  final bool showDuration;
  final ValueChanged<bool> onChanged;

  @override
  State<_TodoOptionsDialog> createState() => _TodoOptionsDialogState();
}

class _TodoOptionsDialogState extends State<_TodoOptionsDialog> {
  late bool _showDuration = widget.showDuration;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Görünüm ayarları'),
    contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
    content: Container(
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(FlorienRadius.md),
        border: Border.all(
          color: context.palette.border,
          width: FlorienBorders.thin,
        ),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        value: _showDuration,
        onChanged: (value) {
          setState(() => _showDuration = value);
          widget.onChanged(value);
        },
        secondary: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: FlorienColors.softPink,
            borderRadius: BorderRadius.circular(FlorienRadius.sm),
          ),
          child: const Icon(Icons.timer_outlined, size: 19),
        ),
        title: const Text('Görev süresi'),
        subtitle: Text(_showDuration ? 'Kartlarda görünür' : 'Kartlarda gizli'),
      ),
    ),
  );
}

class _AddTodoDialog extends ConsumerStatefulWidget {
  const _AddTodoDialog({
    required this.todoListId,
    required this.lists,
    this.initialTitle = '',
    this.autofocus = true,
  });

  final String? todoListId;
  final List<TodoListDefinition> lists;
  final String initialTitle;
  final bool autofocus;

  @override
  ConsumerState<_AddTodoDialog> createState() => _AddTodoDialogState();
}

class _AddTodoDialogState extends ConsumerState<_AddTodoDialog> {
  late final _controller = TextEditingController(text: widget.initialTitle);
  bool _isSaving = false;
  int _duration = 15;
  late String? _todoListId = widget.todoListId;
  late final RealtimeTaskIconController _taskIcon =
      RealtimeTaskIconController();
  final _speech = SpeechInputService();
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle.trim().isNotEmpty) {
      _taskIcon.onTaskChanged(widget.initialTitle);
    }
  }

  String get _listName {
    if (_todoListId == null) return 'To-do';
    for (final list in widget.lists) {
      if (list.id == _todoListId) return list.name;
    }
    return 'To-do';
  }

  @override
  void dispose() {
    _controller.dispose();
    _taskIcon.dispose();
    _speech.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceInput() async {
    if (_listening) {
      await _speech.stop();
      return;
    }
    final existingText = _controller.text.trim();
    await _speech.start(
      onText: (spokenText) {
        if (!mounted) return;
        final text = existingText.isEmpty
            ? spokenText
            : '$existingText $spokenText';
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        _taskIcon.onTaskChanged(text);
      },
      onListeningChanged: (isListening) {
        if (mounted) setState(() => _listening = isListening);
      },
      onError: _showVoiceError,
    );
  }

  void _showVoiceError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _close() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop();
  }

  Future<void> _create() async {
    final title = _controller.text.trim();
    if (title.isEmpty || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      _taskIcon.onTaskChanged(title);
      await ref
          .read(inboxProvider.notifier)
          .addToInbox(
            title: title,
            todoListId: _todoListId,
            durationMinutes: _duration,
            icon: _taskIcon.value.category.storageName,
          );
      if (mounted) _close();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboard),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: palette.border, width: 2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .08),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: palette.aiSurface,
                      borderRadius: BorderRadius.circular(FlorienRadius.sm),
                      border: Border.all(color: palette.border),
                    ),
                    child: const Icon(Icons.checklist_rounded, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Yeni To-do',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: _isSaving ? null : _close,
                    iconSize: 19,
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(36),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: palette.aiSurface,
                  borderRadius: BorderRadius.circular(FlorienRadius.md),
                  border: Border.all(
                    color: palette.border,
                    width: FlorienBorders.thin,
                  ),
                ),
                child: TextField(
                  key: const ValueKey('todo-quick-title'),
                  controller: _controller,
                  onChanged: _taskIcon.onTaskChanged,
                  autofocus: widget.autofocus,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _create(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ne yapman gerekiyor?',
                    border: InputBorder.none,
                    prefixIcon: ValueListenableBuilder(
                      valueListenable: _taskIcon,
                      builder: (_, result, _) =>
                          TaskIconBadge.forResult(result, size: 34),
                    ),
                    suffixIconConstraints: const BoxConstraints(),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: const ValueKey('todo-quick-voice'),
                            tooltip: _listening ? 'Konuşmayı bitir' : 'Konuş',
                            onPressed: _isSaving ? null : _toggleVoiceInput,
                            style: IconButton.styleFrom(
                              fixedSize: const Size.square(34),
                              padding: EdgeInsets.zero,
                              backgroundColor: _listening
                                  ? FlorienColors.softPink
                                  : palette.surface,
                              side: BorderSide(
                                color: palette.border,
                                width: FlorienBorders.thin,
                              ),
                            ),
                            icon: Icon(
                              _listening
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton.filled(
                            key: const ValueKey('todo-quick-submit'),
                            tooltip: _isSaving ? 'Ekleniyor' : 'Ekle',
                            onPressed: _isSaving ? null : _create,
                            style: IconButton.styleFrom(
                              fixedSize: const Size.square(34),
                              padding: EdgeInsets.zero,
                            ),
                            icon: _isSaving
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, size: 19),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (widget.lists.isNotEmpty) ...[
                    _QuickOptionChip(
                      key: const ValueKey('todo-quick-list'),
                      icon: Icons.format_list_bulleted_rounded,
                      label: _listName,
                      onTap: _pickList,
                    ),
                    const SizedBox(width: 8),
                  ],
                  _QuickOptionChip(
                    key: const ValueKey('todo-quick-duration'),
                    icon: Icons.timer_outlined,
                    label: _durationLabel(_duration).toUpperCase(),
                    onTap: _pickDuration,
                  ),
                  const SizedBox(width: 8),
                  _QuickOptionChip(
                    key: const ValueKey('todo-quick-details'),
                    icon: Icons.more_horiz_rounded,
                    label: '',
                    onTap: () => Navigator.pop(
                      context,
                      _TodoQuickDraft(
                        title: _controller.text,
                        duration: _duration,
                        todoListId: _todoListId,
                        icon: _taskIcon.value.category.storageName,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDuration() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [5, 10, 15, 30, 45, 60, 90, 120]
              .map(
                (value) => ListTile(
                  title: Text(_durationLabel(value)),
                  trailing: value == _duration
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(context, value),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _duration = selected);
  }

  Future<void> _pickList() async {
    const defaultList = '__default_todo_list__';
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Text(
                'Liste seç',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.checklist_rounded),
              title: const Text('To-do'),
              trailing: _todoListId == null
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.pop(context, defaultList),
            ),
            for (final list in widget.lists)
              ListTile(
                leading: const Icon(Icons.list_alt_rounded),
                title: Text(list.name),
                subtitle: list.description.isEmpty
                    ? null
                    : Text(
                        list.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
    setState(() {
      _todoListId = selected == defaultList ? null : selected;
    });
  }
}

class _TodoQuickDraft {
  const _TodoQuickDraft({
    required this.title,
    required this.duration,
    required this.todoListId,
    required this.icon,
  });

  final String title;
  final int duration;
  final String? todoListId;
  final String icon;
}

String _durationLabel(int minutes) => switch (minutes) {
  60 => '1 saat',
  90 => '1,5 saat',
  120 => '2 saat',
  _ => '$minutes dk',
};

class _QuickOptionChip extends StatelessWidget {
  const _QuickOptionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.surfaceMuted,
    borderRadius: BorderRadius.circular(99),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ],
        ),
      ),
    ),
  );
}

class _TodoSectionData {
  const _TodoSectionData(this.label, this.shortLabel, this.color, this.icon);

  final String label;
  final String shortLabel;
  final Color color;
  final IconData icon;
}

const _defaultSection = _TodoSectionData(
  'YAPILACAK',
  'Yapılacak',
  FlorienColors.primary,
  Icons.check_circle_outline_rounded,
);

const _completedSection = _TodoSectionData(
  'TAMAMLANDI',
  'Tamamlandı',
  FlorienColors.success,
  Icons.check_circle_rounded,
);

class _TodoSection extends StatelessWidget {
  const _TodoSection({
    required this.section,
    required this.tasks,
    required this.collapsed,
    required this.onToggle,
    required this.onAdd,
    required this.showDuration,
    this.allowAdd = true,
    this.completedTarget = false,
    this.onTaskDropped,
  });

  final _TodoSectionData section;
  final List<TaskModel> tasks;
  final bool collapsed;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final bool showDuration;
  final bool allowAdd;
  final bool completedTarget;
  final Future<void> Function(TaskModel task)? onTaskDropped;

  @override
  Widget build(BuildContext context) => DragTarget<TaskModel>(
    key: ValueKey(completedTarget ? 'todo-drop-completed' : 'todo-drop-tasks'),
    onWillAcceptWithDetails: (details) {
      return onTaskDropped != null &&
          completedTarget &&
          !details.data.isCompleted;
    },
    onAcceptWithDetails: (details) => onTaskDropped?.call(details.data),
    builder: (context, candidates, rejected) => AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: candidates.isEmpty ? EdgeInsets.zero : const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: candidates.isEmpty
            ? Colors.transparent
            : section.color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(FlorienRadius.md),
        border: candidates.isEmpty
            ? null
            : Border.all(color: section.color.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Material(
                color: section.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(FlorienRadius.sm),
                child: InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(FlorienRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(section.icon, size: 16, color: section.color),
                        const SizedBox(width: 6),
                        Text(
                          '${section.label} (${tasks.length})',
                          style: TextStyle(
                            color: context.palette.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .4,
                          ),
                        ),
                        Icon(
                          collapsed
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          color: context.palette.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!collapsed) ...[
            const SizedBox(height: 5),
            if (tasks.isEmpty && allowAdd)
              _EmptySection(onAdd: onAdd)
            else
              ...tasks.map(
                (task) => _TodoDraggableTask(
                  key: ValueKey(task.id),
                  task: task,
                  showDuration: showDuration,
                ),
              ),
          ],
        ],
      ),
    ),
  );
}

class _TodoDraggableTask extends StatelessWidget {
  const _TodoDraggableTask({
    super.key,
    required this.task,
    required this.showDuration,
  });

  final TaskModel task;
  final bool showDuration;

  @override
  Widget build(BuildContext context) {
    final card = _TodoTaskCard(task: task, showDuration: showDuration);
    return LongPressDraggable<TaskModel>(
      data: task,
      delay: const Duration(milliseconds: 280),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width - 36,
          child: Transform.scale(
            scale: .92,
            child: Opacity(
              key: ValueKey('todo-drag-feedback-${task.id}'),
              opacity: .72,
              child: _TodoDragPreview(task: task, showDuration: showDuration),
            ),
          ),
        ),
      ),
      childWhenDragging: Transform.scale(
        scale: .96,
        child: Opacity(
          key: ValueKey('todo-drag-placeholder-${task.id}'),
          opacity: .18,
          child: card,
        ),
      ),
      child: card,
    );
  }
}

class _TodoDragPreview extends StatelessWidget {
  const _TodoDragPreview({required this.task, required this.showDuration});

  final TaskModel task;
  final bool showDuration;

  @override
  Widget build(BuildContext context) {
    final color = FlorienColors.fromHex(task.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.12),
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
          TaskIconBadge.forTask(icon: task.icon, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (showDuration)
                  Text(
                    '${task.durationMinutes} dk',
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Icon(Icons.drag_indicator_rounded, color: color),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(FlorienRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: context.palette.surfaceMuted.withValues(alpha: .42),
            borderRadius: BorderRadius.circular(FlorienRadius.sm),
          ),
          child: Row(
            children: [
              Icon(
                Icons.add_rounded,
                size: 16,
                color: context.palette.textSecondary.withValues(alpha: .68),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Görev ekle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.palette.textSecondary.withValues(alpha: .72),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodoTaskCard extends ConsumerStatefulWidget {
  const _TodoTaskCard({required this.task, required this.showDuration});

  final TaskModel task;
  final bool showDuration;

  @override
  ConsumerState<_TodoTaskCard> createState() => _TodoTaskCardState();
}

class _TodoTaskCardState extends ConsumerState<_TodoTaskCard> {
  bool _expanded = false;

  TaskModel get task => widget.task;

  @override
  void didUpdateWidget(covariant _TodoTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!task.hasSubtasks) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final color = FlorienColors.fromHex(task.color);
    final completedSubtasks = task.completedSubtaskCount;
    final subtaskProgress = task.hasSubtasks
        ? completedSubtasks / task.subtasks.length
        : 0.0;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: task.isCompleted ? .58 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            color.withValues(alpha: task.isCompleted ? 0.04 : 0.10),
            context.palette.surface,
          ),
          borderRadius: BorderRadius.circular(FlorienRadius.lg),
          border: Border.all(
            color: context.palette.border,
            width: FlorienBorders.thin,
          ),
        ),
        child: Column(
          children: [
            ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -4),
              minTileHeight: widget.showDuration ? 42 : 38,
              minVerticalPadding: 0,
              contentPadding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
              leading: TaskIconBadge.forTask(icon: task.icon, size: 24),
              title: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  decoration: task.isCompleted
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationThickness: 2,
                ),
              ),
              subtitle: widget.showDuration
                  ? Text(
                      '${task.durationMinutes} dk',
                      style: TextStyle(
                        color: context.palette.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    )
                  : null,
              trailing: _TodoIconButton(
                tooltip: task.isCompleted
                    ? 'Tamamlanmadı olarak işaretle'
                    : 'Tamamla',
                icon: task.isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                compact: true,
                size: 24,
                filled: task.isCompleted,
                onPressed: () => _toggleCompletion(task),
              ),
              onTap: () => _showTaskOptions(context, ref),
            ),
            if (task.hasSubtasks) ...[
              Divider(height: 1, color: context.palette.border),
              Tooltip(
                message: _expanded
                    ? 'Alt görevleri gizle'
                    : 'Alt görevleri göster',
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: subtaskProgress,
                              minHeight: 4,
                              backgroundColor: context.palette.surfaceMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            '$completedSubtasks / ${task.subtasks.length} alt görev',
                            style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: _expanded ? .5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: _expanded
                      ? Column(
                          children: [
                            for (final subtask in task.subtasks)
                              _TodoSubtaskRow(
                                subtask: subtask,
                                parentColor: color,
                              ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleCompletion(TaskModel target) async {
    final notifier = ref.read(inboxProvider.notifier);
    if (target.isCompleted) {
      await notifier.uncompleteTask(target.id);
    } else {
      await notifier.completeTask(target.id);
      final counts = await ref.read(manualCompletionSummaryProvider)(target.id);
      if (!mounted) return;
      await showCompletionCelebration(context, counts);
    }
  }

  Future<void> _showTaskOptions(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<_TaskMenuAction>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          children: [
            _TaskOptionTile(
              icon: Icons.copy_all_outlined,
              label: 'Bir kopya oluştur',
              onTap: () => Navigator.pop(context, _TaskMenuAction.createCopy),
            ),
            _TaskOptionTile(
              icon: Icons.move_to_inbox_outlined,
              label: 'Listeye taşı',
              onTap: () => Navigator.pop(context, _TaskMenuAction.moveToList),
            ),
            _TaskOptionTile(
              icon: Icons.calendar_month_outlined,
              label: 'Tarife',
              onTap: () => Navigator.pop(context, _TaskMenuAction.schedule),
            ),
            if (!task.hasSubtasks)
              const _TaskOptionTile(
                icon: Icons.auto_awesome_rounded,
                label: 'Ayrım öner',
              ),
            _TaskOptionTile(
              icon: Icons.play_circle_outline_rounded,
              label: 'Görevi başlat',
              onTap: () => Navigator.pop(context, _TaskMenuAction.startFocus),
            ),
            _TaskOptionTile(
              icon: Icons.edit_outlined,
              label: 'Yapılacakları düzenle',
              onTap: () => Navigator.pop(context, _TaskMenuAction.edit),
            ),
            _TaskOptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Yapılacakları sil',
              destructive: true,
              onTap: () => Navigator.pop(context, _TaskMenuAction.delete),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case _TaskMenuAction.createCopy:
        await pushFlorienOverlayRoute<bool>(
          context: context,
          builder: (_) => TodoDetailScreen(
            initialTitle: '${task.title} (Kopya)',
            initialDescription: task.description ?? '',
            initialSubtasks: task.subtasks
                .map((subtask) => subtask.title)
                .toList(),
            initialDuration: task.durationMinutes,
            todoListId: task.todoListId,
            initialIcon: task.icon,
          ),
        );
      case _TaskMenuAction.moveToList:
        await _showMoveToList(context, ref);
      case _TaskMenuAction.schedule:
        await _showSchedule(context, ref);
      case _TaskMenuAction.startFocus:
        await ref.read(startTaskFocusProvider)(task);
        if (!context.mounted) return;
        ref.read(focusTaskLaunchProvider.notifier).state = FocusTaskLaunch(
          taskId: task.id,
          title: task.title,
          durationMinutes: task.durationMinutes,
          icon: task.icon,
          color: task.color,
        );
      case _TaskMenuAction.edit:
        await pushFlorienOverlayRoute<bool>(
          context: context,
          builder: (_) => TodoDetailScreen(
            taskId: task.id,
            initialTitle: task.title,
            initialDescription: task.description ?? '',
            initialSubtasks: task.subtasks
                .map((subtask) => subtask.title)
                .toList(),
            initialDuration: task.durationMinutes,
            todoListId: task.todoListId,
            initialIcon: task.icon,
          ),
        );
      case _TaskMenuAction.delete:
        await ref.read(inboxProvider.notifier).deleteTask(task.id);
      case null:
        return;
    }
  }

  Future<void> _showSchedule(BuildContext context, WidgetRef ref) async {
    final selectedDate = await showFlorienBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ScheduleTaskSheet(),
    );
    if (selectedDate == null || !context.mounted) return;
    final scheduledAt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      12,
    );
    await ref.read(inboxProvider.notifier).scheduleTask(task.id, scheduledAt);
    ref.invalidate(dailyTimelineProvider(_scheduleDateOnly(selectedDate)));
  }

  Future<void> _showMoveToList(BuildContext context, WidgetRef ref) async {
    const defaultList = '__default_todo_list__';
    final lists = ref.read(todoListsProvider).valueOrNull ?? const [];
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            Text('Listeye taşı', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _MoveListTile(
              label: 'To-do',
              selected: task.todoListId == null,
              onTap: () => Navigator.pop(context, defaultList),
            ),
            for (final list in lists) ...[
              const SizedBox(height: 8),
              _MoveListTile(
                label: list.name,
                selected: task.todoListId == list.id,
                onTap: () => Navigator.pop(context, list.id),
              ),
            ],
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    final targetListId = selected == defaultList ? null : selected;
    if (targetListId == task.todoListId) return;
    await ref.read(inboxProvider.notifier).moveTask(task.id, targetListId);
  }
}

class _TodoSubtaskRow extends ConsumerWidget {
  const _TodoSubtaskRow({required this.subtask, required this.parentColor});

  final TaskModel subtask;
  final Color parentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AnimatedOpacity(
    duration: const Duration(milliseconds: 180),
    opacity: subtask.isCompleted ? .55 : 1,
    child: Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.palette.border)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          TaskIconBadge.forTask(icon: subtask.icon, size: 32),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              subtask.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: subtask.isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                decorationThickness: 2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _TodoIconButton(
            tooltip: subtask.isCompleted
                ? '${subtask.title} tamamlanmadı olarak işaretle'
                : '${subtask.title} tamamla',
            icon: subtask.isCompleted
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            compact: true,
            filled: subtask.isCompleted,
            onPressed: () async {
              final notifier = ref.read(inboxProvider.notifier);
              if (subtask.isCompleted) {
                await notifier.uncompleteTask(subtask.id);
              } else {
                await notifier.completeTask(subtask.id);
              }
            },
          ),
        ],
      ),
    ),
  );
}

enum _TaskMenuAction {
  createCopy,
  moveToList,
  schedule,
  startFocus,
  edit,
  delete,
}

class _ScheduleTaskSheet extends StatefulWidget {
  const _ScheduleTaskSheet();

  @override
  State<_ScheduleTaskSheet> createState() => _ScheduleTaskSheetState();
}

class _ScheduleTaskSheetState extends State<_ScheduleTaskSheet> {
  late DateTime _selectedDate = _scheduleDateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final today = _scheduleDateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final weekend = _nextWeekday(today, DateTime.saturday, includeToday: true);
    final nextWeek = _nextWeekday(today, DateTime.monday);
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: context.palette.border)),
        ),
        child: ListView(
          key: const ValueKey('schedule-sheet-list'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.palette.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
                Expanded(
                  child: Text(
                    'Tarife',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Tarihi onayla',
                  onPressed: () => Navigator.pop(context, _selectedDate),
                  icon: const Icon(Icons.check_rounded),
                ),
              ],
            ),
            CalendarDatePicker(
              initialDate: _selectedDate,
              currentDate: today,
              firstDate: DateTime(today.year - 1),
              lastDate: DateTime(today.year + 5, 12, 31),
              onDateChanged: (value) =>
                  setState(() => _selectedDate = _scheduleDateOnly(value)),
            ),
            const Divider(height: 18),
            _ScheduleShortcut(
              icon: Icons.today_outlined,
              label: 'Bugün (${_weekdayShortLabel(today)})',
              onTap: () => Navigator.pop(context, today),
            ),
            _ScheduleShortcut(
              icon: Icons.light_mode_outlined,
              label: 'Yarın (${_weekdayShortLabel(tomorrow)})',
              onTap: () => Navigator.pop(context, tomorrow),
            ),
            _ScheduleShortcut(
              icon: Icons.weekend_outlined,
              label: 'Bu hafta sonu (${_weekdayShortLabel(weekend)})',
              onTap: () => Navigator.pop(context, weekend),
            ),
            _ScheduleShortcut(
              icon: Icons.redo_rounded,
              label:
                  'Gelecek hafta (${nextWeek.day} ${_monthShortLabel(nextWeek)} ${_weekdayShortLabel(nextWeek)})',
              onTap: () => Navigator.pop(context, nextWeek),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleShortcut extends StatelessWidget {
  const _ScheduleShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      ListTile(leading: Icon(icon), title: Text(label), onTap: onTap);
}

DateTime _scheduleDateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _nextWeekday(DateTime from, int weekday, {bool includeToday = false}) {
  var difference = (weekday - from.weekday) % 7;
  if (difference == 0 && !includeToday) difference = 7;
  return from.add(Duration(days: difference));
}

String _weekdayShortLabel(DateTime value) =>
    const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'][value.weekday - 1];

String _monthShortLabel(DateTime value) => const [
  'Oca',
  'Şub',
  'Mar',
  'Nis',
  'May',
  'Haz',
  'Tem',
  'Ağu',
  'Eyl',
  'Eki',
  'Kas',
  'Ara',
][value.month - 1];

class _MoveListTile extends StatelessWidget {
  const _MoveListTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? Theme.of(context).colorScheme.primaryContainer
        : context.palette.surfaceMuted,
    borderRadius: BorderRadius.circular(FlorienRadius.md),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FlorienRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (selected) const Icon(Icons.check_rounded, size: 18),
          ],
        ),
      ),
    ),
  );
}

class _TaskOptionTile extends StatelessWidget {
  const _TaskOptionTile({
    required this.icon,
    required this.label,
    this.destructive = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : context.palette.textPrimary;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap ?? () {},
    );
  }
}

class _TodoIconButton extends StatelessWidget {
  const _TodoIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.compact = false,
    this.filled = true,
    this.size,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final bool compact;
  final bool filled;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final resolvedSize = size ?? (compact ? 34.0 : 40.0);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            width: resolvedSize,
            height: resolvedSize,
            decoration: BoxDecoration(
              color: filled ? FlorienColors.primary : context.palette.surface,
              border: Border.all(
                color: context.palette.border,
                width: FlorienBorders.thin,
              ),
              borderRadius: BorderRadius.circular(FlorienRadius.sm),
            ),
            child: Icon(
              icon,
              color: filled
                  ? FlorienColors.onPrimary
                  : context.palette.textSecondary,
              size: size == null ? (compact ? 18 : 21) : resolvedSize * .54,
            ),
          ),
        ),
      ),
    );
  }
}
