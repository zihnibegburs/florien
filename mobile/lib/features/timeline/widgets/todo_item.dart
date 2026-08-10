import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/utils/task_icons.dart';
import 'package:florien/core/widgets/liquid_glass.dart';
import 'package:florien/core/widgets/florien_soft_overlay.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/timeline/widgets/edit_task_sheet.dart';

class TodoItem extends ConsumerWidget {
  const TodoItem({super.key, required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final color = FlorienColors.fromHex(task.color);

    return LiquidGlass(
      margin: const EdgeInsets.only(bottom: 8),
      blur: false,
      borderRadius: BorderRadius.circular(16),
      tintOpacity: 0.8,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            TaskIcons.iconForTask(title: task.title, icon: task.icon),
            color: color,
            size: 18,
          ),
        ),
        title: Text(
          task.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        onTap: () => showFlorienBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) =>
              EditTaskSheet(task: task, selectedDate: DateTime.now()),
        ),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: s.scheduleTask,
              icon: const Icon(Icons.schedule_rounded, size: 20),
              onPressed: () => _schedule(context, ref),
            ),
            IconButton(
              tooltip: s.complete,
              icon: const Icon(
                Icons.check_rounded,
                size: 20,
                color: FlorienColors.success,
              ),
              onPressed: () => _complete(context, ref),
            ),
            IconButton(
              tooltip: s.delete,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: Colors.red.shade400,
              ),
              onPressed: () => _delete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _schedule(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (selectedDate == null) return;
    if (!context.mounted) return;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (selectedTime == null) return;
    final scheduled = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    try {
      await ref.read(inboxProvider.notifier).scheduleTask(task.id, scheduled);
      ref.invalidate(timelineProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.friendlyTaskActionError(e))));
    }
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    try {
      await ref.read(timelineProvider.notifier).completeTask(task.id);
      ref.invalidate(inboxProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.friendlyTaskActionError(e))));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    try {
      await ref.read(inboxProvider.notifier).deleteTask(task.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.friendlyTaskActionError(e))));
    }
  }
}
