import 'package:florien/core/routing/startup_routing.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/storage/onboarding_storage.dart';
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

class _SurveyCompleteOnboardingNotifier extends OnboardingPreferencesNotifier {
  @override
  Future<OnboardingPreferences> build() async {
    final now = DateTime(2026, 1, 1);
    return OnboardingPreferences(
      answers: {
        for (final questionId in onboardingSurveyQuestionIds)
          questionId: OnboardingAnswer(
            questionId: questionId,
            answerId: 'test',
            answeredAt: now,
          ),
      },
    );
  }
}

class _CompletedOnboardingNotifier extends OnboardingPreferencesNotifier {
  @override
  Future<OnboardingPreferences> build() async =>
      const OnboardingPreferences(completed: true);
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

class _RetryPremiumPlansNotifier extends PremiumMembershipNotifier {
  bool reloadCalled = false;

  @override
  Future<PremiumMembership> build() async =>
      const PremiumMembership(storeAvailable: true);

  @override
  Future<void> reloadProducts() async {
    reloadCalled = true;
    state = AsyncData(
      PremiumMembership(
        storeAvailable: true,
        // Deliberately stale: the model must fall back to the available plan.
        selectedProductId: premiumMonthlyProductId,
        products: [
          ProductDetails(
            id: premiumYearlyProductId,
            title: 'Yıllık',
            description: '',
            price: '₺799,99',
            rawPrice: 799.99,
            currencyCode: 'TRY',
          ),
        ],
      ),
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('existing account login skips paywall after survey', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_login_intent': 'existing',
    });
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
        onboardingPreferencesProvider.overrideWith(
          _SurveyCompleteOnboardingNotifier.new,
        ),
        premiumMembershipProvider.overrideWith(
          _TestPremiumMembershipNotifier.new,
        ),
        recentAuthIsNewUserProvider.overrideWith((ref) => false),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    await container.read(onboardingPreferencesProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FlorienApp(),
      ),
    );
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .byKey(const ValueKey('todo-home-scroll-chrome-header'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }

    expect(find.byKey(const ValueKey('paywall-continue')), findsNothing);
    expect(find.text('Florien Premium'), findsNothing);
    expect(
      find.byKey(const ValueKey('todo-home-scroll-chrome-header')),
      findsOneWidget,
    );
  });

  testWidgets('survey complete on startup opens paywall until setup is done', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
        onboardingPreferencesProvider.overrideWith(
          _SurveyCompleteOnboardingNotifier.new,
        ),
        premiumMembershipProvider.overrideWith(
          _TestPremiumMembershipNotifier.new,
        ),
        recentAuthIsNewUserProvider.overrideWith((ref) => true),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    await container.read(onboardingPreferencesProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FlorienApp(),
      ),
    );
    for (var attempt = 0; attempt < 20; attempt++) {
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
    expect(
      find.byKey(const ValueKey('todo-home-scroll-chrome-header')),
      findsNothing,
    );
  });

  testWidgets('onboarding paywall continues to notification permission', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumMembershipProvider.overrideWith(
            _TestPremiumMembershipNotifier.new,
          ),
        ],
        child: MaterialApp(
          home: PremiumMembershipScreen(
            onContinue: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Florien Premium'), findsWidgets);
    expect(find.text('Florien özellikleri'), findsOneWidget);
    expect(find.byKey(const ValueKey('paywall-continue')), findsOneWidget);
  });

  testWidgets('completed onboarding skips paywall on startup', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
        onboardingPreferencesProvider.overrideWith(
          _CompletedOnboardingNotifier.new,
        ),
        premiumMembershipProvider.overrideWith(
          _TestPremiumMembershipNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    await container.read(onboardingPreferencesProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FlorienApp(),
      ),
    );
    await tester.pump();
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .byKey(const ValueKey('todo-home-scroll-chrome-header'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }

    expect(find.byKey(const ValueKey('paywall-continue')), findsNothing);
    expect(find.text('Florien Premium'), findsNothing);
    expect(
      find.byKey(const ValueKey('todo-home-scroll-chrome-header')),
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
          home: PremiumMembershipScreen(
            onContinue: () async {
              continued = true;
            },
          ),
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

  testWidgets('missing products show retry and use the available fallback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notifier = _RetryPremiumPlansNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [premiumMembershipProvider.overrideWith(() => notifier)],
        child: const MaterialApp(home: PremiumMembershipScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final retry = find.byKey(const ValueKey('retry-premium-products'));
    await tester.scrollUntilVisible(
      retry,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Premium yakında'), findsNothing);
    expect(find.text('Planları tekrar yükle'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('premium-plan-$premiumMonthlyProductId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('premium-plan-$premiumYearlyProductId')),
      findsOneWidget,
    );
    expect(find.text('App Store fiyatı bekleniyor'), findsNWidgets(2));

    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(notifier.reloadCalled, isTrue);
    expect(
      find.byKey(const ValueKey('premium-plan-$premiumYearlyProductId')),
      findsOneWidget,
    );
    expect(find.text('₺799,99 karşılığında Premium ol'), findsOneWidget);
    expect(
      notifier.state.requireValue.selectedProduct?.id,
      premiumYearlyProductId,
    );
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
