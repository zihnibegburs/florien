import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mimio/core/firebase/user_profile_service.dart';
import 'package:mimio/core/l10n/app_strings.dart';
import 'package:mimio/core/models/achievement.dart';
import 'package:mimio/core/storage/achievement_storage.dart';
import 'package:mimio/core/theme/mimio_theme.dart';
import 'package:mimio/features/providers.dart';

final achievementStatsProvider =
    AsyncNotifierProvider<AchievementStatsNotifier, AchievementStats>(AchievementStatsNotifier.new);

class AchievementStatsNotifier extends AsyncNotifier<AchievementStats> {
  String? get _userId => ref.read(authStateProvider).valueOrNull?.userId;

  @override
  Future<AchievementStats> build() async {
    final userId = ref.watch(authStateProvider.select((auth) => auth.valueOrNull?.userId));
    if (userId == null) return const AchievementStats();
    return ref.read(achievementStorageProvider).load(userId);
  }

  Future<void> recordTaskCompleted({required DateTime completedAt}) async {
    final userId = _userId;
    if (userId == null) return;
    final storage = ref.read(achievementStorageProvider);
    final current = state.valueOrNull ?? await storage.load(userId);
    final updated = storage.recordTaskCompleted(current, completedAt: completedAt);
    await storage.save(userId, updated);
    state = AsyncData(updated);
    try {
      await ref.read(userProfileServiceProvider).patchSettings(userId, {
        'achievements': updated.toJson(),
      });
    } catch (_) {}
  }
}

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(achievementStatsProvider);
    final s = ref.watch(stringsProvider);

    final body = statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (stats) => _AchievementsBody(stats: stats, strings: s),
    );

    if (embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(s.achievementsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: body,
    );
  }
}

class _AchievementsBody extends StatelessWidget {
  const _AchievementsBody({required this.stats, required this.strings});

  final AchievementStats stats;
  final S strings;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievementDefinitions.where((a) => a.isUnlocked(stats)).length;
    final total = achievementDefinitions.length;
    final progress = total == 0 ? 0.0 : unlocked / total;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MimioColors.primary.withValues(alpha: 0.16),
                    MimioColors.primaryLight.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: MimioColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 6,
                          backgroundColor: MimioColors.primary.withValues(alpha: 0.15),
                          color: MimioColors.primary,
                        ),
                        const Icon(Icons.emoji_events_rounded, color: MimioColors.primary, size: 28),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.achievementsUnlocked(unlocked, total),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          strings.achievementsSubtitle,
                          style: TextStyle(color: context.palette.textSecondary, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: strings.achievementsStatWeekly,
                    value: '${stats.tasksCompletedThisWeek}',
                    icon: Icons.calendar_view_week_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: strings.achievementsStatAllTime,
                    value: '${stats.tasksCompleted}',
                    icon: Icons.task_alt_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Text(
              strings.achievementsWeekly,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        _AchievementGridSliver(definitions: weeklyAchievementDefinitions, stats: stats, strings: strings),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Text(
              strings.achievementsAllTime,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        _AchievementGridSliver(definitions: allTimeAchievementDefinitions, stats: stats, strings: strings),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }
}

class _AchievementGridSliver extends StatelessWidget {
  const _AchievementGridSliver({
    required this.definitions,
    required this.stats,
    required this.strings,
  });

  final List<AchievementDefinition> definitions;
  final AchievementStats stats;
  final S strings;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final achievement = definitions[index];
            return _AchievementCard(achievement: achievement, stats: stats, strings: strings);
          },
          childCount: definitions.length,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: MimioColors.primary),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: context.palette.textSecondary, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.achievement,
    required this.stats,
    required this.strings,
  });

  final AchievementDefinition achievement;
  final AchievementStats stats;
  final S strings;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.isUnlocked(stats);
    final progress = achievement.progress(stats);
    final current = achievement.progressOf(stats);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked ? achievement.color.withValues(alpha: 0.45) : context.palette.border,
          width: unlocked ? 1.5 : 1,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: achievement.color.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: unlocked
                      ? achievement.color.withValues(alpha: 0.18)
                      : context.palette.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  achievement.icon,
                  color: unlocked ? achievement.color : context.palette.textSecondary.withValues(alpha: 0.5),
                  size: 22,
                ),
              ),
              const Spacer(),
              if (unlocked)
                Icon(Icons.check_circle_rounded, color: achievement.color, size: 22)
              else
                Text(
                  '$current/${achievement.target}',
                  style: TextStyle(fontSize: 12, color: context.palette.textSecondary, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            strings.achievementTitle(achievement),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: unlocked ? context.palette.textPrimary : context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              strings.achievementDescription(achievement),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: unlocked ? context.palette.textSecondary : context.palette.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ),
          if (!unlocked) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: MimioColors.primary.withValues(alpha: 0.1),
                color: achievement.color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
