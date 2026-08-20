import 'package:florien/core/storage/settings_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/onboarding/updates_permission_screen.dart';
import 'package:florien/features/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('stores an opt-in for Florien news and campaigns', (
    tester,
  ) async {
    final storage = SettingsStorage();
    var completed = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsStorageProvider.overrideWithValue(storage)],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: UpdatesPermissionScreen(onComplete: () => completed = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('updates-permission-illustration')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('allow-updates')));
    await tester.tap(find.byKey(const ValueKey('allow-updates')));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(await storage.isUpdatesConsentIntroCompleted(), isTrue);
    expect(await storage.isMarketingUpdatesEnabled(), isTrue);
  });

  testWidgets('stores a separate decline without blocking onboarding', (
    tester,
  ) async {
    final storage = SettingsStorage();
    var completed = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsStorageProvider.overrideWithValue(storage)],
        child: MaterialApp(
          theme: FlorienTheme.dark,
          home: UpdatesPermissionScreen(onComplete: () => completed = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('decline-updates')));
    await tester.tap(find.byKey(const ValueKey('decline-updates')));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(await storage.isUpdatesConsentIntroCompleted(), isTrue);
    expect(await storage.isMarketingUpdatesEnabled(), isFalse);
  });
}
