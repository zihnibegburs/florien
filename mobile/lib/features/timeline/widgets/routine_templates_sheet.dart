import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/data/routine_templates.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/utils/task_icons.dart';
import 'package:florien/core/widgets/florien_soft_overlay.dart';
import 'package:florien/features/providers.dart';

Future<void> showRoutineTemplatesSheet(BuildContext context, WidgetRef ref, DateTime date) {
  return showFlorienBottomSheet(
    context: context,
    builder: (_) => _RoutineTemplatesSheet(selectedDate: date),
  );
}

class _RoutineTemplatesSheet extends ConsumerWidget {
  const _RoutineTemplatesSheet({required this.selectedDate});

  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(appLanguageProvider).valueOrNull ?? 'tr';
    final templates = routineTemplatesFor(lang);

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.routineTemplates, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ...templates.map((t) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: FlorienColors.fromHex(t.color).withValues(alpha: 0.15),
                  child: Icon(TaskIcons.fromName(t.icon), color: FlorienColors.fromHex(t.color)),
                ),
                title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${t.steps.length} steps'),
                trailing: const Icon(Icons.add_rounded),
                onTap: () => _apply(context, ref, t),
              )),
        ],
      ),
    );
  }

  Future<void> _apply(BuildContext context, WidgetRef ref, RoutineTemplate template) async {
    final s = ref.read(stringsProvider);
    var start = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      DateTime.now().hour,
      (DateTime.now().minute ~/ 5) * 5,
    );
    try {
      for (final step in template.steps) {
        await ref.read(timelineProvider.notifier).createTask(
              title: step.title,
              durationMinutes: step.durationMinutes,
              color: step.color,
              icon: step.icon,
              scheduledAt: start,
            );
        start = start.add(Duration(minutes: step.durationMinutes + 5));
      }
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.friendlyTaskActionError(e))));
      }
    }
  }
}
