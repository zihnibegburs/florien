import 'dart:convert';

import 'package:florien/core/models/models.dart';
import 'package:florien/core/storage/onboarding_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/onboarding/onboarding_screen.dart';
import 'package:florien/features/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('logged-in users skip the opening screen and existing-account link', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            _LoggedInAuthNotifier.new,
          ),
          onboardingPreferencesProvider.overrideWith(
            _EmptyOnboardingNotifier.new,
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(
      find.text('Bazen plan yapmak bile yorucu gelebilir.'),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('onboarding-existing-account')), findsNothing);
    expect(
      find.text('Gün içinde en sık hangisini yaşıyorsun?'),
      findsOneWidget,
    );
  });

  testWidgets('onboarding follows the active light theme', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: FlorienTheme.light,
          darkTheme: FlorienTheme.dark,
          themeMode: ThemeMode.light,
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final openingContext = tester.element(
      find.byKey(const ValueKey('onboarding-opening')),
    );
    expect(Theme.of(openingContext).brightness, Brightness.light);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      FlorienPalette.light.background,
    );
    final logo = tester.widget<Image>(
      find.byKey(const ValueKey('onboarding-opening-logo')),
    );
    expect(
      _assetNameOf(logo),
      'assets/brand/florien-logo-light-background.png',
    );
  });

  testWidgets('onboarding opening logo follows the dark theme', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: FlorienTheme.light,
          darkTheme: FlorienTheme.dark,
          themeMode: ThemeMode.dark,
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final logo = tester.widget<Image>(
      find.byKey(const ValueKey('onboarding-opening-logo')),
    );
    expect(_assetNameOf(logo), 'assets/brand/florien-logo-dark-background.png');
  });

  testWidgets('opening screen offers login for existing accounts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('Giriş ekranı')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('onboarding-existing-account')),
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-existing-account')));
    await tester.pumpAndSettle();

    expect(find.text('Giriş ekranı'), findsOneWidget);
  });

  testWidgets('completed onboarding remains saved and continues to login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_preferences_guest': jsonEncode({
        'completed': true,
        'onboardingVersion': '1',
        'answers': {
          'ONB-Q1': {
            'questionId': 'ONB-Q1',
            'answerId': 'mind_overload',
            'answeredAt': '2026-08-18T15:30:00.000',
          },
        },
      }),
    });
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('Giriş ekranı')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Giriş ekranı'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(preferences.getString('onboarding_preferences_guest')!)
            as Map<String, dynamic>;
    expect(stored['completed'], isTrue);
    expect(stored['answers'], isNotEmpty);
  });

  testWidgets('onboarding saves seven answers and advances automatically', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Bazen plan yapmak bile yorucu gelebilir.'),
      findsOneWidget,
    );
    expect(find.text('0/7'), findsOneWidget);
    expect(find.text('Profesyonel gibi planla'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('onboarding-start')));
    await tester.pumpAndSettle();
    expect(
      find.text('Gün içinde en sık hangisini yaşıyorsun?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Yapacaklarım kafamda birbirine giriyor'));
    await tester.pumpAndSettle();
    expect(find.text('1/7'), findsOneWidget);
    expect(
      find.text('Bir işe başlaman gerektiğinde genelde ne yapıyorsun?'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('onboarding-back')));
    await tester.pumpAndSettle();
    final selectedAnswer = find.byKey(
      const ValueKey('onboarding-answer-mind_overload'),
    );
    expect(
      find.descendant(
        of: selectedAnswer,
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Yapacaklarım kafamda birbirine giriyor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gözümde büyütüyorum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DEHB tanısı aldım'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Birkaç gün iyi gidiyor, sonra bırakıyorum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bir işin ne kadar süreceğini kestiremiyorum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kendime yükleniyorum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nereden başlayacağımı bilmek'));
    await tester.pumpAndSettle();

    expect(find.text('Yalnız değilsin.'), findsOneWidget);
    expect(find.text('Devam et'), findsOneWidget);
    expect(find.text('7/7'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final preferences = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(preferences.getString('onboarding_preferences_guest')!)
            as Map<String, dynamic>;
    final answers = stored['answers'] as Map<String, dynamic>;
    expect(stored['onboardingVersion'], '1');
    expect(answers, hasLength(7));
    expect(
      (answers['ONB-Q3'] as Map<String, dynamic>)['answerId'],
      'diagnosed',
    );
  });
}

String _assetNameOf(Image image) {
  final provider = image.image;
  final assetProvider = provider is ResizeImage
      ? provider.imageProvider
      : provider;
  return (assetProvider as AssetImage).assetName;
}

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  Future<AuthResponse?> build() async => const AuthResponse(
    userId: 'user-1',
    email: 'user@example.com',
    displayName: 'Test User',
    avatarColor: '#F2BC52',
  );
}

class _EmptyOnboardingNotifier extends OnboardingPreferencesNotifier {
  @override
  Future<OnboardingPreferences> build() async => const OnboardingPreferences();
}
