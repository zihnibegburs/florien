import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/todo/calendar_connections_screen.dart';
import 'package:florien/features/todo/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('settings opens Apple and Google calendar connections', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const SettingsScreen(),
        ),
      ),
    );

    await tester.tap(find.text('Bağlı Takvimler'));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarConnectionsScreen), findsOneWidget);
    expect(find.text('Apple Takvimini Bağla'), findsOneWidget);
    expect(find.text('Google Takvimini Bağla'), findsOneWidget);
  });
}
