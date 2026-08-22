import 'dart:async';

import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationPermissionScreen extends ConsumerStatefulWidget {
  const NotificationPermissionScreen({super.key, required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  ConsumerState<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends ConsumerState<NotificationPermissionScreen> {
  bool _requesting = false;
  String? _error;

  Future<void> _allow() async {
    if (_requesting) return;
    setState(() {
      _requesting = true;
      _error = null;
    });
    try {
      final granted = await ref
          .read(taskAlarmServiceProvider)
          .enableDefaultsAfterPermissionGrant();
      if (granted) {
        ref.invalidate(notificationPreferencesProvider);
        unawaited(ref.read(notificationReconcileProvider)());
      }
      await _finish();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _requesting = false;
        _error = ref.read(stringsProvider).notificationPermissionError;
      });
    }
  }

  Future<void> _skip() async {
    if (_requesting) return;
    // Do not re-prompt; leave type preferences untouched except task reminders off
    // for users who explicitly skip the intro.
    await ref.read(settingsStorageProvider).setTaskRemindersEnabled(false);
    await _finish();
  }

  Future<void> _finish() async {
    await ref
        .read(settingsStorageProvider)
        .markNotificationPermissionIntroCompleted();
    if (!mounted) return;
    setState(() => _requesting = false);
    await widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return Scaffold(
      key: const ValueKey('notification-permission-screen'),
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(FlorienSpacing.screen),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.palette.primaryMuted,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '1 / 2',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: FlorienSpacing.sm),
                  Semantics(
                    image: true,
                    label: strings.notificationIntroTitle,
                    child: Image.asset(
                      'assets/onboarding/perm-01-reminder-illustration.png',
                      key: const ValueKey('reminder-permission-illustration'),
                      height: 280,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: FlorienSpacing.lg),
                  Text(
                    strings.notificationIntroTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: FlorienSpacing.md),
                  Text(
                    strings.notificationIntroDescription,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.palette.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: FlorienSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(FlorienSpacing.md),
                    decoration: BoxDecoration(
                      color: context.palette.primaryMuted,
                      borderRadius: BorderRadius.circular(FlorienRadius.md),
                      border: Border.all(color: context.palette.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            strings.notificationIntroPrivacy,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: FlorienSpacing.md),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.palette.error),
                    ),
                  ],
                  const SizedBox(height: FlorienSpacing.xxxl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('allow-notifications'),
                      onPressed: _requesting ? null : _allow,
                      icon: _requesting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.notifications_rounded),
                      label: Text(strings.allowNotifications),
                    ),
                  ),
                  const SizedBox(height: FlorienSpacing.sm),
                  TextButton(
                    key: const ValueKey('skip-notifications'),
                    onPressed: _requesting ? null : _skip,
                    child: Text(strings.skipForNow),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
