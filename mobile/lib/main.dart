import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/liquid_glass.dart';
import 'package:florien/features/auth/login_screen.dart';
import 'package:florien/features/auth/register_screen.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/todo_home_screen.dart';
import 'package:florien/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const ProviderScope(child: FlorienApp()));
}

class FlorienApp extends ConsumerWidget {
  const FlorienApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appLanguageProvider).valueOrNull ?? 'tr';
    final themeMode =
        ref.watch(appThemeModeProvider).valueOrNull ?? ThemeMode.system;

    return MaterialApp.router(
      title: 'Florien',
      theme: FlorienTheme.light,
      darkTheme: FlorienTheme.dark,
      themeMode: themeMode,
      locale: Locale(language),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          FlorienAmbientBackground(child: child ?? const SizedBox.shrink()),
      debugShowCheckedModeBanner: false,
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = auth.valueOrNull != null;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      if (!loggedIn && !isAuthRoute) return '/login';
      if (loggedIn && isAuthRoute) return '/todo';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/todo', builder: (_, _) => const TodoHomeScreen()),
    ],
  );
});
