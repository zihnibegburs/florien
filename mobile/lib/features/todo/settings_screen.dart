import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/theme/florien_theme.dart';

/// Full settings page. Only [Görünüm] is interactive.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(appThemeModeProvider).valueOrNull ?? ThemeMode.system;

    return Scaffold(
      key: const ValueKey('settings-screen'),
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
                const SizedBox(width: 12),
                Icon(
                  Icons.settings_outlined,
                  size: 26,
                  color: context.palette.textPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ayarlar',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: FlorienSpacing.xxxl),
            Text(
              'Ayarlar',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: FlorienSpacing.lg),
            const _SettingsRow(
              icon: Icons.notifications_none_rounded,
              label: 'Bildirimler',
            ),
            const _SettingsRow(
              icon: Icons.calendar_month_outlined,
              label: 'Bağlı Takvimler',
            ),
            const _SettingsRow(
              icon: Icons.format_list_bulleted_rounded,
              label: 'Hatırlatıcı içe aktar',
              locked: true,
            ),
            const _SettingsRow(
              icon: Icons.circle_outlined,
              label: 'Tema',
            ),
            _SettingsRow(
              icon: Icons.wb_sunny_outlined,
              label: 'Görünüm',
              trailingLabel: _themeLabel(themeMode),
              onTap: () => _showAppearanceSheet(context, ref, themeMode),
            ),
            const _SettingsRow(
              icon: Icons.text_fields_rounded,
              label: 'Yazı tipi ayarları',
            ),
            const _SettingsRow(
              icon: Icons.music_note_outlined,
              label: 'Sesler',
            ),
            const _SettingsRow(
              icon: Icons.apps_rounded,
              label: 'Uygulama simgesi',
            ),
            const SizedBox(height: FlorienSpacing.xxxl),
            Text(
              'Profil',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: FlorienSpacing.lg),
            const _SettingsRow(
              icon: Icons.person_add_alt_1_outlined,
              label: 'Yeni profil ekle',
              locked: true,
            ),
            const _SettingsRow(
              icon: Icons.person_outline_rounded,
              label: 'Profil adını düzenle',
            ),
            const SizedBox(height: FlorienSpacing.xxxl),
            Text(
              'Hesap ve abonelik',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: FlorienSpacing.lg),
            const _SettingsRow(
              icon: Icons.restart_alt_rounded,
              label: 'Satın alımı geri yükle',
            ),
          ],
        ),
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Aydınlık',
    ThemeMode.dark => 'Karanlık',
    ThemeMode.system => 'Sistem',
  };

  Future<void> _showAppearanceSheet(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(FlorienRadius.xl),
              border: Border.all(
                color: context.palette.border,
                width: FlorienBorders.thin,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.palette.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Görünüm',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _AppearanceChoice(
                  label: 'Aydınlık mod',
                  selected: current == ThemeMode.light,
                  onTap: () => Navigator.pop(context, ThemeMode.light),
                ),
                const SizedBox(height: 10),
                _AppearanceChoice(
                  label: 'Karanlık mod',
                  selected: current == ThemeMode.dark,
                  onTap: () => Navigator.pop(context, ThemeMode.dark),
                ),
                const SizedBox(height: 10),
                _AppearanceChoice(
                  label: 'Sistem',
                  selected: current == ThemeMode.system,
                  onTap: () => Navigator.pop(context, ThemeMode.system),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !context.mounted) return;
    await ref.read(appThemeModeProvider.notifier).setThemeMode(selected);
  }
}

class _AppearanceChoice extends StatelessWidget {
  const _AppearanceChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FlorienColors.primary : context.palette.surfaceMuted,
      borderRadius: BorderRadius.circular(FlorienRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FlorienRadius.pill),
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FlorienRadius.pill),
            border: Border.all(
              color: context.palette.border,
              width: FlorienBorders.thin,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: selected
                  ? FlorienColors.onPrimary
                  : context.palette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.trailingLabel,
    this.locked = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? trailingLabel;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final interactive = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FlorienRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 24, color: context.palette.textPrimary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (locked)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: FlorienColors.aiAccent,
                  ),
                ),
              if (trailingLabel != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    trailingLabel!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.palette.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (interactive)
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.palette.textSecondary,
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.palette.textSecondary.withValues(alpha: 0.55),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
