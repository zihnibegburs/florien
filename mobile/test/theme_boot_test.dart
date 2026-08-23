import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('light and dark themes build the first frame', (tester) async {
    for (final theme in [FlorienTheme.light, FlorienTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: const Text('boot'),
            bottomNavigationBar: FlorienBottomNavigation(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              onAiPressed: () {},
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
      await tester.pump();
      expect(find.text('boot'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
