import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/services/home_screen_widget_service.dart';
import 'package:florien/core/services/notification_payload.dart';
import 'package:florien/core/firebase/firebase_providers.dart';
import 'package:florien/core/routing/startup_routing.dart';
import 'package:florien/core/routing/startup_screen.dart';
import 'package:florien/core/storage/onboarding_storage.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_keyboard.dart';
import 'package:florien/core/widgets/liquid_glass.dart';
import 'package:florien/features/auth/email_login_screen.dart';
import 'package:florien/features/auth/login_screen.dart';
import 'package:florien/features/auth/register_screen.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/task_icon/services/task_icon_classifier.dart';
import 'package:florien/features/onboarding/onboarding_screen.dart';
import 'package:florien/features/onboarding/notification_permission_screen.dart';
import 'package:florien/features/onboarding/updates_permission_screen.dart';
import 'package:florien/features/premium/premium_membership.dart';
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

class _FlorienAppState extends ConsumerState<FlorienApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetLaunchSubscription;
  bool _notificationHandlersReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_listenForHomeWidgetLaunches());
      unawaited(_prepareNotifications());
      // Warm StoreKit + purchase stream before the paywall opens.
      unawaited(_preparePremiumStore());
    });
  }

  Future<void> _preparePremiumStore() async {
    try {
      await ref.read(premiumPurchaseServiceProvider).prepareStore();
      // Touch the provider so purchaseStream is subscribed early.
      ref.read(premiumMembershipProvider);
    } catch (error) {
      debugPrint('Premium store prepare failed: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_reconcileNotifications());
      unawaited(_refreshPremiumEntitlement());
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    ref.invalidate(appLanguageProvider);
  }

  Future<void> _refreshPremiumEntitlement() async {
    final auth = ref.read(authStateProvider).valueOrNull;
    if (auth == null) return;
    try {
      await ref.read(premiumMembershipProvider.notifier).refreshEntitlement();
    } catch (error) {
      debugPrint('Premium entitlement refresh failed: $error');
    }
  }

  Future<void> _prepareNotifications() async {
    final alarms = ref.read(taskAlarmServiceProvider);
    await alarms.initialize();
    alarms.onNotificationOpened = (payload) async {
      await _dispatchNotificationPayload(payload);
    };
    alarms.onNotificationAction = (payload, actionId) async {
      if (actionId == 'complete' && payload.taskId != null) {
        try {
          await ref.read(completeFocusedTaskProvider)(payload.taskId!);
        } catch (error) {
          debugPrint('Notification complete action failed: $error');
        }
        return;
      }
      if (actionId == 'dismiss_alarm') {
        ref.read(planAlarmRingProvider.notifier).state = null;
        final taskId = payload.taskId;
        if (taskId != null) {
          try {
            await ref.read(taskAlarmServiceProvider).cancelPlanAlarm(taskId);
          } catch (error) {
            debugPrint('Plan alarm dismiss failed: $error');
          }
        }
        return;
      }
      await _dispatchNotificationPayload(payload);
    };
    _notificationHandlersReady = true;
    final launch = await alarms.consumeLaunchPayload();
    if (launch != null) await _dispatchNotificationPayload(launch);
    await _reconcileNotifications();
  }

  Future<void> _dispatchNotificationPayload(
    FlorienNotificationPayload payload,
  ) async {
    final auth = ref.read(authStateProvider).valueOrNull;
    if (auth == null) return;
    if (payload.accountId.isNotEmpty && payload.accountId != auth.userId) {
      return;
    }
    ref.read(routerProvider).go('/todo');
    ref
        .read(notificationLaunchProvider.notifier)
        .state = NotificationLaunchCommand(
      target: payload.target,
      taskId: payload.taskId,
      kind: payload.kind,
    );
  }

  Future<void> _reconcileNotifications() async {
    if (!_notificationHandlersReady) return;
    final auth = ref.read(authStateProvider).valueOrNull;
    if (auth == null) return;
    try {
      await ref.read(notificationReconcileProvider)();
    } catch (error) {
      debugPrint('Notification reconcile failed: $error');
    }
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
    WidgetsBinding.instance.removeObserver(this);
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
    final language =
        ref.watch(appLanguageProvider).valueOrNull ?? ActiveLanguage.code;
    final themeMode =
        ref.watch(appThemeModeProvider).valueOrNull ?? ThemeMode.system;

    ref.listen(authStateProvider, (previous, next) {
      final wasLoggedIn = previous?.valueOrNull != null;
      final isLoggedIn = next.valueOrNull != null;
      if (!wasLoggedIn && isLoggedIn) {
        unawaited(_reconcileNotifications());
      }
    });

    return MaterialApp.router(
      title: 'Florien',
      theme: FlorienTheme.light,
      darkTheme: FlorienTheme.dark,
      themeMode: themeMode,
      locale: localeForLanguageCode(language),
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => FlorienKeyboardDismiss(
        child: FlorienAmbientBackground(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);
  final onboardingPrefs = ref.watch(onboardingPreferencesProvider);
  final setupRequired = ref.watch(onboardingSetupRequiredProvider);

  return GoRouter(
    initialLocation: '/startup',
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (location == '/startup') return null;

      if (auth.isLoading ||
          onboardingPrefs.isLoading ||
          setupRequired.isLoading) {
        return '/startup';
      }

      final loggedIn = auth.valueOrNull != null;
      final prefs =
          onboardingPrefs.valueOrNull ?? const OnboardingPreferences();
      final isAuthRoute =
          location == '/login' ||
          location == '/register' ||
          location == '/email-login';
      final isSetupFlow =
          location == '/paywall' ||
          location == '/notification-permission' ||
          location == '/updates-permission';

      if (loggedIn && prefs.completed) {
        if (isAuthRoute || location == '/onboarding' || isSetupFlow) {
          return '/todo';
        }
        return null;
      }

      if (!loggedIn) {
        if (location == '/todo' || isSetupFlow) return '/login';
        if (location == '/onboarding' &&
            (prefs.completed || isOnboardingSurveyComplete(prefs))) {
          return '/login';
        }
        return null;
      }

      final surveyComplete = isOnboardingSurveyComplete(prefs);
      if (!surveyComplete) {
        if (location == '/todo' || isSetupFlow) return '/onboarding';
        if (isAuthRoute) return '/onboarding';
        return null;
      }

      if (setupRequired.valueOrNull != true) {
        if (location == '/onboarding' || isAuthRoute || isSetupFlow) {
          return '/todo';
        }
        return null;
      }

      if (location == '/todo' || location == '/onboarding' || isAuthRoute) {
        return '/paywall';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/startup', builder: (_, _) => const StartupScreen()),
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
            await continueOnboardingSetupFromPaywall(context, ref);
          },
        ),
      ),
      GoRoute(
        path: '/notification-permission',
        builder: (context, _) => NotificationPermissionScreen(
          onComplete: () async {
            final completed = await ref
                .read(settingsStorageProvider)
                .isUpdatesConsentIntroCompleted();
            if (!context.mounted) return;
            if (!completed) {
              context.go('/updates-permission');
              return;
            }
            await completeOnboardingSetupAndGoTodo(context, ref);
          },
        ),
      ),
      GoRoute(
        path: '/updates-permission',
        builder: (context, _) => UpdatesPermissionScreen(
          onComplete: () async {
            await completeOnboardingSetupAndGoTodo(context, ref);
          },
        ),
      ),
      GoRoute(path: '/todo', builder: (_, _) => const TodoHomeScreen()),
    ],
  );
});
