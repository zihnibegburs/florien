import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/core/l10n/app_strings.dart';

class LiveActivitySettingsScreen extends ConsumerWidget {
  const LiveActivitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(liveActivityPreferencesProvider);
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(context.l10n('Canlı Etkinlikler'))),
      body: preferences.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            Center(child: Text(context.l10n('Ayarlar yüklenemedi.'))),
        data: (value) => ListView(
          padding: const EdgeInsets.all(FlorienSpacing.screen),
          children: [
            Text(
              context.l10n(
                'Kilit ekranında ve Dynamic Island’da odak sayacını göster.',
              ),
              style: TextStyle(color: context.palette.textSecondary),
            ),
            const SizedBox(height: FlorienSpacing.lg),
            _LiveActivityTile(
              icon: Icons.timelapse_rounded,
              title: context.l10n('Odak sayacı'),
              subtitle: context.l10n('Aktif odak turunun kalan süresi.'),
              value: value.focusTimerEnabled,
              onChanged: (enabled) =>
                  _save(ref, value.copyWith(focusTimerEnabled: enabled)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(WidgetRef ref, LiveActivityPreferences value) async {
    await ref.read(settingsStorageProvider).setLiveActivityPreferences(value);
    await ref.read(liveActivityServiceProvider).applyPreferences(value);
    ref.invalidate(liveActivityPreferencesProvider);
  }
}

class _LiveActivityTile extends StatelessWidget {
  const _LiveActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.palette.background,
      borderRadius: BorderRadius.circular(FlorienRadius.lg),
      border: Border.all(
        color: context.palette.border,
        width: FlorienBorders.thin,
      ),
    ),
    child: SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    ),
  );
}
