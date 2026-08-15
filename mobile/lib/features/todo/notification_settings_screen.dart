import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _updating = false;

  Future<void> _setReminders(bool enabled) async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      final isEnabled = await ref
          .read(taskAlarmServiceProvider)
          .setTaskRemindersEnabled(enabled);
      ref.invalidate(notificationPreferencesProvider);
      if (enabled && !isEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bildirim izni verilmedi. Cihaz ayarlarından izin verebilirsin.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bildirim ayarı güncellenemedi: $error')),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _setSound(bool enabled) async {
    await ref.read(taskAlarmServiceProvider).setSoundEnabled(enabled);
    ref.invalidate(notificationPreferencesProvider);
  }

  Future<void> _setVibration(bool enabled) async {
    await ref.read(taskAlarmServiceProvider).setVibrationEnabled(enabled);
    ref.invalidate(notificationPreferencesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      key: const ValueKey('notification-settings-screen'),
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            FlorienSpacing.screen,
            FlorienSpacing.md,
            FlorienSpacing.screen,
            FlorienSpacing.huge,
          ),
          children: [
            Row(
              children: [
                Material(
                  color: context.palette.surface,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: context.palette.border,
                      width: FlorienBorders.thin,
                    ),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox.square(
                      dimension: 40,
                      child: Icon(Icons.chevron_left_rounded, size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Bildirimler',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: FlorienSpacing.xxxl),
            Text(
              'Görev hatırlatıcıları',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Planladığın görevlerin zamanı geldiğinde haber verelim.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: FlorienSpacing.lg),
            preferences.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, _) => Text(
                'Bildirim ayarları yüklenemedi.',
                style: TextStyle(color: context.palette.error),
              ),
              data: (value) => Column(
                children: [
                  _NotificationSettingTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Görev hatırlatıcıları',
                    subtitle: 'Zamanı gelen görevler için bildirim gönder.',
                    value: value.taskRemindersEnabled,
                    enabled: !_updating,
                    onChanged: _setReminders,
                  ),
                  const SizedBox(height: FlorienSpacing.sm),
                  _NotificationSettingTile(
                    icon: Icons.volume_up_outlined,
                    title: 'Bildirim sesi',
                    subtitle: 'Yeni görev alarmında ses çal.',
                    value: value.soundEnabled,
                    enabled: value.taskRemindersEnabled && !_updating,
                    onChanged: _setSound,
                  ),
                  const SizedBox(height: FlorienSpacing.sm),
                  _NotificationSettingTile(
                    icon: Icons.vibration_rounded,
                    title: 'Titreşim',
                    subtitle: 'Yeni görev alarmında titreşim kullan.',
                    value: value.vibrationEnabled,
                    enabled: value.taskRemindersEnabled && !_updating,
                    onChanged: _setVibration,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationSettingTile extends StatelessWidget {
  const _NotificationSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: BoxDecoration(
        color: enabled ? context.palette.surface : context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(FlorienRadius.lg),
        border: Border.all(
          color: context.palette.border,
          width: FlorienBorders.thin,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 27, color: context.palette.textPrimary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}
