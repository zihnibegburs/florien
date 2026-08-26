import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/services/apple_health_mood_service.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/premium/premium_membership.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/settings_screen.dart';

class _NonPremiumMembershipNotifier extends PremiumMembershipNotifier {
  @override
  Future<PremiumMembership> build() async =>
      const PremiumMembership(storeAvailable: false);
}

class _GuestAuthNotifier extends AuthNotifier {
  @override
  Future<AuthResponse?> build() async => null;
}

class _DeniedAppleHealth extends AppleHealthMoodService {
  @override
  bool get isSupported => true;

  @override
  Future<bool> requestAuthorization() async => false;

  @override
  Future<bool> isSharingAuthorized() async => false;
}

void main() {
  testWidgets('denying Apple Health does not mark settings as connected', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_GuestAuthNotifier.new),
          premiumMembershipProvider.overrideWith(
            _NonPremiumMembershipNotifier.new,
          ),
          appleHealthMoodServiceProvider.overrideWith(
            (ref) => _DeniedAppleHealth(),
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-apple-health')));
    await tester.pumpAndSettle();

    expect(find.text('Bağlı'), findsNothing);
    expect(
      find.text('Apple Sağlık izni verilmedi veya bu iPhone desteklenmiyor.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'stale Health sync flag is not shown as connected without sharing',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'mood_health_sync_v1_guest:primary': true,
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(_GuestAuthNotifier.new),
            premiumMembershipProvider.overrideWith(
              _NonPremiumMembershipNotifier.new,
            ),
            appleHealthMoodServiceProvider.overrideWith(
              (ref) => _DeniedAppleHealth(),
            ),
          ],
          child: MaterialApp(
            theme: FlorienTheme.light,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bağlı'), findsNothing);
    },
  );
}
