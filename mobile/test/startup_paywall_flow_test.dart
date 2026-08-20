import 'package:florien/core/models/models.dart';
import 'package:florien/features/premium/premium_membership.dart';
import 'package:florien/features/premium/premium_membership_screen.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/core/services/premium_purchase_service.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

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

class _PremiumPlansNotifier extends PremiumMembershipNotifier {
  @override
  Future<PremiumMembership> build() async => PremiumMembership(
    storeAvailable: true,
    selectedProductId: premiumMonthlyProductId,
    products: [
      ProductDetails(
        id: premiumMonthlyProductId,
        title: 'Aylık',
        description: '',
        price: '₺99,99',
        rawPrice: 99.99,
        currencyCode: 'TRY',
      ),
      ProductDetails(
        id: premiumYearlyProductId,
        title: 'Yıllık',
        description: '',
        price: '₺799,99',
        rawPrice: 799.99,
        currencyCode: 'TRY',
      ),
    ],
  );
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
    expect(find.text('Florien özellikleri'), findsOneWidget);
    expect(find.text('Yapılacaklar ve günlük plan'), findsOneWidget);
    expect(find.text('Odak zamanlayıcısı'), findsOneWidget);
    expect(find.text('Hazır rutinler'), findsOneWidget);
    expect(find.text('Günlük yansımalar'), findsOneWidget);
    expect(find.text('AI plan asistanı'), findsOneWidget);
    expect(find.text('Alt görevler'), findsOneWidget);
    expect(find.text('Birden fazla profil'), findsOneWidget);
    expect(find.text('Takvim aktarma'), findsOneWidget);
    expect(find.text('Alarm ve hatırlatıcılar'), findsOneWidget);
    expect(find.text('Görev için özel saat'), findsOneWidget);
    expect(find.text('Standart'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.byKey(const ValueKey('standard-aiChat')), findsOneWidget);
    expect(find.byKey(const ValueKey('premium-aiChat')), findsOneWidget);
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('standard-tasksAndDailyPlan')),
          )
          .icon,
      Icons.check_circle_rounded,
    );
    expect(
      tester
          .widget<Icon>(find.byKey(const ValueKey('premium-tasksAndDailyPlan')))
          .icon,
      Icons.check_circle_rounded,
    );
    expect(
      tester.widget<Icon>(find.byKey(const ValueKey('standard-aiChat'))).icon,
      Icons.close_rounded,
    );
    expect(find.byKey(const ValueKey('paywall-continue')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('paywall-continue')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('notification-permission-screen')),
      findsOneWidget,
    );
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

  testWidgets('monthly and yearly plans are shown side by side', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumMembershipProvider.overrideWith(_PremiumPlansNotifier.new),
        ],
        child: const MaterialApp(home: PremiumMembershipScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final monthly = find.byKey(
      const ValueKey('premium-plan-$premiumMonthlyProductId'),
    );
    final yearly = find.byKey(
      const ValueKey('premium-plan-$premiumYearlyProductId'),
    );
    await tester.scrollUntilVisible(
      monthly,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(monthly, findsOneWidget);
    expect(yearly, findsOneWidget);
    expect(find.text('Esnek'), findsOneWidget);
    expect(find.text('En avantajlı'), findsOneWidget);
    expect(find.textContaining('Günde yaklaşık'), findsNWidgets(2));
    expect(find.textContaining('3,33'), findsOneWidget);
    expect(find.textContaining('2,19'), findsOneWidget);
    expect(tester.getTopLeft(monthly).dy, tester.getTopLeft(yearly).dy);
    expect(
      tester.getTopLeft(monthly).dx,
      lessThan(tester.getTopLeft(yearly).dx),
    );
    final monthlyDecoration =
        tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: monthly,
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration
            as BoxDecoration;
    final yearlyDecoration =
        tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: yearly,
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(monthlyDecoration.color, isNot(yearlyDecoration.color));
    expect(monthlyDecoration.border!.top.width, 2);
    expect(yearlyDecoration.border!.top.width, FlorienBorders.thin);
  });

  testWidgets('plan cards follow the selected English language', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_language': 'en'});
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumMembershipProvider.overrideWith(_PremiumPlansNotifier.new),
        ],
        child: const MaterialApp(home: PremiumMembershipScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Florien features'), findsOneWidget);
    expect(find.text('To-dos and daily plan'), findsOneWidget);
    expect(find.text('AI planning assistant'), findsOneWidget);
    final monthly = find.byKey(
      const ValueKey('premium-plan-$premiumMonthlyProductId'),
    );
    await tester.scrollUntilVisible(
      monthly,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose your plan'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Best value'), findsOneWidget);
    expect(find.textContaining('per day'), findsNWidgets(2));
    expect(find.textContaining('3.33'), findsOneWidget);
    expect(find.textContaining('2.19'), findsOneWidget);
  });
}
