import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/achievement.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/storage/achievement_progress_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/achievement_collection.dart';

const _confettiDuration = Duration(milliseconds: 1050);

/// Keeps normal task completion on the current page. An achievement dialog is
/// only shown when this exact completion reaches a new achievement threshold.
Future<void> showTaskCompletionFeedback(
  BuildContext context,
  WidgetRef ref,
  CompletionCounts counts,
) async {
  final feedbackContext =
      Navigator.maybeOf(context, rootNavigator: true)?.context ?? context;
  AchievementProgressStorage? storage;
  String? profileScope;
  ProviderContainer? container;
  final Future<AchievementDefinition?> achievementFuture;
  if (counts.total > 0) {
    final currentProfileScope = ref.read(activeProfileScopeProvider);
    final currentStorage = ref.read(achievementProgressStorageProvider);
    profileScope = currentProfileScope;
    storage = currentStorage;
    container = ProviderScope.containerOf(context, listen: false);
    achievementFuture = _newAchievementForCompletion(
      catalogFuture: ref.read(achievementCatalogProvider.future),
      storage: currentStorage,
      profileScope: currentProfileScope,
      completedTaskCount: counts.total,
    );
  } else {
    achievementFuture = Future.value(null);
  }
  await _showCompletionConfetti(context);

  final achievement = await achievementFuture;
  if (!feedbackContext.mounted || achievement == null) return;

  await showAchievementCelebration(feedbackContext, achievement);
  await storage!.markCelebrated(
    profileScope: profileScope!,
    threshold: achievement.threshold,
  );
  container!.invalidate(achievementProgressProvider);
}

Future<AchievementDefinition?> _newAchievementForCompletion({
  required Future<AchievementCatalog> catalogFuture,
  required AchievementProgressStorage storage,
  required String profileScope,
  required int completedTaskCount,
}) async {
  if (completedTaskCount <= 0) return null;
  try {
    final catalog = await catalogFuture;
    final matching = catalog.items
        .where((item) => item.threshold == completedTaskCount)
        .firstOrNull;
    if (matching == null) return null;

    final celebrated = await storage.loadCelebratedThreshold(profileScope);
    return celebrated < matching.threshold ? matching : null;
  } catch (error) {
    // Task completion must remain successful if achievement data is unavailable.
    debugPrint('Achievement completion feedback could not be loaded: $error');
    return null;
  }
}

Future<void> _showCompletionConfetti(BuildContext context) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final controller = ConfettiController(duration: _confettiDuration);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: SizedBox(
            key: const ValueKey('task-completion-confetti'),
            width: 1,
            height: 1,
            child: ConfettiWidget(
              confettiController: controller,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: .07,
              numberOfParticles: 18,
              minBlastForce: 8,
              maxBlastForce: 22,
              gravity: .16,
              colors: const [
                FlorienColors.primary,
                FlorienColors.accent,
                FlorienColors.mint,
                FlorienColors.paleBlue,
                FlorienColors.softPink,
                FlorienColors.aiAccent,
              ],
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  controller.play();
  await Future<void>.delayed(
    _confettiDuration + const Duration(milliseconds: 250),
  );
  entry.remove();
  controller.dispose();
}
