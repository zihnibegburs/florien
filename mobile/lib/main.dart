import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/services/home_screen_widget_service.dart';
import 'package:florien/core/firebase/firebase_providers.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/liquid_glass.dart';
import 'package:florien/features/auth/email_login_screen.dart';
import 'package:florien/features/auth/login_screen.dart';
import 'package:florien/features/auth/register_screen.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/task_icon/services/task_icon_classifier.dart';
import 'package:florien/features/onboarding/onboarding_screen.dart';
import 'package:florien/features/onboarding/notification_permission_screen.dart';
import 'package:florien/features/premium/premium_membership_screen.dart';
import 'package:florien/features/todo/todo_home_screen.dart';
import 'package:florien/firebase_options.dart';
import 'package:home_widget/home_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  unawaited(HomeScreenWidgetService.initialize());
  if (!kIsWeb) {
    await HomeWidget.registerInteractivityCallback(
      florienWidgetBackgroundCallback,
    );
  }
  runApp(const ProviderScope(child: FlorienApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      TaskIconClassifier.instance.initialize().onError((error, stackTrace) {
        debugPrint('Task icon classifier warm-up failed: $error');
      }),
    );
  });
}

@pragma('vm:entry-point')
Future<void> florienWidgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!DefaultFirebaseOptions.isConfigured) return;
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  final command = HomeScreenWidgetService.commandFromUri(uri);
  if (command?.action != HomeWidgetLaunchAction.taskComplete ||
      command?.taskId == null) {
    return;
  }

  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return;
  final profileId = uri?.queryParameters['profileId'] ?? 'primary';
  final taskRef = tasksCol(
    FirebaseFirestore.instance,
    userId,
    profileId,
  ).doc(command!.taskId);
  final task = await taskRef.get();
  if (!task.exists || task.data()?['status'] == 'COMPLETED') return;

  await taskRef.update({
    'status': 'COMPLETED',
    'completedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  final parentTaskId = task.data()?['parentTaskId'] as String?;
  if (parentTaskId != null) {
    final siblings = await tasksCol(
      FirebaseFirestore.instance,
      userId,
      profileId,
    ).where('parentTaskId', isEqualTo: parentTaskId).get();
    final allCompleted = siblings.docs.every(
      (sibling) =>
          sibling.id == command.taskId ||
          sibling.data()['status'] == 'COMPLETED',
    );
    if (allCompleted) {
      await tasksCol(
        FirebaseFirestore.instance,
        userId,
        profileId,
      ).doc(parentTaskId).update({
        'status': 'COMPLETED',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
  await HomeScreenWidgetService.removeCompletedTask(
    taskId: command.taskId!,
    isDailyPlan: command.isDailyPlan,
  );
}

class FlorienApp extends ConsumerStatefulWidget {
  const FlorienApp({super.key});

  @override
  ConsumerState<FlorienApp> createState() => _FlorienAppState();
}

class _FlorienAppState extends ConsumerState<FlorienApp> {
  StreamSubscription<Uri?>? _widgetLaunchSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_listenForHomeWidgetLaunches());
    });
  }

  Future<void> _listenForHomeWidgetLaunches() async {
    try {
      await HomeScreenWidgetService.initialize();
      _widgetLaunchSubscription = HomeWidget.widgetClicked.listen(
        _handleWidgetLaunch,
      );
      await _handleWidgetLaunch(
        await HomeWidget.initiallyLaunchedFromHomeWidget(),
      );
    } catch (error) {
      debugPrint('Home widget launch could not be read: $error');
    }
  }

  @override
  void dispose() {
    _widgetLaunchSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleWidgetLaunch(Uri? uri) async {
    final command = HomeScreenWidgetService.commandFromUri(uri);
    if (command == null || !mounted) return;

    ref.read(routerProvider).go('/todo');
    if (command.action != HomeWidgetLaunchAction.focus) {
      ref.read(homeWidgetLaunchProvider.notifier).state = command;
      return;
    }

    ref.read(homeWidgetLaunchProvider.notifier).state = command;
    try {
      final launch = await ref.read(createStandaloneFocusTaskProvider)(
        command.durationMinutes ?? 15,
      );
      ref.read(focusTaskLaunchProvider.notifier).state = launch;
    } catch (error) {
      debugPrint('Focus session could not start from home widget: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
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
    initialLocation: '/onboarding',
    redirect: (context, state) {
      final loggedIn = auth.valueOrNull != null;
      final isOnboardingRoute = state.matchedLocation == '/onboarding';
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/email-login';
      if (isOnboardingRoute) return null;
      if (!loggedIn && !isAuthRoute) return '/login';
      if (loggedIn && isAuthRoute) return '/paywall';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/email-login',
        builder: (_, _) => const EmailLoginScreen(),
      ),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/paywall',
        builder: (context, _) => PremiumMembershipScreen(
          onContinue: () async {
            final completed = await ref
                .read(settingsStorageProvider)
                .isNotificationPermissionIntroCompleted();
            if (!context.mounted) return;
            context.go(completed ? '/todo' : '/notification-permission');
          },
        ),
      ),
      GoRoute(
        path: '/notification-permission',
        builder: (context, _) =>
            NotificationPermissionScreen(onComplete: () => context.go('/todo')),
      ),
      GoRoute(path: '/todo', builder: (_, _) => const TodoHomeScreen()),
    ],
  );
});
