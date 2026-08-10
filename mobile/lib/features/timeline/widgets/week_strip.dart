import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/liquid_glass.dart';
import 'package:florien/features/providers.dart';

class WeekStrip extends ConsumerWidget {
  const WeekStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekAsync = ref.watch(weeklyTimelineProvider);
    final selected = ref.watch(selectedDateProvider);
    final today = DateTime.now();
    final language = ref.watch(appLanguageProvider).valueOrNull ?? 'tr';
    final locale = dateLocaleFor(language);

    return weekAsync.when(
      loading: () => const SizedBox(
        height: 76,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (days) => SizedBox(
        height: 76,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
          itemCount: days.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final day = days[index];
            final isSelected = _sameDay(day.date, selected);
            final isToday = _sameDay(day.date, today);
            final completed = day.tasks.where((t) => t.isCompleted).length;
            final total = day.tasks.length;

            return GestureDetector(
              onTap: () {
                ref.read(selectedDateProvider.notifier).state = day.date;
                ref.invalidate(timelineProvider);
              },
              child: isSelected
                  ? AnimatedContainer(
                      duration:
                          (MediaQuery.maybeOf(context)?.disableAnimations ??
                              false)
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      width: 52,
                      decoration: BoxDecoration(
                        color: FlorienColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _DayPillContent(
                        day: day,
                        isSelected: true,
                        isToday: isToday,
                        completed: completed,
                        total: total,
                        locale: locale,
                      ),
                    )
                  : LiquidGlass(
                      blur: false,
                      borderRadius: BorderRadius.circular(16),
                      tintOpacity: 1,
                      borderWidth: 1,
                      child: SizedBox(
                        width: 52,
                        child: _DayPillContent(
                          day: day,
                          isSelected: false,
                          isToday: isToday,
                          completed: completed,
                          total: total,
                          locale: locale,
                        ),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayPillContent extends StatelessWidget {
  const _DayPillContent({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.completed,
    required this.total,
    required this.locale,
  });

  final TimelineModel day;
  final bool isSelected;
  final bool isToday;
  final int completed;
  final int total;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          DateFormat('EEE', locale).format(day.date).toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white70 : context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          DateFormat('d').format(day.date),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : context.palette.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        if (total > 0)
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              width: 24,
              height: 3,
              child: LinearProgressIndicator(
                value: completed / total,
                backgroundColor: isSelected
                    ? Colors.white30
                    : context.palette.border,
                valueColor: AlwaysStoppedAnimation(
                  isSelected ? Colors.white : FlorienColors.success,
                ),
              ),
            ),
          )
        else
          Container(
            width: isToday ? 4 : 18,
            height: isToday ? 4 : 3,
            decoration: BoxDecoration(
              color: isToday
                  ? (isSelected ? Colors.white : FlorienColors.primary)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
