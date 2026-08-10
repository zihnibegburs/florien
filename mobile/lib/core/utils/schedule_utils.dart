import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/models/models.dart';

class ScheduleConflict {
  const ScheduleConflict({
    required this.taskA,
    required this.taskB,
    required this.overlapMinutes,
    required this.isTight,
  });

  final TaskModel taskA;
  final TaskModel taskB;
  final int overlapMinutes;
  final bool isTight;
}

List<ScheduleConflict> detectScheduleConflicts(List<TaskModel> tasks) {
  final scheduled = tasks
      .where((t) => t.scheduledAt != null && !t.isCompleted && t.parentTaskId == null)
      .toList()
    ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

  final conflicts = <ScheduleConflict>[];
  for (var i = 0; i < scheduled.length; i++) {
    for (var j = i + 1; j < scheduled.length; j++) {
      final a = scheduled[i];
      final b = scheduled[j];
      final aStart = a.scheduledAt!;
      final aEnd = a.endTime;
      final bStart = b.scheduledAt!;
      final bEnd = b.endTime;

      if (bStart.isAfter(aEnd) && bStart.difference(aEnd).inMinutes > 5) break;

      if (bStart.isBefore(aEnd)) {
        final overlapEnd = bEnd.isBefore(aEnd) ? bEnd : aEnd;
        final overlap = overlapEnd.difference(bStart).inMinutes;
        if (overlap > 0) {
          conflicts.add(ScheduleConflict(
            taskA: a,
            taskB: b,
            overlapMinutes: overlap,
            isTight: false,
          ));
        }
      } else {
        final gap = bStart.difference(aEnd).inMinutes;
        if (gap >= 0 && gap < 5) {
          conflicts.add(ScheduleConflict(
            taskA: a,
            taskB: b,
            overlapMinutes: 0,
            isTight: true,
          ));
        }
      }
    }
  }
  return conflicts;
}

TaskModel? currentTask(List<TaskModel> tasks, DateTime now) {
  for (final task in tasks) {
    if (task.isCompleted || task.scheduledAt == null) continue;
    final start = task.scheduledAt!;
    final end = task.endTime;
    if (!now.isBefore(start) && now.isBefore(end)) return task;
  }
  return null;
}

TaskModel? nextTask(List<TaskModel> tasks, DateTime now, {String? excludeId}) {
  final upcoming = tasks
      .where((t) =>
          !t.isCompleted &&
          t.scheduledAt != null &&
          t.scheduledAt!.isAfter(now) &&
          t.id != excludeId &&
          t.parentTaskId == null)
      .toList()
    ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
  return upcoming.isEmpty ? null : upcoming.first;
}

List<TaskModel> filterByEnergy(List<TaskModel> tasks, EnergyLevel? dailyEnergy) {
  if (dailyEnergy == null) return tasks;
  final matching = tasks.where((t) => t.energyLevel == null || t.energyLevel == dailyEnergy).toList();
  return matching.isEmpty ? tasks : matching;
}
