import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/storage/profile_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/premium/premium_gate.dart';
import 'package:florien/features/premium/premium_membership.dart';

class ProfileManagementScreen extends ConsumerStatefulWidget {
  const ProfileManagementScreen({super.key});

  @override
  ConsumerState<ProfileManagementScreen> createState() =>
      _ProfileManagementScreenState();
}

class _ProfileManagementScreenState
    extends ConsumerState<ProfileManagementScreen> {
  bool _saving = false;

  Future<void> _addProfile() async {
    if (!await requirePremiumAccess(
      context,
      ref,
      PremiumFeature.multipleProfiles,
    )) {
      return;
    }
    if (!mounted) return;
    final name = await _askForName(title: 'Yeni profil');
    if (name == null) return;
    await _perform(() => ref.read(appProfilesProvider.notifier).create(name));
  }

  Future<void> _renameProfile(AppProfile profile) async {
    final name = await _askForName(
      title: 'Profil adını düzenle',
      initialValue: profile.name,
    );
    if (name == null) return;
    await _perform(
      () => ref.read(appProfilesProvider.notifier).rename(profile.id, name),
    );
  }

  Future<void> _deleteProfile(AppProfile profile) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profili sil?'),
        content: Text('${profile.name} profili silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.error,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    await _perform(
      () => ref.read(appProfilesProvider.notifier).delete(profile.id),
    );
  }

  Future<String?> _askForName({
    required String title,
    String initialValue = '',
  }) async {
    var profileName = initialValue;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initialValue,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Profil adı',
            labelStyle: TextStyle(color: dialogContext.palette.textSecondary),
            floatingLabelStyle: TextStyle(
              color: dialogContext.palette.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          onChanged: (value) => profileName = value,
          onFieldSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(profileName),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    final trimmed = result?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _perform(Future<void> Function() operation) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await operation();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(appProfilesProvider);
    final isPremium = ref.watch(
      premiumMembershipProvider.select(
        (membership) => membership.valueOrNull?.hasActivePremium == true,
      ),
    );

    return Scaffold(
      key: const ValueKey('profile-management-screen'),
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
                  'Profiller',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: FlorienSpacing.xxxl),
            Text(
              'Profillerin',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Aynı uygulamada farklı profiller arasında geçiş yapabilirsin.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: FlorienSpacing.lg),
            profiles.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, _) => Text(
                'Profiller yüklenemedi.',
                style: TextStyle(color: context.palette.error),
              ),
              data: (state) => Column(
                children: [
                  for (final profile in state.profiles) ...[
                    _ProfileCard(
                      profile: profile,
                      isActive: profile.id == state.activeProfileId,
                      canDelete: state.profiles.length >= 2,
                      isSaving: _saving,
                      onSelect: () => _perform(
                        () => ref
                            .read(appProfilesProvider.notifier)
                            .select(profile.id),
                      ),
                      onRename: () => _renameProfile(profile),
                      onDelete: () => _deleteProfile(profile),
                    ),
                    if (profile != state.profiles.last)
                      const SizedBox(height: FlorienSpacing.sm),
                  ],
                ],
              ),
            ),
            const SizedBox(height: FlorienSpacing.xl),
            FilledButton.icon(
              key: const ValueKey('add-profile-button'),
              onPressed: _saving ? null : _addProfile,
              icon: Icon(
                isPremium
                    ? Icons.person_add_alt_1_outlined
                    : Icons.lock_outline_rounded,
              ),
              label: const Text('Yeni profil ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.canDelete,
    required this.isSaving,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
  });

  final AppProfile profile;
  final bool isActive;
  final bool canDelete;
  final bool isSaving;
  final VoidCallback onSelect;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? context.palette.accent : context.palette.surface,
        borderRadius: BorderRadius.circular(FlorienRadius.lg),
        border: Border.all(
          color: context.palette.border,
          width: FlorienBorders.thin,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.person_rounded : Icons.person_outline_rounded,
            size: 28,
            color: context.palette.textPrimary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive ? 'Kullanımdaki profil' : 'Profili değiştir',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!isActive)
            IconButton(
              tooltip: 'Bu profile geç',
              onPressed: isSaving ? null : onSelect,
              icon: const Icon(Icons.check_circle_outline_rounded),
            ),
          PopupMenuButton<_ProfileAction>(
            enabled: !isSaving,
            tooltip: 'Profil seçenekleri',
            onSelected: (action) {
              switch (action) {
                case _ProfileAction.rename:
                  onRename();
                  break;
                case _ProfileAction.delete:
                  onDelete();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _ProfileAction.rename,
                child: Text('Adını değiştir'),
              ),
              if (canDelete)
                const PopupMenuItem(
                  value: _ProfileAction.delete,
                  child: Text('Profili sil'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ProfileAction { rename, delete }

const _manageProfilesResult = '__manage_profiles__';

Future<void> showProfileSwitcher(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(appProfilesProvider.notifier);
  final selectedProfileId = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ProfileSwitcherSheet(),
  );
  if (selectedProfileId == null || !context.mounted) return;
  if (selectedProfileId == _manageProfilesResult) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfileManagementScreen()),
    );
    return;
  }

  try {
    await notifier.select(selectedProfileId);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
    );
  }
}

class _ProfileSwitcherSheet extends ConsumerWidget {
  const _ProfileSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(appProfilesProvider);
    return Container(
      key: const ValueKey('profile-switcher-sheet'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(FlorienRadius.xl),
        border: Border.all(
          color: context.palette.border,
          width: FlorienBorders.medium,
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
              borderRadius: BorderRadius.circular(FlorienRadius.pill),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Profil değiştir',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Kapat',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: profiles.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Profiller yüklenemedi.',
                  style: TextStyle(color: context.palette.error),
                ),
              ),
              data: (state) => ListView.separated(
                shrinkWrap: true,
                itemCount: state.profiles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final profile = state.profiles[index];
                  final selected = profile.id == state.activeProfileId;
                  return Material(
                    color: selected
                        ? FlorienColors.primary
                        : context.palette.surfaceMuted,
                    borderRadius: BorderRadius.circular(FlorienRadius.md),
                    child: InkWell(
                      key: ValueKey('switch-profile-${profile.id}'),
                      onTap: () => Navigator.of(context).pop(profile.id),
                      borderRadius: BorderRadius.circular(FlorienRadius.md),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(FlorienRadius.md),
                          border: Border.all(
                            color: context.palette.border,
                            width: FlorienBorders.thin,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.person_rounded
                                  : Icons.person_outline_rounded,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                profile.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('manage-profiles-button'),
              onPressed: () => Navigator.of(context).pop(_manageProfilesResult),
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text('Profilleri yönet'),
            ),
          ),
        ],
      ),
    );
  }
}
