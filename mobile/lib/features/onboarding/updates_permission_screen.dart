import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UpdatesPermissionScreen extends ConsumerStatefulWidget {
  const UpdatesPermissionScreen({super.key, required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  ConsumerState<UpdatesPermissionScreen> createState() =>
      _UpdatesPermissionScreenState();
}

class _UpdatesPermissionScreenState
    extends ConsumerState<UpdatesPermissionScreen> {
  bool _saving = false;

  Future<void> _finish(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref.read(settingsStorageProvider).setMarketingUpdatesEnabled(enabled);
    if (!mounted) return;
    setState(() => _saving = false);
    await widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return Scaffold(
      key: const ValueKey('updates-permission-screen'),
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
                        '2 / 2',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: FlorienSpacing.sm),
                  Semantics(
                    image: true,
                    label: strings.updatesIntroTitle,
                    child: Image.asset(
                      'assets/onboarding/onb-01-updates-illustration.png',
                      key: const ValueKey('updates-permission-illustration'),
                      height: 280,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: FlorienSpacing.lg),
                  Text(
                    strings.updatesIntroTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: FlorienSpacing.md),
                  Text(
                    strings.updatesIntroDescription,
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
                        const Icon(Icons.favorite_border_rounded, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            strings.updatesIntroPrivacy,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FlorienSpacing.xxxl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('allow-updates'),
                      onPressed: _saving ? null : () => _finish(true),
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.mark_email_read_outlined),
                      label: Text(strings.allowUpdates),
                    ),
                  ),
                  const SizedBox(height: FlorienSpacing.sm),
                  TextButton(
                    key: const ValueKey('decline-updates'),
                    onPressed: _saving ? null : () => _finish(false),
                    child: Text(strings.declineUpdates),
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
