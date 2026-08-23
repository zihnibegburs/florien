import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_duration_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('duration picker uses compact tiles instead of sparse rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showFlorienDurationPicker(
                context: context,
                selected: 15,
              ),
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();

    expect(find.text('Süre'), findsOneWidget);
    expect(find.text('5 dk'), findsOneWidget);
    expect(find.text('1,5 saat'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);

    final tile = tester.getSize(find.text('30 dk'));
    expect(tile.height, lessThan(28));

    await tester.tap(find.text('30 dk'));
    await tester.pumpAndSettle();
    expect(find.text('1,5 saat'), findsNothing);
  });
}
