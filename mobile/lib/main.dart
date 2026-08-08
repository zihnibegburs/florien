import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:live_activities/models/url_scheme_data.dart';
import 'package:mimio/core/l10n/app_strings.dart';
import 'package:mimio/core/platform/live_activity_service.dart';
import 'package:mimio/core/platform/notification_service.dart';
import 'package:mimio/core/platform/siri_sync_service.dart';
import 'package:mimio/core/platform/widget_sync_service.dart';
import 'package:mimio/core/theme/mimio_theme.dart';
import 'package:mimio/core/widgets/liquid_glass.dart';
import 'package:mimio/core/widgets/mimio_soft_overlay.dart';
import 'package:mimio/features/auth/login_screen.dart';
import 'package:mimio/features/auth/register_screen.dart';
import 'package:mimio/features/providers.dart';
import 'package:mimio/features/ai/ai_plan_screen.dart';
import 'package:mimio/features/achievements/achievements_screen.dart';
import 'package:mimio/features/weekly/weekly_retrospective_screen.dart';
import 'package:mimio/features/integrations/calendar_import_screen.dart';
import 'package:mimio/features/focus/focus_screen.dart';
import 'package:mimio/features/profile/profile_screen.dart';
import 'package:mimio/features/timeline/home_screen.dart';
import 'package:mimio/features/timeline/home_tab.dart';
import 'package:mimio/features/web/web_shell.dart';
import 'package:mimio/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  for (final locale in ['tr_TR', 'en_US', 'es_ES', 'fr_FR', 'de_DE']) {
    await initializeDateFormatting(locale);
  }

  if (DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } else {
    debugPrint(
      'Firebase not configured — fill mobile/lib/firebase_options.dart via `flutterfire configure`.',
    );
  }

  await WidgetSyncService.initialize();
  await LiveActivityService.instance.initialize();
  await NotificationService(FlutterLocalNotificationsPlugin()).initialize();

  String? token;
  if (DefaultFirebaseOptions.isConfigured) {
    token = await FirebaseAuth.instance.currentUser?.getIdToken();
  }
  await SiriSyncService.syncCredentials(token: token);
  runApp(const ProviderScope(child: MimioApp()));
}

class MimioApp extends ConsumerWidget {
  const MimioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final lang = ref.watch(appLanguageProvider).valueOrNull ?? 'tr';
    final themeMode = ref.watch(appThemeModeProvider).valueOrNull ?? ThemeMode.system;

    return LiveActivityDeepLinkListener(
      child: MaterialApp.router(
        title: 'Mimio',
        theme: MimioTheme.light,
        darkTheme: MimioTheme.dark,
        themeMode: themeMode,
        locale: Locale(lang),
        routerConfig: router,
        builder: (context, child) => MimioAmbientBackground(
          child: child ?? const SizedBox.shrink(),
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class LiveActivityDeepLinkListener extends ConsumerStatefulWidget {
  const LiveActivityDeepLinkListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LiveActivityDeepLinkListener> createState() => _LiveActivityDeepLinkListenerState();
}

class _LiveActivityDeepLinkListenerState extends ConsumerState<LiveActivityDeepLinkListener> {
  StreamSubscription<UrlSchemeData>? _subscription;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    final service = LiveActivityService.instance;
    if (!service.isInitialized) return;
    _subscription = service.plugin.urlSchemeStream().listen((data) {
      if (!mounted) return;
      final path = data.path ?? '';
      if (path.contains('focus') || path.isEmpty) {
        ref.read(homeTabProvider.notifier).state = HomeTab.focus;
        final router = ref.read(routerProvider);
        if (router.state.matchedLocation != '/home') {
          router.go('/home');
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/home',
        builder: (_, __) => const WebShell(child: HomeScreen()),
      ),
      GoRoute(
        path: '/focus',
        pageBuilder: (context, state) => mimioOverlayGoRoutePage(state: state, child: const FocusScreen()),
      ),
      GoRoute(
        path: '/ai',
        pageBuilder: (context, state) => mimioOverlayGoRoutePage(state: state, child: const AiPlanScreen()),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => mimioOverlayGoRoutePage(state: state, child: const ProfileScreen()),
      ),
      GoRoute(
        path: '/calendar-import',
        pageBuilder: (context, state) => mimioOverlayGoRoutePage(state: state, child: const CalendarImportScreen()),
      ),
      GoRoute(
        path: '/achievements',
        pageBuilder: (context, state) => mimioOverlayGoRoutePage(state: state, child: const AchievementsScreen()),
      ),
      GoRoute(
        path: '/brain-dump',
        redirect: (_, __) => '/ai',
      ),
      GoRoute(
        path: '/weekly-retro',
        pageBuilder: (context, state) =>
            mimioOverlayGoRoutePage(state: state, child: const WeeklyRetrospectiveScreen()),
      ),
    ],
  );
});
