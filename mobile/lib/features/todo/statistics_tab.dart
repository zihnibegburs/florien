import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/settings_screen.dart';

/// Insights / statistics tab inspired by the reference layout.
class StatisticsTab extends ConsumerWidget {
  const StatisticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(completionCountsProvider);
    final authName = ref.watch(
      authStateProvider.select((value) => value.valueOrNull?.firstName),
    );
    final profileName = ref.watch(activeAppProfileProvider)?.name;
    final name = profileName?.isNotEmpty == true
        ? profileName!
        : (authName == null || authName.isEmpty ? 'Florien' : authName);
    final today = counts.valueOrNull?.today ?? 0;
    final week = counts.valueOrNull?.thisWeek ?? 0;
    final streak = week.clamp(0, 7);
    final completedGoal = 30;
    final completed = week.clamp(0, completedGoal);

    return ColoredBox(
      color: context.palette.background,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          key: const ValueKey('statistics-scroll'),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  FlorienSpacing.screen,
                  FlorienSpacing.md,
                  FlorienSpacing.screen,
                  0,
                ),
                child: _StatsHeader(name: name),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: FlorienSpacing.xxl),
            ),
            const SliverToBoxAdapter(child: _BadgeCarousel()),
            const SliverToBoxAdapter(
              child: SizedBox(height: FlorienSpacing.xxl),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FlorienSpacing.screen,
                ),
                child: _StatsSummaryCard(
                  streak: streak,
                  completed: completed,
                  completedGoal: completedGoal,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: FlorienSpacing.xxxl),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: FlorienSpacing.screen,
                ),
                child: _MoodSection(),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: FlorienSpacing.xxxl),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: FlorienSpacing.huge),
                child: _TipsSection(todayCompleted: today),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(FlorienRadius.pill),
            border: Border.all(
              color: context.palette.border,
              width: FlorienBorders.thin,
            ),
          ),
          child: Text(
            name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const Spacer(),
        _RoundHeaderButton(
          tooltip: 'Paylaş',
          icon: Icons.ios_share_rounded,
          onPressed: () {},
        ),
        const SizedBox(width: 10),
        _RoundHeaderButton(
          tooltip: 'Ayarlar',
          icon: Icons.settings_outlined,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            );
          },
        ),
      ],
    );
  }
}

class _RoundHeaderButton extends StatelessWidget {
  const _RoundHeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: context.palette.surface,
        shape: CircleBorder(
          side: BorderSide(
            color: context.palette.border,
            width: FlorienBorders.thin,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(dimension: 44, child: Icon(icon, size: 20)),
        ),
      ),
    );
  }
}

class _BadgeCarousel extends StatelessWidget {
  const _BadgeCarousel();

  static const _badges = [
    _BadgeData('Odak', Icons.timelapse_rounded, FlorienColors.accent, 8),
    _BadgeData('Akış', Icons.auto_awesome_rounded, FlorienColors.paleBlue, 11),
    _BadgeData(
      'Radiance',
      Icons.local_florist_rounded,
      FlorienColors.softPink,
      14,
    ),
    _BadgeData('Ritim', Icons.bolt_rounded, FlorienColors.primary, 9),
    _BadgeData('Denge', Icons.spa_rounded, FlorienColors.mint, 6),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: FlorienSpacing.screen),
        itemCount: _badges.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final badge = _badges[index];
          final featured = index == 2;
          return _BadgeOrb(badge: badge, featured: featured);
        },
      ),
    );
  }
}

class _BadgeData {
  const _BadgeData(this.title, this.icon, this.color, this.tasks);

  final String title;
  final IconData icon;
  final Color color;
  final int tasks;
}

class _BadgeOrb extends StatelessWidget {
  const _BadgeOrb({required this.badge, required this.featured});

