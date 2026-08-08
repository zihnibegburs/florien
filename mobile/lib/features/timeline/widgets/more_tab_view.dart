import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mimio/core/l10n/app_strings.dart';
import 'package:mimio/core/models/achievement.dart';
import 'package:mimio/core/theme/mimio_theme.dart';
import 'package:mimio/features/achievements/achievements_screen.dart';
import 'package:mimio/features/web/weekly_view.dart';

class MoreTabView extends ConsumerWidget {
  const MoreTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final palette = context.palette;
    final stats =
        ref.watch(achievementStatsProvider).valueOrNull ??
        const AchievementStats();
    final unlockedCount = achievementDefinitions
        .where((a) => a.isUnlocked(stats))
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        Text(
          s.week,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          s.weeklyPlanSummary,
          style: TextStyle(fontSize: 13, color: palette.textSecondary),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 420,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              child: WeeklyView(),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          s.more,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _MoreTile(
          icon: Icons.emoji_events_rounded,
          title: s.achievementsTitle,
          subtitle: '$unlockedCount/${achievementDefinitions.length}',
          onTap: () => context.push('/achievements'),
        ),
        _MoreTile(
          icon: Icons.insights_rounded,
          title: s.weeklyRetro,
          onTap: () => context.push('/weekly-retro'),
        ),
        _MoreTile(
          icon: Icons.calendar_month_rounded,
          title: s.calendarImport,
          subtitle: s.calendarImportSubtitle,
          onTap: () => context.push('/calendar-import'),
        ),
        _MoreTile(
          icon: Icons.person_outline_rounded,
          title: s.profile,
          onTap: () => context.push('/profile'),
        ),
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: MimioColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null
            ? Text(subtitle!, style: const TextStyle(fontSize: 12))
            : null,
        trailing: const Icon(Icons.chevron_right_rounded),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: palette.surface,
        onTap: onTap,
      ),
    );
  }
}
