import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';

class WeeklyRetrospectiveScreen extends ConsumerWidget {
  const WeeklyRetrospectiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekAsync = ref.watch(weeklyTimelineProvider);
    final s = ref.watch(stringsProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(s.weeklyRetro),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: weekAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(s.weeklyLoadError(e))),
        data: (days) {
          var totalTasks = 0;
          var completed = 0;
          var perfectDays = 0;
          final hourCounts = List<int>.filled(24, 0);

          for (final day in days) {
            totalTasks += day.tasks.length;
            final dayCompleted = day.tasks.where((t) => t.isCompleted).length;
            completed += dayCompleted;
            if (day.tasks.isNotEmpty && dayCompleted == day.tasks.length) perfectDays++;
            for (final task in day.tasks.where((t) => t.isCompleted && t.scheduledAt != null)) {
              hourCounts[task.scheduledAt!.hour]++;
            }
          }

          final peakHour = hourCounts.indexOf(hourCounts.reduce((a, b) => a > b ? a : b));
          final peak = peakHour >= 0 ? '${peakHour.toString().padLeft(2, '0')}:00' : '—';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [FlorienColors.primary.withValues(alpha: 0.15), FlorienColors.primaryLight.withValues(alpha: 0.1)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  s.weeklyRetroSummary(completed, perfectDays, peak),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.5),
                ),
              ),
              const SizedBox(height: 20),
              ...days.map((day) => _DaySummary(day: day)),
            ],
          );
        },
      ),
    );
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.day});

  final TimelineModel day;

  @override
  Widget build(BuildContext context) {
    final completed = day.tasks.where((t) => t.isCompleted).length;
    return ListTile(
      title: Text('${day.date.day}/${day.date.month}', style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Text('$completed/${day.tasks.length}'),
    );
  }
}
