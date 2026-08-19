import 'package:florien/core/models/models.dart';
import 'package:florien/features/premium/premium_membership.dart';
import 'package:florien/features/premium/premium_membership_screen.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  Future<AuthResponse?> build() async => const AuthResponse(
    userId: 'user-1',
    email: 'user@example.com',
    displayName: 'Test User',
    avatarColor: '#F2BC52',
  );
}

class _TestPremiumMembershipNotifier extends PremiumMembershipNotifier {
  @override
  Future<PremiumMembership> build() async =>
      const PremiumMembership(storeAvailable: false);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('logged-in auth routes redirect to paywall', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
        premiumMembershipProvider.overrideWith(
          _TestPremiumMembershipNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FlorienApp(),
      ),
    );
    await tester.pump();

    container.read(routerProvider).go('/login');
    for (var attempt = 0; attempt < 10; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .byKey(const ValueKey('paywall-continue'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }

    expect(find.text('Florien Premium'), findsWidgets);
    expect(find.byKey(const ValueKey('paywall-continue')), findsOneWidget);
  });

  testWidgets('onboarding paywall can be skipped', (tester) async {
    var continued = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumMembershipProvider.overrideWith(
            _TestPremiumMembershipNotifier.new,
          ),
        ],
        child: MaterialApp(
          home: PremiumMembershipScreen(onContinue: () => continued = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Şimdilik geç'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('paywall-continue')));

    expect(continued, isTrue);
  });
}
