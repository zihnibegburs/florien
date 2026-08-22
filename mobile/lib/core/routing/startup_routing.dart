import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:florien/core/storage/onboarding_login_intent_storage.dart';
import 'package:florien/core/storage/onboarding_storage.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:florien/features/providers.dart';

final onboardingSetupRequiredProvider = FutureProvider<bool>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(onboardingPreferencesProvider);
  ref.watch(recentAuthIsNewUserProvider);
  return shouldShowOnboardingSetup(ref);
});

final startupDestinationProvider = FutureProvider<String>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(onboardingPreferencesProvider);
  ref.watch(onboardingSetupRequiredProvider);
  return resolveStartupDestination(ref);
});

Future<bool> shouldShowOnboardingSetup(dynamic ref) async {
  final prefs = await ref.read(onboardingPreferencesProvider.future);
  if (prefs.completed) return false;
  if (!isOnboardingSurveyComplete(prefs)) return false;

  final isNewUser = ref.read(recentAuthIsNewUserProvider);
  if (isNewUser == true) return true;
  if (isNewUser == false) return false;

  final intent = await ref.read(onboardingLoginIntentStorageProvider).load();
  return intent != OnboardingLoginIntent.existingAccount;
}

Future<String> resolveIncompleteSetupDestination(dynamic ref) async {
  final storage = ref.read(settingsStorageProvider);
  final notificationCompleted = await storage
      .isNotificationPermissionIntroCompleted();
  if (!notificationCompleted) return '/paywall';
  final updatesCompleted = await storage.isUpdatesConsentIntroCompleted();
  if (!updatesCompleted) return '/updates-permission';
  return '/paywall';
}

Future<String> resolveStartupDestination(dynamic ref) async {
  final auth = await ref.read(authStateProvider.future);
  if (auth == null) {
    final guest = await ref.read(onboardingStorageProvider).load('guest');
    if (guest.completed || isOnboardingSurveyComplete(guest)) {
      return '/login';
    }
    return '/onboarding';
  }

  final prefs = await ref.read(onboardingPreferencesProvider.future);
  if (prefs.completed) return '/todo';
  if (!isOnboardingSurveyComplete(prefs)) return '/onboarding';
  if (await shouldShowOnboardingSetup(ref)) {
    return resolveIncompleteSetupDestination(ref);
  }
  return '/todo';
}

Future<String> resolvePostAuthDestination(dynamic ref) async {
  final prefs = await ref.read(onboardingPreferencesProvider.future);
  if (prefs.completed) return '/todo';
  if (!isOnboardingSurveyComplete(prefs)) return '/onboarding';
  if (await shouldShowOnboardingSetup(ref)) {
    return resolveIncompleteSetupDestination(ref);
  }
  return '/todo';
}

Future<void> navigateAfterAuth(BuildContext context, WidgetRef ref) async {
  if (ref.read(recentAuthIsNewUserProvider) == true) {
    await ref.read(onboardingLoginIntentStorageProvider).setFirstTimeSetup();
  }
  ref.invalidate(onboardingPreferencesProvider);
  await ref.read(onboardingPreferencesProvider.future);
  ref.invalidate(startupDestinationProvider);
  ref.invalidate(onboardingSetupRequiredProvider);
  final destination = await resolvePostAuthDestination(ref);
  if (context.mounted) context.go(destination);
}

Future<void> completeOnboardingSetupAndGoTodo(
  BuildContext context,
  dynamic ref,
) async {
  await ref.read(onboardingPreferencesProvider.notifier).completeOnboarding();
  await ref.read(onboardingLoginIntentStorageProvider).clear();
  ref.invalidate(onboardingPreferencesProvider);
  await ref.read(onboardingPreferencesProvider.future);
  ref.invalidate(startupDestinationProvider);
  ref.invalidate(onboardingSetupRequiredProvider);
  if (context.mounted) context.go('/todo');
}

Future<void> continueOnboardingSetupFromPaywall(
  BuildContext context,
  dynamic ref,
) async {
  final storage = ref.read(settingsStorageProvider);
  final notificationCompleted = await storage
      .isNotificationPermissionIntroCompleted();
  if (!context.mounted) return;
  if (!notificationCompleted) {
    context.go('/notification-permission');
    return;
  }
  final updatesCompleted = await storage.isUpdatesConsentIntroCompleted();
  if (!context.mounted) return;
  if (!updatesCompleted) {
    context.go('/updates-permission');
    return;
  }
  await completeOnboardingSetupAndGoTodo(context, ref);
}
