import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimio/core/l10n/app_strings.dart';
import 'package:mimio/core/theme/mimio_theme.dart';
import 'package:mimio/features/providers.dart';
import 'package:mimio/features/timeline/widgets/todo_item.dart';

/// Compact unscheduled-task list embedded in Today.
class InboxSection extends ConsumerStatefulWidget {
  const InboxSection({super.key});

  @override
  ConsumerState<InboxSection> createState() => _InboxSectionState();
}

class _InboxSectionState extends ConsumerState<InboxSection> {
  final _titleController = TextEditingController();
  final _focusNode = FocusNode();
  bool _adding = false;
  bool _expanded = true;

  @override
  void dispose() {
    _titleController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _addInboxTask() async {
    if (_adding || _titleController.text.trim().isEmpty) return;
    setState(() => _adding = true);
    final s = ref.read(stringsProvider);

    try {
      await ref
          .read(inboxProvider.notifier)
          .addToInbox(title: _titleController.text.trim());
      _titleController.clear();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.friendlyTaskActionError(e))));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final inboxAsync = ref.watch(inboxProvider);
    final tasks = inboxAsync.valueOrNull ?? [];
    final count = tasks.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    s.inboxTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: MimioColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MimioColors.primary,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: context.palette.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: s.taskNameHint,
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _addInboxTask(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _adding || _titleController.text.trim().isEmpty
                      ? null
                      : _addInboxTask,
                  icon: _adding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_rounded),
                ),
              ],
            ),
            if (count == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  s.inboxHint,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.palette.textSecondary,
                  ),
                ),
              )
            else
              ...tasks.map((task) => TodoItem(task: task)),
          ],
        ],
      ),
    );
  }
}
