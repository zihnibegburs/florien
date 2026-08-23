import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/achievement.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';

class AchievementSection extends ConsumerWidget {
  const AchievementSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(achievementProgressProvider);
    return progress.when(
      data: (value) => AchievementCollection(progress: value),
      loading: () => const SizedBox(
        height: 214,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: FlorienSpacing.screen),
        child: Container(
          padding: const EdgeInsets.all(FlorienSpacing.lg),
          decoration: BoxDecoration(
            color: context.palette.surfaceMuted,
            borderRadius: BorderRadius.circular(FlorienRadius.lg),
          ),
          child: const Text('Başarılar şu anda yüklenemiyor.'),
        ),
      ),
    );
  }
}

class AchievementCollection extends StatelessWidget {
  const AchievementCollection({super.key, required this.progress});

  final AchievementProgress progress;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final cardHeight = (202 + ((textScale - 1) * 64).clamp(0, 76)).toDouble();
    final cardWidth = (128 + ((textScale - 1) * 48).clamp(0, 56)).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FlorienSpacing.screen,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Başarılar',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: context.palette.selection,
                  borderRadius: BorderRadius.circular(FlorienRadius.pill),
                  border: Border.all(
                    color: context.palette.border,
                    width: FlorienBorders.thin,
                  ),
                ),
                child: Text(
                  '${progress.completedTaskCount} görev',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: FlorienColors.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: FlorienSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FlorienSpacing.screen,
          ),
          child: _NextAchievementCard(progress: progress),
        ),
        const SizedBox(height: FlorienSpacing.lg),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            key: const ValueKey('achievement-list'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: FlorienSpacing.screen,
            ),
            itemCount: progress.catalog.items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final achievement = progress.catalog.items[index];
              return _AchievementCard(
                achievement: achievement,
                unlocked: progress.isUnlocked(achievement),
                width: cardWidth,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NextAchievementCard extends StatelessWidget {
  const _NextAchievementCard({required this.progress});

  final AchievementProgress progress;

  @override
  Widget build(BuildContext context) {
    final next = progress.next;
    return Semantics(
      excludeSemantics: true,
      label: next == null
          ? 'Tüm başarılar açıldı. ${progress.completedTaskCount} görev tamamlandı.'
          : 'Sıradaki başarı ${next.name}. ${next.threshold} görev gerekiyor. '
                '${progress.remainingForNext} görev kaldı.',
      child: Container(
        padding: const EdgeInsets.all(FlorienSpacing.lg),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(FlorienRadius.lg),
          border: Border.all(
            color: context.palette.border,
            width: FlorienBorders.thin,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (next != null) ...[
                  Image.asset(
                    next.assetPath,
                    width: 48,
                    height: 48,
                    cacheWidth: 144,
                    cacheHeight: 144,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        next == null
                            ? 'Koleksiyon tamamlandı'
                            : 'Sıradaki rozet',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: context.palette.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        next?.name ?? 'Bütün başarılar açık',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                if (next != null)
                  Text(
                    '${progress.remainingForNext} kaldı',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(FlorienRadius.pill),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: progress.nextProgress,
                backgroundColor: context.palette.surfaceMuted,
                valueColor: const AlwaysStoppedAnimation(FlorienColors.mint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.achievement,
    required this.unlocked,
    required this.width,
  });

  final AchievementDefinition achievement;
  final bool unlocked;
  final double width;

  @override
  Widget build(BuildContext context) {
    final status = unlocked ? 'açıldı' : 'kilitli';
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${achievement.name}, ${achievement.threshold} görev, $status',
      child: Material(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(FlorienRadius.lg),
        child: InkWell(
          key: ValueKey('achievement-${achievement.id}'),
          onTap: () => showAchievementDetails(
            context,
            achievement: achievement,
            unlocked: unlocked,
          ),
          borderRadius: BorderRadius.circular(FlorienRadius.lg),
          child: Container(
            width: width,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FlorienRadius.lg),
              border: Border.all(
                color: context.palette.border,
                width: FlorienBorders.thin,
              ),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 86,
                  height: 86,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          achievement.assetPath,
                          cacheWidth: 258,
                          cacheHeight: 258,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: unlocked
                                ? FlorienColors.mint
                                : context.palette.surfaceMuted,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.palette.border,
                              width: FlorienBorders.thin,
                            ),
                          ),
                          child: Icon(
                            unlocked
                                ? Icons.check_rounded
                                : Icons.lock_outline_rounded,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    achievement.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.08,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      unlocked
                          ? Icons.check_circle_outline_rounded
                          : Icons.lock_outline_rounded,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${achievement.threshold} görev',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.palette.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showAchievementDetails(
  BuildContext context, {
  required AchievementDefinition achievement,
  required bool unlocked,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(achievement.name, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            achievement.assetPath,
            width: 160,
            height: 160,
            cacheWidth: 480,
            cacheHeight: 480,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                unlocked
                    ? Icons.check_circle_outline_rounded
                    : Icons.lock_outline_rounded,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  unlocked
                      ? '${achievement.threshold} görevle açıldı'
                      : '${achievement.threshold} görevde açılır',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Kapat'),
        ),
      ],
    ),
  );
}

Future<void> showAchievementCelebration(
  BuildContext context,
  AchievementDefinition achievement,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Kutlamayı kapat',
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: curved, child: child),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          key: const ValueKey('achievement-celebration'),
          width: 320,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(FlorienRadius.xl),
            border: Border.all(
              color: context.palette.border,
              width: FlorienBorders.medium,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Yeni başarı açıldı!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Image.asset(
                achievement.assetPath,
                width: 160,
                height: 160,
                cacheWidth: 480,
                cacheHeight: 480,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
              Text(
                achievement.name,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '${achievement.threshold} gerçek görev tamamladın.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Harika'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
