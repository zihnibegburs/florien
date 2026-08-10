import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/storage/adhd_settings_storage.dart';
import 'package:florien/core/widgets/florien_soft_overlay.dart';
import 'package:florien/core/theme/florien_theme.dart';

Future<void> showNotificationSettingsSheet(BuildContext context, WidgetRef ref) {
  return showFlorienBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _NotificationSettingsSheet(),
  );
}

class _NotificationSettingsSheet extends ConsumerWidget {
  const _NotificationSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final prefs = ref.watch(adhdPreferencesProvider).valueOrNull ?? const AdhdPreferences();
    final notifier = ref.read(adhdPreferencesProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.notificationSettings, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            SwitchListTile(
              title: Text(s.remind10Min),
              value: prefs.defaultRemind10Min,
              onChanged: (v) => notifier.patch((p) => p.copyWith(defaultRemind10Min: v)),
            ),
            SwitchListTile(
              title: Text(s.remind5Min),
              value: prefs.defaultRemind5Min,
              onChanged: (v) => notifier.patch((p) => p.copyWith(defaultRemind5Min: v)),
            ),
            SwitchListTile(
              title: Text(s.remind1Min),
              value: prefs.defaultRemind1Min,
              onChanged: (v) => notifier.patch((p) => p.copyWith(defaultRemind1Min: v)),
            ),
            SwitchListTile(
              title: Text(s.remindTransitionEnd),
              value: prefs.transitionAlerts,
              onChanged: (v) => notifier.patch((p) => p.copyWith(transitionAlerts: v)),
            ),
            SwitchListTile(
              title: Text(s.breakAfterFocus),
              value: prefs.breakAfterFocus,
              onChanged: (v) => notifier.patch((p) => p.copyWith(breakAfterFocus: v)),
            ),
            ListTile(
              title: Text(s.breakTime),
              subtitle: Text('${prefs.breakDurationMinutes} min'),
              trailing: DropdownButton<int>(
                value: prefs.breakDurationMinutes,
                items: [5, 10, 15, 20].map((m) => DropdownMenuItem(value: m, child: Text('$m'))).toList(),
                onChanged: (v) {
                  if (v != null) notifier.patch((p) => p.copyWith(breakDurationMinutes: v));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
