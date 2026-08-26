import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/services/home_screen_widget_service.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_card.dart';
import 'package:florien/features/todo/calendar_connections_screen.dart';
import 'package:florien/features/todo/notification_settings_screen.dart';
import 'package:florien/features/todo/live_activity_settings_screen.dart';
import 'package:florien/features/todo/profile_management_screen.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/premium/premium_membership_screen.dart';
import 'package:florien/core/services/store_review.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full settings page.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final language = ref.watch(appLanguageProvider).valueOrNull ?? strings.lang;
    final themeMode =
        ref.watch(appThemeModeProvider).valueOrNull ?? ThemeMode.system;
    final activeProfileName =
        ref.watch(activeAppProfileProvider)?.name ?? strings('Profilim');

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
                  strings('Ayarlar'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: FlorienSpacing.xxxl),
            Text(
              strings('Ayarlar'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: FlorienSpacing.lg),
            FlorienGroupedPanel(
              children: [
                _SettingsRow(
                  icon: Icons.workspace_premium_rounded,
                  label: strings('Florien Premium'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PremiumMembershipScreen(),
                    ),
                  ),
                ),
                _SettingsRow(
                  icon: Icons.notifications_none_rounded,
                  label: strings('Bildirimler'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  ),
                ),
                _SettingsRow(
                  icon: Icons.timelapse_rounded,
                  label: strings('Canlı Etkinlikler'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LiveActivitySettingsScreen(),
                    ),
                  ),
                ),
                _SettingsRow(
                  icon: Icons.calendar_month_outlined,
                  label: strings('Bağlı Takvimler'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CalendarConnectionsScreen(),
                    ),
                  ),
                ),
                _SettingsRow(
                  key: const ValueKey('settings-apple-health'),
                  icon: Icons.health_and_safety_outlined,
                  label: strings('Apple Sağlık'),
                  trailingLabel:
                      (ref.watch(appleHealthSyncEnabledProvider).valueOrNull ??
                          false)
                      ? strings('Bağlı')
                      : null,
                  onTap: () => _connectAppleHealth(context, ref),
                ),
                _SettingsRow(
                  icon: Icons.wb_sunny_outlined,
                  label: strings('Görünüm'),
                  trailingLabel: _themeLabel(strings, themeMode),
                  onTap: () => _showAppearanceSheet(context, ref, themeMode),
                ),
                _SettingsRow(
                  key: const ValueKey('settings-language'),
                  icon: Icons.translate_rounded,
                  label: strings('Dil'),
                  trailingLabel: _languageLabel(language),
                  onTap: () => _showLanguageSheet(context, ref, language),
                ),
                _SettingsRow(
                  key: const ValueKey('settings-rate-us'),
                  icon: Icons.star_outline_rounded,
                  label: strings('Bizi değerlendirin'),
                  onTap: () => _rateFlorien(context),
                ),
              ],
            ),
            const SizedBox(height: FlorienSpacing.xxxl),
            Text(
              strings('Profil'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: FlorienSpacing.lg),
            FlorienGroupedPanel(
              children: [
                _SettingsRow(
                  key: const ValueKey('settings-profile-switcher'),
                  icon: Icons.switch_account_outlined,
                  label: activeProfileName,
                  trailingLabel: strings('Değiştir'),
                  onTap: () => showProfileSwitcher(context, ref),
                ),
                _SettingsRow(
                  icon: Icons.person_add_alt_1_outlined,
                  label: strings('Yeni profil ekle'),
                  onTap: () => _openProfiles(context),
                ),
                _SettingsRow(
                  icon: Icons.person_outline_rounded,
                  label: strings('Profil adını düzenle'),
                  onTap: () => _openProfiles(context),
                ),
              ],
            ),
            const SizedBox(height: FlorienSpacing.xxxl),
            Text(
              strings('Hesap ve abonelik'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: FlorienSpacing.lg),
            FlorienGroupedPanel(
              children: [
                _SettingsRow(
                  icon: Icons.restart_alt_rounded,
                  label: strings('Satın alımı geri yükle'),
                ),
                _SettingsRow(
                  icon: Icons.logout_rounded,
                  label: strings('Çıkış yap'),
                  onTap: () => _confirmLogout(context, ref),
                ),
                _SettingsRow(
                  icon: Icons.delete_outline_rounded,
                  label: strings('Hesabı sil'),
                  onTap: () => _confirmDeleteAccount(context, ref),
                ),
              ],
            ),
            const SizedBox(height: FlorienSpacing.xxxl),
            Text(
              strings('Yasal'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: FlorienSpacing.lg),
            FlorienGroupedPanel(
              children: [
                _SettingsRow(
                  key: const ValueKey('settings-terms'),
                  icon: Icons.description_outlined,
                  label: strings('Hizmet şartları'),
                  onTap: () => _openLegalUrl(
                    context,
                    'https://www.wirefire.co/florien/terms',
                  ),
                ),
                _SettingsRow(
                  key: const ValueKey('settings-privacy'),
                  icon: Icons.privacy_tip_outlined,
                  label: strings('Gizlilik politikası'),
                  onTap: () => _openLegalUrl(
                    context,
                    'https://www.wirefire.co/florien/privacy',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _themeLabel(S strings, ThemeMode mode) => switch (mode) {
    ThemeMode.light => strings('Aydınlık'),
    ThemeMode.dark => strings('Karanlık'),
    ThemeMode.system => strings('Sistem'),
  };

  static String _languageLabel(String code) {
    final match = supportedLanguageOptions.where((item) => item.code == code);
    return match.isEmpty ? code : match.first.nativeName;
  }

  Future<void> _rateFlorien(BuildContext context) async {
    final opened = await openFlorienStoreReview();
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n('Mağaza şu anda açılamadı. Lütfen tekrar dene.'),
        ),
      ),
    );
  }

  Future<void> _openLegalUrl(BuildContext context, String url) async {
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;
    } catch (_) {}
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n('Sayfa açılamadı.'))));
  }

  void _openProfiles(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileManagementScreen()));
  }

  Future<void> _connectAppleHealth(BuildContext context, WidgetRef ref) async {
    final connected = await ref
        .read(moodEntriesProvider.notifier)
        .connectAppleHealth();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          connected
              ? context.l10n(
                  'Apple Sağlık bağlandı. Bu haftanın ruh halleri eşitlendi.',
                )
              : context.l10n(
                  'Apple Sağlık izni verilmedi veya bu iPhone desteklenmiyor.',
                ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final approved = await _confirmAction(
      context,
      title: context.l10n('Çıkış yapılsın mı?'),
      message: context.l10n('Hesabından çıkış yapacaksın.'),
      actionLabel: context.l10n('Çıkış yap'),
    );
    if (approved != true) return;
    await ref.read(authStateProvider.notifier).logout();
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final approved = await _confirmAction(
      context,
      title: context.l10n('Hesap silinsin mi?'),
      message: context.l10n(
        'Hesabın ve buluttaki görevlerin kalıcı olarak silinecek.',
      ),
      actionLabel: context.l10n('Hesabı sil'),
      destructive: true,
    );
    if (approved != true || !context.mounted) return;

    try {
      await ref.read(authStateProvider.notifier).deleteAccount();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n('Hesap silinemedi: {error}', {'error': '$error'}),
          ),
        ),
      );
    }
  }

  Future<bool?> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
    bool destructive = false,
  }) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(context.l10n('Vazgeç')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: context.palette.error)
              : null,
          child: Text(actionLabel),
        ),
      ],
    ),
  );

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
              color: context.palette.background,
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
                  context.l10n('Görünüm'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _AppearanceChoice(
                  label: context.l10n('Aydınlık mod'),
                  selected: current == ThemeMode.light,
                  onTap: () => Navigator.pop(context, ThemeMode.light),
                ),
                const SizedBox(height: 10),
                _AppearanceChoice(
                  label: context.l10n('Karanlık mod'),
                  selected: current == ThemeMode.dark,
                  onTap: () => Navigator.pop(context, ThemeMode.dark),
                ),
                const SizedBox(height: 10),
                _AppearanceChoice(
                  label: context.l10n('Sistem'),
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

  Future<void> _showLanguageSheet(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: context.palette.background,
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
                  context.l10n('Dili seç'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _AppearanceChoice(
                        label: context.l10n('Telefon dili'),
                        selected: false,
                        onTap: () => Navigator.pop(context, ''),
                      ),
                      const SizedBox(height: 10),
                      for (final option in supportedLanguageOptions) ...[
                        _AppearanceChoice(
                          label: option.nativeName,
                          selected: option.code == current,
                          onTap: () => Navigator.pop(context, option.code),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !context.mounted) return;
    await ref
        .read(appLanguageProvider.notifier)
        .setLanguage(selected.isEmpty ? null : selected);
    await HomeScreenWidgetService.syncChrome();
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
      color: selected
          ? context.palette.selection
          : context.palette.surfaceMuted,
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
    super.key,
    required this.icon,
    required this.label,
    this.trailingLabel,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? trailingLabel;
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
