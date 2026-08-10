import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/timeline/home_tab.dart';

/// Tam haftalık görünüm — mobilde liste, webde kompakt satır.
class WeeklyView extends ConsumerWidget {
  const WeeklyView({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekAsync = ref.watch(weeklyTimelineProvider);
    final selected = ref.watch(selectedDateProvider);
    final s = ref.watch(stringsProvider);

    return weekAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(s.weeklyLoadError(e))),
      data: (days) {
        if (compact) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: days.map((day) {
              return Expanded(
                child: _DayColumn(
                  day: day,
                  isSelected: _isSameDay(day.date, selected),
                  onTap: () => _selectDay(ref, day.date),
                ),
              );
            }).toList(),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: days.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final day = days[index];
            return _DayColumn(
              day: day,
              isSelected: _isSameDay(day.date, selected),
              onTap: () {
                _selectDay(ref, day.date);
                ref.read(homeTabProvider.notifier).state = HomeTab.today;
              },
              expanded: true,
            );
          },
        );
      },
    );
  }

  void _selectDay(WidgetRef ref, DateTime date) {
    ref.read(selectedDateProvider.notifier).state = date;
    ref.invalidate(timelineProvider);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.isSelected,
    required this.onTap,
    this.expanded = false,
  });

  final TimelineModel day;
  final bool isSelected;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('EEEE', 'tr_TR').format(day.date);
    final dayNum = DateFormat('d MMMM', 'tr_TR').format(day.date);
    final completed = day.tasks.where((t) => t.isCompleted).length;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: expanded ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.all(expanded ? 16 : 12),
        decoration: BoxDecoration(
          color: isSelected ? FlorienColors.primary.withValues(alpha: 0.06) : context.palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? FlorienColors.primary : context.palette.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayName,
                        style: TextStyle(
                          fontSize: expanded ? 16 : 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? FlorienColors.primary : context.palette.textSecondary,
                        ),
                      ),
                      Text(
                        dayNum,
                        style: TextStyle(
                          fontSize: expanded ? 14 : 22,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? FlorienColors.primary : context.palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (day.tasks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: FlorienColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$completed/${day.tasks.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: FlorienColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            if (expanded) const SizedBox(height: 12),
            ...day.tasks.take(expanded ? 8 : 4).map((task) {
              final color = FlorienColors.fromHex(task.color);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: task.isCompleted ? context.palette.textSecondary : context.palette.textPrimary,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (task.scheduledAt != null)
                      Text(
                        DateFormat('HH:mm').format(task.scheduledAt!.toLocal()),
                        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              );
            }),
            if (day.tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Plan yok', style: TextStyle(color: context.palette.textSecondary, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }
}
