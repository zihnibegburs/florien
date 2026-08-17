import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/mood_entry.dart';
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
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: FlorienSpacing.screen,
                ),
                child: _MoodSection(),
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

class _MoodSection extends ConsumerWidget {
  const _MoodSection();

  static const _days = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final weekStart = _weekStart(now);
    final entries = ref.watch(moodEntriesProvider).valueOrNull ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Ruh Hali ve Günlük Yansımalar',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _connectAppleHealth(context, ref),
              icon: const Icon(Icons.health_and_safety_outlined, size: 18),
              label: const Text('Apple Sağlık'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Bu haftanın her günü için nasıl hissettiğini seç.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary),
        ),
        const SizedBox(height: FlorienSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < _days.length; i++)
              _MoodDayButton(
                label: _days[i],
                date: weekStart.add(Duration(days: i)),
                entry: _entryForDay(entries, weekStart.add(Duration(days: i))),
                isToday: _sameDay(now, weekStart.add(Duration(days: i))),
                onTap: () => _editMood(
                  context,
                  ref,
                  weekStart.add(Duration(days: i)),
                  _entryForDay(entries, weekStart.add(Duration(days: i))),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _connectAppleHealth(BuildContext context, WidgetRef ref) async {
    final connected = await ref
        .read(moodEntriesProvider.notifier)
        .connectAppleHealth();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          connected
              ? 'Apple Sağlık bağlandı. Bu haftanın ruh halleri eşitlendi.'
              : 'Apple Sağlık izni verilmedi veya bu iPhone desteklenmiyor.',
        ),
      ),
    );
  }

  Future<void> _editMood(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    MoodEntry? entry,
  ) async {
    final updated = await showModalBottomSheet<MoodEntry>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MoodEntrySheet(date: date, entry: entry),
    );
    if (updated != null) {
      await ref.read(moodEntriesProvider.notifier).saveEntry(updated);
    }
  }
}

class _MoodDayButton extends StatelessWidget {
  const _MoodDayButton({
    required this.label,
    required this.date,
    required this.entry,
    required this.isToday,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final MoodEntry? entry;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mood = entry?.mood;
    final color = _moodColor(mood, context);
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
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            key: ValueKey('mood-day-${date.year}-${date.month}-${date.day}'),
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: mood == null ? context.palette.surface : color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isToday
                      ? FlorienColors.primary
                      : context.palette.border,
                  width: isToday ? FlorienBorders.medium : FlorienBorders.thin,
                ),
              ),
              child: Center(
                child: Text(
                  mood?.emoji ?? '+',
                  style: TextStyle(
                    fontSize: mood == null ? 22 : 19,
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MoodEntrySheet extends StatefulWidget {
  const _MoodEntrySheet({required this.date, required this.entry});

  final DateTime date;
  final MoodEntry? entry;

  @override
  State<_MoodEntrySheet> createState() => _MoodEntrySheetState();
}

class _MoodEntrySheetState extends State<_MoodEntrySheet> {
  late MoodLevel _mood = widget.entry?.mood ?? MoodLevel.neutral;
  late final TextEditingController _reflection = TextEditingController(
    text: widget.entry?.reflection ?? '',
  );

  @override
  void dispose() {
    _reflection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.palette.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '${widget.date.day}.${widget.date.month} için nasılsın?',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mood in MoodLevel.values)
                ChoiceChip(
                  label: Text('${mood.emoji} ${mood.label}'),
                  selected: _mood == mood,
                  selectedColor: _moodColor(mood, context),
                  onSelected: (_) => setState(() => _mood = mood),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('mood-reflection-input'),
            controller: _reflection,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Bugünle ilgili kısa bir yansıma ekle (isteğe bağlı)',
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                MoodEntry(
                  date: widget.date,
                  mood: _mood,
                  reflection: _reflection.text.trim(),
                ),
              ),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Ruh halini kaydet'),
            ),
          ),
        ],
      ),
    ),
  );
}

MoodEntry? _entryForDay(List<MoodEntry> entries, DateTime date) {
  for (final entry in entries) {
    if (_sameDay(entry.date, date)) return entry;
  }
  return null;
}

DateTime _weekStart(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

Color _moodColor(MoodLevel? mood, BuildContext context) => switch (mood) {
  MoodLevel.veryLow => FlorienColors.softPink,
  MoodLevel.low => FlorienColors.warning,
  MoodLevel.neutral => context.palette.surfaceMuted,
  MoodLevel.good => FlorienColors.mint,
  MoodLevel.veryGood => FlorienColors.primary,
  null => context.palette.surface,
};
