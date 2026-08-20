import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/achievement.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/storage/achievement_progress_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/achievement_collection.dart';

const _bubbleDuration = Duration(milliseconds: 1150);

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
  await _showCompletionBubbles(context);

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

Future<void> _showCompletionBubbles(BuildContext context) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned.fill(
      child: IgnorePointer(
        child: _TaskCompletionBubbles(
          key: const ValueKey('task-completion-bubbles'),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  await Future<void>.delayed(
    _bubbleDuration + const Duration(milliseconds: 120),
  );
  entry.remove();
}

class _TaskCompletionBubbles extends StatefulWidget {
  const _TaskCompletionBubbles({super.key});

  @override
  State<_TaskCompletionBubbles> createState() => _TaskCompletionBubblesState();
}

class _TaskCompletionBubblesState extends State<_TaskCompletionBubbles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _bubbleDuration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _PastelBubblePainter(_controller),
      child: const SizedBox.expand(),
    ),
  );
}

class _PastelBubblePainter extends CustomPainter {
  _PastelBubblePainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  static const _colors = [
    FlorienColors.primaryLight,
    FlorienColors.accent,
    FlorienColors.mint,
    FlorienColors.paleBlue,
    FlorienColors.softPink,
    FlorienColors.aiLavender,
    FlorienColors.softLime,
  ];

  static const _bubbles = [
    _BubbleSpec(-118, 18, -38, 176, 17, 0.00),
    _BubbleSpec(-82, 42, 30, 245, 11, 0.05),
    _BubbleSpec(-48, 0, -22, 212, 23, 0.12),
    _BubbleSpec(-14, 38, 20, 278, 14, 0.02),
    _BubbleSpec(20, 10, -18, 232, 19, 0.16),
    _BubbleSpec(54, 46, 35, 196, 12, 0.08),
    _BubbleSpec(90, 4, -28, 264, 21, 0.20),
    _BubbleSpec(122, 34, 18, 218, 15, 0.10),
    _BubbleSpec(-142, 72, 42, 205, 10, 0.22),
    _BubbleSpec(-102, 86, -18, 286, 14, 0.18),
    _BubbleSpec(-58, 70, 34, 238, 9, 0.27),
    _BubbleSpec(-8, 92, -32, 222, 18, 0.14),
    _BubbleSpec(42, 76, 24, 290, 10, 0.24),
    _BubbleSpec(78, 94, -38, 244, 16, 0.19),
    _BubbleSpec(132, 74, 26, 184, 11, 0.29),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    final origin = Offset(size.width / 2, size.height * .64);
    for (var index = 0; index < _bubbles.length; index++) {
      final bubble = _bubbles[index];
      final localProgress = ((progress - bubble.delay) / (1 - bubble.delay))
          .clamp(0.0, 1.0);
      if (localProgress <= 0 || localProgress >= 1) continue;

      final rise = Curves.easeOutCubic.transform(localProgress);
      final drift = Curves.easeInOutSine.transform(localProgress);
      final opacity = math.sin(math.pi * localProgress) * .46;
      final center = Offset(
        origin.dx + bubble.startX + (bubble.driftX * drift),
        origin.dy + bubble.startY - (bubble.rise * rise),
      );
      final radius = bubble.radius * (.82 + localProgress * .18);
      final color = _colors[index % _colors.length];

      canvas.drawCircle(
        center,
        radius,
        Paint()..color = color.withValues(alpha: opacity),
      );
      canvas.drawCircle(
        center.translate(-radius * .28, -radius * .3),
        radius * .24,
        Paint()..color = Colors.white.withValues(alpha: opacity * .42),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PastelBubblePainter oldDelegate) => false;
}

class _BubbleSpec {
  const _BubbleSpec(
    this.startX,
    this.startY,
    this.driftX,
    this.rise,
    this.radius,
    this.delay,
  );

  final double startX;
  final double startY;
  final double driftX;
  final double rise;
  final double radius;
  final double delay;
}
