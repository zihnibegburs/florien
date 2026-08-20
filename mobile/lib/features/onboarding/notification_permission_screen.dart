import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationPermissionScreen extends ConsumerStatefulWidget {
  const NotificationPermissionScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

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
      await ref.read(taskAlarmServiceProvider).setTaskRemindersEnabled(true);
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
    await ref.read(settingsStorageProvider).setTaskRemindersEnabled(false);
    await _finish();
  }

  Future<void> _finish() async {
    await ref
        .read(settingsStorageProvider)
        .markNotificationPermissionIntroCompleted();
    if (!mounted) return;
    setState(() => _requesting = false);
    widget.onComplete();
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
                  Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      color: context.palette.aiSurface,
                      borderRadius: BorderRadius.circular(FlorienRadius.xxl),
                      border: Border.all(
                        color: context.palette.border,
                        width: FlorienBorders.thin,
                      ),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      size: 62,
                    ),
                  ),
                  const SizedBox(height: FlorienSpacing.xxxl),
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
                      color: context.palette.surfaceMuted,
                      borderRadius: BorderRadius.circular(FlorienRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 20),
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
