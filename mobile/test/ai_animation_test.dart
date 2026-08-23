import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_ai_animation.dart';
import 'package:florien/core/widgets/florien_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

Widget _animationHost(double speed) {
  return MaterialApp(
    theme: FlorienTheme.light,
    home: Scaffold(
      body: Center(
        child: FlorienAiAnimation(
          key: const ValueKey('ai-animation-under-test'),
          speed: speed,
          animate: true,
        ),
      ),
    ),
  );
}

double _progressDelta(double before, double after) {
  return after >= before ? after - before : (1 - before) + after;
}

void main() {
  test('voice animation speed increases with sound energy', () {
    final idle = florienAiVoiceAnimationSpeed(
      isListening: false,
      soundLevel: 1,
    );
    final quiet = florienAiVoiceAnimationSpeed(
      isListening: true,
      soundLevel: 0.1,
    );
    final speaking = florienAiVoiceAnimationSpeed(
      isListening: true,
      soundLevel: 0.9,
    );

    expect(idle, 0.65);
    expect(quiet, greaterThan(idle));
    expect(speaking, greaterThan(quiet));
    expect(speaking, lessThanOrEqualTo(3));
  });

  testWidgets('Lottie playback accelerates without replacing the animation', (
    tester,
  ) async {
    await tester.pumpWidget(_animationHost(0.5));
    await tester.pump(const Duration(milliseconds: 200));

    final lottieFinder = find.byKey(const ValueKey('florien-ai-lottie'));
    expect(lottieFinder, findsOneWidget);
    final lottie = tester.widget<LottieBuilder>(lottieFinder);
    final controller = lottie.controller!;

    final slowStart = controller.value;
    await tester.pump(const Duration(milliseconds: 300));
    final slowDelta = _progressDelta(slowStart, controller.value);

    await tester.pumpWidget(_animationHost(2));
    await tester.pump(const Duration(milliseconds: 30));
    final fastStart = controller.value;
    await tester.pump(const Duration(milliseconds: 300));
    final fastDelta = _progressDelta(fastStart, controller.value);

    expect(slowDelta, greaterThan(0));
    expect(fastDelta, greaterThan(slowDelta * 2.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI FAB uses the supplied image and remains tappable', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: Scaffold(body: FlorienAiFab(onPressed: () => tapped = true)),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('florien-ai-fab-image')), findsOneWidget);
    final image = tester.widget<Image>(
      find.byKey(const ValueKey('florien-ai-fab-image')),
    );
    expect((image.image as AssetImage).assetName, florienAiFabImageAsset);
    expect(find.byType(FlorienAiAnimation), findsNothing);
    await tester.tap(find.byType(FlorienAiFab));
    expect(tapped, isTrue);
  });

  testWidgets('bottom banner keeps a decorative special button on the right', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: Scaffold(
          bottomNavigationBar: FlorienBottomNavigation(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: const [
              FlorienNavDestination(
                label: 'To-do',
                icon: Icons.check_box_outlined,
                selectedIcon: Icons.check_box_rounded,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('florien-nav-special-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('florien-nav-special-image')), findsOneWidget);
    expect(find.byKey(const ValueKey('planner-ai-chat-button')), findsNothing);
  });
}
