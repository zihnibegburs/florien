import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/storage/profile_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';

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
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Profil adı'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    controller.dispose();
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
              icon: const Icon(Icons.person_add_alt_1_outlined),
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
