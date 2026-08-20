import 'package:florien/core/models/models.dart';

class TaskUsageCandidate {
  const TaskUsageCandidate({required this.task, required this.createdAt});

  final TaskModel task;
  final DateTime createdAt;
}

class TaskUsageSummary {
  const TaskUsageSummary({
    required this.task,
    required this.usageCount,
    required this.lastCreatedAt,
  });

  final TaskModel task;
  final int usageCount;
  final DateTime lastCreatedAt;
}

List<TaskUsageSummary> rankFrequentlyUsedTasks(
  Iterable<TaskUsageCandidate> candidates, {
  int limit = 10,
}) {
  final groups = <String, _TaskUsageGroup>{};
  for (final candidate in candidates) {
    if (candidate.task.parentTaskId != null) continue;
    final key = normalizeTaskUsageTitle(candidate.task.title);
    if (key.isEmpty) continue;
    final group = groups[key];
    if (group == null) {
      groups[key] = _TaskUsageGroup(
        task: candidate.task,
        usageCount: 1,
        lastCreatedAt: candidate.createdAt,
      );
      continue;
    }
    group.usageCount++;
    if (candidate.createdAt.isAfter(group.lastCreatedAt)) {
      group
        ..task = candidate.task
        ..lastCreatedAt = candidate.createdAt;
    }
  }

  final ranked =
      groups.values
          .map(
            (group) => TaskUsageSummary(
              task: group.task,
              usageCount: group.usageCount,
              lastCreatedAt: group.lastCreatedAt,
            ),
          )
          .toList()
        ..sort((first, second) {
          final byUsage = second.usageCount.compareTo(first.usageCount);
          if (byUsage != 0) return byUsage;
          return second.lastCreatedAt.compareTo(first.lastCreatedAt);
        });
  return ranked.take(limit).toList(growable: false);
}

String normalizeTaskUsageTitle(String value) => value
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll('İ', 'i')
    .replaceAll('I', 'ı')
    .toLowerCase();

class _TaskUsageGroup {
  _TaskUsageGroup({
    required this.task,
    required this.usageCount,
    required this.lastCreatedAt,
  });

  TaskModel task;
  int usageCount;
  DateTime lastCreatedAt;
}
