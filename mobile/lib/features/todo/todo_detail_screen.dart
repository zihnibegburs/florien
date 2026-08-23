import 'package:flutter/material.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/services/planner_ai_service.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_card.dart';
import 'package:florien/core/widgets/florien_duration_picker.dart';
import 'package:florien/core/utils/subtask_sequence.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/premium/premium_gate.dart';
import 'package:florien/features/premium/premium_membership.dart';
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

  Future<void> _addSubtask() async {
    final value = _subtask.text.trim();
    if (value.isEmpty) return;
    if (!await requirePremiumAccess(context, ref, PremiumFeature.subtasks)) {
      return;
    }
    if (!mounted) return;
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
      SnackBar(
        content: Text(context.l10n('En fazla 30 alt görev ekleyebilirsin.')),
      ),
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
    if (!await requirePremiumAccess(context, ref, PremiumFeature.subtasks)) {
      return;
    }
    if (!mounted) return;

    setState(() => _generatingSubtasks = true);
    try {
      final generated = await ref
          .read(taskBreakdownServiceProvider)
          .generateSubtasks(title);
      if (!mounted || _title.text.trim().isEmpty) return;
      final additions = selectAiSubtaskAdditions(
        generated: generated,
        existing: _subtasks,
      );
      if (additions.isEmpty) return;
      setState(() => _subtasksExpanded = true);
      await revealSubtasksSequentially(
        subtasks: additions,
        canContinue: () => mounted && _title.text.trim() == title,
        onReveal: (subtask) => setState(() => _subtasks.add(subtask)),
      );
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
    final isPremium = ref.watch(
      premiumMembershipProvider.select(
        (membership) => membership.valueOrNull?.hasActivePremium == true,
      ),
    );
    var listName = context.l10n('To-do');
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
        title: Text(
          widget.isEditing
              ? context.l10n('Görevi düzenle')
              : context.l10n('Görev ekle'),
        ),
        leading: IconButton(
          tooltip: context.l10n('Kapat'),
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
            label: Text(
              _saving
                  ? context.l10n('Kaydediliyor...')
                  : context.l10n('To-do’yu kaydet'),
            ),
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
                    Expanded(
                      child: Text(
                        widget.isEditing
                            ? context.l10n('To-do görevini düzenle')
                            : context.l10n('Aklındaki işi yakala'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('todo-detail-title'),
                  controller: _title,
                  onChanged: _onTitleChanged,
                  textCapitalization: TextCapitalization.sentences,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: context.l10n('Ne yapman gerekiyor?'),
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
                    title: Text(context.l10n('Liste')),
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
                  title: Text(context.l10n('Süre')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ValuePill(label: _durationLabel(_duration)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: _pickDuration,
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
                  FlorienFormSectionHeader(
                    key: const ValueKey('todo-subtasks-section-toggle'),
                    icon: Icons.account_tree_outlined,
                    title: context.l10n('Alt görevler'),
                    subtitle: _subtasks.isEmpty
                        ? context.l10n(
                            'Küçük adımlar başlatmayı kolaylaştırır.',
                          )
                        : context.l10n(
                            'Adımları dilediğin sırayla düzenleyebilirsin.',
                          ),
                    color: FlorienColors.aiLavender,
                    trailing:
                        _title.text.trim().isNotEmpty &&
                            _subtasks.length < TaskModel.userSubtaskLimit
                        ? IconButton.filledTonal(
                            key: const ValueKey('todo-ai-subtasks-button'),
                            tooltip: isPremium
                                ? context.l10n('AI ile alt görev oluştur')
                                : context.l10n('Alt görevler Premium'),
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
                                : Icon(
                                    isPremium
                                        ? Icons.auto_awesome_rounded
                                        : Icons.lock_outline_rounded,
                                  ),
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
                          tooltip: context.l10n('Sil'),
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
                            decoration: InputDecoration(
                              hintText: context.l10n('Yeni alt görev'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: context.l10n('Alt görev ekle'),
                          onPressed: () => _addSubtask(),
                          icon: Icon(
                            isPremium
                                ? Icons.add_rounded
                                : Icons.lock_outline_rounded,
                          ),
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
                  FlorienFormSectionHeader(
                    key: const ValueKey('todo-notes-section-toggle'),
                    icon: Icons.notes_rounded,
                    title: context.l10n('Notlar'),
                    subtitle: context.l10n('Hatırlamak istediğin ayrıntılar.'),
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
                      decoration: InputDecoration(
                        hintText: context.l10n('Notlarını buraya yaz…'),
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

  Future<void> _pickDuration() async {
    final selected = await showFlorienDurationPicker(
      context: context,
      selected: _duration,
    );
    if (selected != null && mounted) setState(() => _duration = selected);
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
            Text(
              context.l10n('Liste seç'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.checklist_rounded),
              title: Text(context.l10n('To-do')),
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

String _durationLabel(int minutes) => florienDurationLabel(minutes);
