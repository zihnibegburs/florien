import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/utils/task_icons.dart';
import 'package:florien/core/theme/florien_theme.dart';

class TimelineHourGrid extends ConsumerWidget {
  const TimelineHourGrid({
    super.key,
    required this.tasks,
    this.onTaskTap,
  });

  final List<TaskModel> tasks;
  final void Function(TaskModel task)? onTaskTap;

  static const int _startHour = 6;
  static const int _endHour = 23;
  static const double _hourHeight = 64;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final totalHours = _endHour - _startHour + 1;
    final gridHeight = totalHours * _hourHeight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            height: gridHeight,
            child: Column(
              children: List.generate(totalHours, (i) {
                final hour = _startHour + i;
                return SizedBox(
                  height: _hourHeight,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8, top: 2),
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.palette.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: gridHeight,
              child: Stack(
                children: [
                  ...List.generate(totalHours, (i) {
                    return Positioned(
                      top: i * _hourHeight,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: _hourHeight,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                      ),
                    );
                  }),
                  ...tasks.map((task) => _TaskBlock(
                        task: task,
                        s: s,
                        onTap: () => onTaskTap?.call(task),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskBlock extends StatelessWidget {
  const _TaskBlock({required this.task, required this.s, this.onTap});

  final TaskModel task;
  final S s;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (task.scheduledAt == null) return const SizedBox.shrink();

    final local = task.scheduledAt!.toLocal();
    final startMinutes = (local.hour - TimelineHourGrid._startHour) * 60 + local.minute;
    if (local.hour < TimelineHourGrid._startHour || local.hour > TimelineHourGrid._endHour) {
      return const SizedBox.shrink();
    }

    final top = (startMinutes / 60) * TimelineHourGrid._hourHeight;
    final height = (task.durationMinutes / 60) * TimelineHourGrid._hourHeight;
    final color = FlorienColors.fromHex(task.color);
    final timeFormat = DateFormat('HH:mm');

    return Positioned(
      top: top.clamp(0, double.infinity),
      left: 4,
      right: 4,
      height: height.clamp(28, double.infinity),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: task.isCompleted ? 0.35 : 0.85),
            borderRadius: BorderRadius.circular(12),
            border: task.isActive ? Border.all(color: color, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                TaskIcons.iconForTask(title: task.title, icon: task.icon),
                color: Colors.white.withValues(alpha: 0.9),
                size: 14,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: task.isCompleted ? Colors.white70 : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (height > 40)
                      Text(
                        task.hasSubtasks
                            ? '${s.stepsCount(task.subtasks.length)} · ${s.minutesShort(task.durationMinutes)}'
                            : '${timeFormat.format(local)} · ${s.minutesShort(task.durationMinutes)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
