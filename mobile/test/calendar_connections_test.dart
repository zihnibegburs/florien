import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/todo/calendar_connections_screen.dart';
import 'package:florien/features/todo/settings_screen.dart';
import 'package:florien/features/premium/premium_membership.dart';

class _NonPremiumMembershipNotifier extends PremiumMembershipNotifier {
  @override
  Future<PremiumMembership> build() async =>
      const PremiumMembership(storeAvailable: false);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('settings hides calendar connections while the feature is off', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumMembershipProvider.overrideWith(
            _NonPremiumMembershipNotifier.new,
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const SettingsScreen(),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('settings-apple-health')), findsOneWidget);
    expect(find.text('Apple Sağlık'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-rate-us')), findsOneWidget);
    expect(find.text('Bizi değerlendirin'), findsOneWidget);
    expect(find.text('Bağlı Takvimler'), findsNothing);
    expect(find.byType(CalendarConnectionsScreen), findsNothing);
  });
}