  final _BadgeData badge;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final size = featured ? 88.0 : 64.0;
    return SizedBox(
      width: featured ? 108 : 84,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  badge.color,
                  Color.lerp(badge.color, FlorienColors.aiAccent, 0.35)!,
                ],
              ),
              border: Border.all(
                color: context.palette.border,
                width: featured ? FlorienBorders.medium : FlorienBorders.thin,
              ),
            ),
            child: Icon(
              badge.icon,
              size: featured ? 36 : 26,
              color: FlorienColors.onPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            badge.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            '${badge.tasks} görev',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSummaryCard extends StatelessWidget {
  const _StatsSummaryCard({
    required this.streak,
    required this.completed,
    required this.completedGoal,
  });

  final int streak;
  final int completed;
  final int completedGoal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(FlorienRadius.xxl),
        border: Border.all(
          color: context.palette.border,
          width: FlorienBorders.thin,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatColumn(
                value: '$streak',
                label: 'GÜN SERİSİ',
                progressLabel: '$streak/7 günler',
                progress: streak / 7,
                accent: FlorienColors.accent,
                icon: Icons.local_fire_department_rounded,
              ),
            ),
            VerticalDivider(
              width: 28,
              thickness: FlorienBorders.thin,
              color: context.palette.border.withValues(alpha: 0.35),
            ),
            Expanded(
              child: _StatColumn(
                value: '$completed',
                label: 'TAMAMLANDI',
                progressLabel: '$completed/$completedGoal görevler',
                progress: completed / completedGoal,
                accent: FlorienColors.mint,
                icon: Icons.check_circle_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.value,
    required this.label,
    required this.progressLabel,
    required this.progress,
    required this.accent,
    required this.icon,
  });

  final String value;
  final String label;
  final String progressLabel;
  final double progress;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(
              color: context.palette.border,
              width: FlorienBorders.thin,
            ),
          ),
          child: Icon(icon, color: FlorienColors.onPrimary),
        ),
        const SizedBox(height: 14),
        Text(
          value,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(FlorienRadius.pill),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: context.palette.surfaceMuted,
            color: accent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          progressLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: context.palette.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MoodSection extends StatelessWidget {
  const _MoodSection();

  static const _days = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];

  @override
  Widget build(BuildContext context) {
    final selected = DateTime.now().weekday - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ruh Hali ve Günlük Yansımalar',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: FlorienSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < _days.length; i++)
              _MoodDayButton(label: _days[i], selected: i == selected),
          ],
        ),
      ],
    );
  }
}

class _MoodDayButton extends StatelessWidget {
  const _MoodDayButton({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: selected ? FlorienColors.primary : context.palette.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: context.palette.border,
              width: FlorienBorders.thin,
            ),
          ),
          child: Icon(
            Icons.add_rounded,
            size: 20,
            color: selected
                ? FlorienColors.onPrimary
                : context.palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _TipsSection extends StatelessWidget {
  const _TipsSection({required this.todayCompleted});

  final int todayCompleted;

  static const _tips = [
    (
      'WEB ÜZERİNDE PLAN YAPIN',
      Icons.laptop_mac_rounded,
      FlorienColors.paleBlue,
    ),
    (
      'KOLAYCA PLANLAYIN',
      Icons.edit_calendar_rounded,
      FlorienColors.aiLavender,
    ),
    ('ODAKLANARAK İLERLEYİN', Icons.timer_outlined, FlorienColors.mint),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FlorienSpacing.screen,
          ),
          child: Text(
            'Bir Profesyonel Gibi Plan Yapın',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
        if (todayCompleted > 0) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FlorienSpacing.screen,
            ),
            child: Text(
              'Bugün $todayCompleted görev tamamladınız',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
        ],
        const SizedBox(height: FlorienSpacing.lg),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: FlorienSpacing.screen,
            ),
            itemCount: _tips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final tip = _tips[index];
              return _TipCard(title: tip.$1, icon: tip.$2, accent: tip.$3);
            },
          ),
        ),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.title,
    required this.icon,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(FlorienRadius.xl),
                border: Border.all(
                  color: context.palette.border,
                  width: FlorienBorders.thin,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(icon, size: 42, color: FlorienColors.onPrimary),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: context.palette.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.palette.border,
                          width: FlorienBorders.thin,
                        ),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
