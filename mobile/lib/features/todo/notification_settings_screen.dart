import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:florien/core/services/task_alarm_service.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_card.dart';
import 'package:florien/features/providers.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  bool _saving = false;
  FlorienOsNotificationPermission _osPermission =
      FlorienOsNotificationPermission.unknown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPermission());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshPermission(reschedule: true));
    }
  }

  Future<void> _refreshPermission({bool reschedule = false}) async {
    final alarms = ref.read(taskAlarmServiceProvider);
    final status = await alarms.osNotificationPermission();
    if (!mounted) return;
    setState(() => _osPermission = status);
    if (reschedule && status == FlorienOsNotificationPermission.granted) {
      await ref.read(notificationReconcileProvider)();
    }
  }

  Future<void> _requestOsPermission() async {
    final granted = await ref
        .read(taskAlarmServiceProvider)
        .requestOsPermission();
    if (!mounted) return;
    await _refreshPermission(reschedule: granted);
  }

  Future<void> _persist(
    NotificationPreferences Function(NotificationPreferences) update,
  ) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final alarms = ref.read(taskAlarmServiceProvider);
      final current = await alarms.getPreferences();
      final previousLead = current.taskReminderLeadMinutes;
      final next = update(current);
      await alarms.savePreferences(next);
      ref.invalidate(notificationPreferencesProvider);
      await ref.read(notificationReconcileProvider)(
        previousDefaultLeadMinutes:
            previousLead == next.taskReminderLeadMinutes ? null : previousLead,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kaydedildi'),
          duration: Duration(milliseconds: 1200),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bildirim ayarı kaydedilemedi: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime({
    required TimeOfDay initial,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final value = await showTimePicker(context: context, initialTime: initial);
    if (value != null) onPicked(value);
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(notificationPreferencesProvider);
    final permissionBlocked =
        _osPermission == FlorienOsNotificationPermission.denied ||
        _osPermission == FlorienOsNotificationPermission.notDetermined;

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
            if (permissionBlocked) ...[
              const SizedBox(height: FlorienSpacing.xl),
              _PermissionDeniedCard(
                needsInAppPrompt:
                    _osPermission ==
                    FlorienOsNotificationPermission.notDetermined,
                onAllow: () => unawaited(_requestOsPermission()),
                onOpenSettings: () async {
                  await ref
                      .read(taskAlarmServiceProvider)
                      .openSystemNotificationSettings();
                },
              ),
            ],
            const SizedBox(height: FlorienSpacing.xxxl),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bildirim türleri',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: FlorienSpacing.lg),
                  FlorienGroupedPanel(
                    children: [
                      _TypeTile(
                        icon: Icons.notifications_active_outlined,
                        title: 'Görev hatırlatması',
                        subtitle: _leadLabel(value.taskReminderLeadMinutes),
                        enabled: value.taskRemindersEnabled,
                        interactive: !_saving,
                        onEnabledChanged: (enabled) => _persist(
                          (current) =>
                              current.copyWith(taskRemindersEnabled: enabled),
                        ),
                        trailing: _LeadPicker(
                          value: value.taskReminderLeadMinutes,
                          enabled: value.taskRemindersEnabled && !_saving,
                          onChanged: (minutes) => _persist(
                            (current) => current.copyWith(
                              taskReminderLeadMinutes: minutes,
                            ),
                          ),
                        ),
                      ),
                      _TypeTile(
                        icon: Icons.wb_sunny_outlined,
                        title: 'Sabah plan özeti',
                        subtitle: _formatTime(value.morningSummaryTime),
                        enabled: value.morningSummaryEnabled,
                        interactive: !_saving,
                        onEnabledChanged: (enabled) => _persist(
                          (current) =>
                              current.copyWith(morningSummaryEnabled: enabled),
                        ),
                        trailing: _TimeButton(
                          label: _formatTime(value.morningSummaryTime),
                          enabled: value.morningSummaryEnabled && !_saving,
                          onTap: () => _pickTime(
                            initial: value.morningSummaryTime,
                            onPicked: (time) => _persist(
                              (current) => current.copyWith(
                                morningSummaryMinutes:
                                    NotificationPreferences.minutesFromTime(
                                      time,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _TypeTile(
                        icon: Icons.favorite_outline_rounded,
                        title: 'Motivasyon',
                        subtitle:
                            'Salı ve perşembe · ${_formatTime(value.motivationTime)}',
                        enabled: value.motivationEnabled,
                        interactive: !_saving,
                        onEnabledChanged: (enabled) => _persist(
                          (current) =>
                              current.copyWith(motivationEnabled: enabled),
                        ),
                        trailing: _TimeButton(
                          label: _formatTime(value.motivationTime),
                          enabled: value.motivationEnabled && !_saving,
                          onTap: () => _pickTime(
                            initial: value.motivationTime,
                            onPicked: (time) => _persist(
                              (current) => current.copyWith(
                                motivationMinutes:
                                    NotificationPreferences.minutesFromTime(
                                      time,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _TypeTile(
                        icon: Icons.nightlight_round,
                        title: 'Günlük değerlendirme',
                        subtitle: _formatTime(value.dailyReviewTime),
                        enabled: value.dailyReviewEnabled,
                        interactive: !_saving,
                        onEnabledChanged: (enabled) => _persist(
                          (current) =>
                              current.copyWith(dailyReviewEnabled: enabled),
                        ),
                        trailing: _TimeButton(
                          label: _formatTime(value.dailyReviewTime),
                          enabled: value.dailyReviewEnabled && !_saving,
                          onTap: () => _pickTime(
                            initial: value.dailyReviewTime,
                            onPicked: (time) => _persist(
                              (current) => current.copyWith(
                                dailyReviewMinutes:
                                    NotificationPreferences.minutesFromTime(
                                      time,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _TypeTile(
                        icon: Icons.calendar_view_week_rounded,
                        title: 'Haftalık değerlendirme',
                        subtitle:
                            'Pazar · ${_formatTime(value.weeklyReviewTime)}',
                        enabled: value.weeklyReviewEnabled,
                        interactive: !_saving,
                        onEnabledChanged: (enabled) => _persist(
                          (current) =>
                              current.copyWith(weeklyReviewEnabled: enabled),
                        ),
                        trailing: _TimeButton(
                          label: _formatTime(value.weeklyReviewTime),
                          enabled: value.weeklyReviewEnabled && !_saving,
                          onTap: () => _pickTime(
                            initial: value.weeklyReviewTime,
                            onPicked: (time) => _persist(
                              (current) => current.copyWith(
                                weeklyReviewMinutes:
                                    NotificationPreferences.minutesFromTime(
                                      time,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FlorienSpacing.xxxl),
                  Text(
                    'Sessiz saatler',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bu aralıkta genel bildirimler sessiz saat bitimine ertelenir. Saatli görev hatırlatmaları etkilenmez.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: FlorienSpacing.lg),
                  FlorienGroupedPanel(
                    children: [
                      _TypeTile(
                    icon: Icons.do_not_disturb_on_outlined,
                    title: 'Sessiz saatler',
                    subtitle:
                        '${_formatTime(value.quietHoursStart)} – ${_formatTime(value.quietHoursEnd)}',
                    enabled: value.quietHoursEnabled,
                    interactive: !_saving,
                    onEnabledChanged: (enabled) => _persist(
                      (current) =>
                          current.copyWith(quietHoursEnabled: enabled),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TimeButton(
                          label: _formatTime(value.quietHoursStart),
                          enabled: value.quietHoursEnabled && !_saving,
                          onTap: () => _pickTime(
                            initial: value.quietHoursStart,
                            onPicked: (time) => _persist(
                              (current) => current.copyWith(
                                quietHoursStartMinutes:
                                    NotificationPreferences.minutesFromTime(
                                      time,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _TimeButton(
                          label: _formatTime(value.quietHoursEnd),
                          enabled: value.quietHoursEnabled && !_saving,
                          onTap: () => _pickTime(
                            initial: value.quietHoursEnd,
                            onPicked: (time) => _persist(
                              (current) => current.copyWith(
                                quietHoursEndMinutes:
                                    NotificationPreferences.minutesFromTime(
                                      time,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                      ),
                    ],
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

String _formatTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour.$minute';
}

String _leadLabel(int minutes) {
  if (minutes <= 0) return 'Tam başlangıçta';
  return '$minutes dakika önce';
}

class _PermissionDeniedCard extends StatelessWidget {
  const _PermissionDeniedCard({
    required this.needsInAppPrompt,
    required this.onAllow,
    required this.onOpenSettings,
  });

  final bool needsInAppPrompt;
  final VoidCallback onAllow;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FlorienSpacing.md),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(FlorienRadius.lg),
        border: Border.all(
          color: context.palette.border,
          width: FlorienBorders.thin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bildirim izni kapalı',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            needsInAppPrompt
                ? 'Hatırlatmalar için Florien’e bildirim izni vermen gerekiyor.'
                : 'Ayarlar → Bildirimler → Florien yolundan izin ver.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: FlorienSpacing.md),
          FilledButton.icon(
            onPressed: needsInAppPrompt ? onAllow : onOpenSettings,
            icon: Icon(
              needsInAppPrompt
                  ? Icons.notifications_active_outlined
                  : Icons.settings_rounded,
            ),
            label: Text(
              needsInAppPrompt
                  ? 'İzin ver'
                  : 'Florien bildirim ayarlarını aç',
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.interactive,
    required this.onEnabledChanged,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool interactive;
  final ValueChanged<bool> onEnabledChanged;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final active = enabled;
    return Opacity(
      opacity: active ? 1 : 0.72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, size: 27, color: context.palette.textPrimary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
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
                Switch.adaptive(
                  value: enabled,
                  onChanged: interactive ? onEnabledChanged : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: trailing),
          ],
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? onTap : null,
      child: Text(label),
    );
  }
}

class _LeadPicker extends StatelessWidget {
  const _LeadPicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: taskReminderLeadOptions.contains(value) ? value : 10,
        isDense: true,
        onChanged: enabled
            ? (next) {
                if (next != null) onChanged(next);
              }
            : null,
        items: [
          for (final minutes in taskReminderLeadOptions)
            DropdownMenuItem(
              value: minutes,
              child: Text(_leadLabel(minutes)),
            ),
        ],
      ),
    );
  }
}
