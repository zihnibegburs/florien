import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/storage/adhd_settings_storage.dart';
import 'package:florien/features/profile/focus_blocking_sheet.dart';
import 'package:florien/features/profile/notification_settings_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/achievement.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/achievements/achievements_screen.dart';
import 'package:florien/features/providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  String? _selectedColor;
  bool _editing = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startEditing(String displayName, String avatarColor) {
    _nameController.text = displayName;
    setState(() {
      _selectedColor = avatarColor;
      _editing = true;
      _error = null;
    });
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(authStateProvider.notifier).updateProfile(
            displayName: name,
            avatarColor: _selectedColor,
          );
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(stringsProvider).profileUpdated)),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider).value;
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(appLanguageProvider).valueOrNull ?? 'tr';
    final themeMode = ref.watch(appThemeModeProvider).valueOrNull ?? ThemeMode.system;
    final palette = context.palette;
    final stats = ref.watch(achievementStatsProvider).valueOrNull ?? const AchievementStats();
    final unlockedCount = achievementDefinitions.where((a) => a.isUnlocked(stats)).length;

    if (auth == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final avatarColor = FlorienColors.fromHex(_editing ? (_selectedColor ?? auth.avatarColor) : auth.avatarColor);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(s.profile),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: avatarColor,
                  child: Text(
                    auth.displayName.isNotEmpty ? auth.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  auth.displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  auth.email,
                  style: TextStyle(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _SectionHeader(title: s.account),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(s.editProfile),
            trailing: Icon(_editing ? Icons.expand_less : Icons.chevron_right_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: palette.surface,
            onTap: () {
              if (_editing) {
                setState(() => _editing = false);
              } else {
                _startEditing(auth.displayName, auth.avatarColor);
              }
            },
          ),
          if (_editing) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.displayName, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(hintText: s.displayName),
                  ),
                  const SizedBox(height: 16),
                  Text(s.avatarColor, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: FlorienColors.taskColors.map((hex) {
                      final color = FlorienColors.fromHex(hex);
                      final selected = (_selectedColor ?? auth.avatarColor) == hex;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = hex),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: selected ? Border.all(color: palette.textPrimary, width: 3) : null,
                          ),
                          child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveProfile,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(s.save),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          _SectionHeader(title: s.achievementsTitle),
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FlorienColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded, color: FlorienColors.primary),
              ),
              title: Text(s.achievementsTitle),
              subtitle: Text(s.achievementsProfileSubtitle, style: const TextStyle(fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: FlorienColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unlockedCount/${achievementDefinitions.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: FlorienColors.primary,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              onTap: () => context.push('/achievements'),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: s.integrations),
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: ListTile(
              leading: const Icon(Icons.calendar_month_rounded, color: FlorienColors.primary),
              title: Text(s.calendarImport),
              subtitle: Text(s.calendarImportSubtitle, style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/calendar-import'),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: s.preferences),
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.bolt_rounded, color: FlorienColors.primary),
                  title: Text(s.dailyEnergy),
                  trailing: DropdownButton<EnergyLevel?>(
                    value: ref.watch(adhdPreferencesProvider).valueOrNull?.dailyEnergyLevel,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(value: null, child: Text(s.cancel)),
                      ...EnergyLevel.values.map((e) => DropdownMenuItem(value: e, child: Text(s.energyLabel(e)))),
                    ],
                    onChanged: (v) => ref.read(adhdPreferencesProvider.notifier).patch(
                          (p) => v == null ? p.copyWith(clearDailyEnergy: true) : p.copyWith(dailyEnergyLevel: v),
                        ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(s.language),
                  subtitle: Text(s.languageName(lang)),
                  trailing: DropdownButton<String>(
                    value: lang,
                    underline: const SizedBox.shrink(),
                    items: supportedLanguageCodes
                        .map((code) => DropdownMenuItem(value: code, child: Text(s.languageName(code))))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(appLanguageProvider.notifier).setLanguage(value);
                      }
                    },
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(s.appearance),
                  subtitle: Text(s.themeModeLabel(preferenceFromThemeMode(themeMode))),
                  trailing: DropdownButton<ThemeMode>(
                    value: themeMode,
                    underline: const SizedBox.shrink(),
                    items: ThemeMode.values
                        .map(
                          (mode) => DropdownMenuItem(
                            value: mode,
                            child: Text(s.themeModeLabel(preferenceFromThemeMode(mode))),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(appThemeModeProvider.notifier).setThemeMode(value);
                      }
                    },
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(s.notifications),
                  subtitle: Text(s.notificationSettings, style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showNotificationSettingsSheet(context, ref),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.do_not_disturb_on_rounded),
                  title: Text(s.focusBlocking),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showFocusBlockingSheet(context, ref),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.insights_rounded),
                  title: Text(s.weeklyRetro),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/weekly-retro'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: Colors.red.shade400),
            title: Text(s.logout, style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: palette.surface,
            onTap: () => ref.read(authStateProvider.notifier).logout(),
          ),
          const SizedBox(height: 32),
          Text(
            '${s.version} 1.0.0',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: palette.textSecondary,
        ),
      ),
    );
  }
}
