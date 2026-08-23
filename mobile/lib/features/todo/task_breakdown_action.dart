import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/services/planner_ai_service.dart';
import 'package:florien/features/premium/premium_gate.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/core/l10n/app_strings.dart';

typedef TaskBreakdownApplier =
    Future<void> Function(TaskModel task, List<String> titles);

final applyAiBreakdownProvider = Provider<TaskBreakdownApplier>((ref) {
  return (task, titles) async {
    if (titles.isEmpty) return;
    await ref
        .read(taskRepositoryProvider)
        .replaceSubtasks(
          parentId: task.id,
          titles: [...task.subtasks.map((subtask) => subtask.title), ...titles],
        );
    await ref.read(inboxProvider.notifier).refresh();
    ref.invalidate(dailyTimelineProvider);
  };
});

Future<void> suggestTaskBreakdown({
  required BuildContext context,
  required WidgetRef ref,
  required TaskModel task,
}) async {
  final title = task.title.trim();
  if (title.isEmpty) return;
  if (task.subtasks.length >= TaskModel.userSubtaskLimit) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n('En fazla 30 alt görev ekleyebilirsin.')),
      ),
    );
    return;
  }
  if (!await requirePremiumAccess(context, ref, PremiumFeature.subtasks)) {
    return;
  }
  if (!context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Card(
          key: ValueKey('task-breakdown-loading'),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded),
                SizedBox(width: 12),
                Text(context.l10n('Küçük adımlar hazırlanıyor...')),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) return;

  var dialogOpen = true;
  void closeDialog() {
    if (!dialogOpen || !context.mounted) return;
    dialogOpen = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  try {
    final generated = await ref
        .read(taskBreakdownServiceProvider)
        .generateSubtasks(title);
    if (!context.mounted) return;
    final additions = selectAiSubtaskAdditions(
      generated: generated,
      existing: task.subtasks.map((subtask) => subtask.title),
    );
    closeDialog();
    if (additions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n('Uygun yeni adım bulunamadı.'))),
      );
      return;
    }
    await ref.read(applyAiBreakdownProvider)(task, additions);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          additions.length == 1
              ? ActiveLanguage.s('1 küçük adım eklendi.')
              : ActiveLanguage.s('{count} küçük adım eklendi.', {
                  'count': '${additions.length}',
                }),
        ),
      ),
    );
  } catch (error) {
    closeDialog();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  } finally {
    closeDialog();
  }
}
