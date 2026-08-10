import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/achievement.dart';
import 'package:florien/core/storage/adhd_settings_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_soft_overlay.dart';
import 'package:florien/features/achievements/achievements_screen.dart';
import 'package:florien/features/providers.dart';

class AchievementUnlockListener extends ConsumerStatefulWidget {
  const AchievementUnlockListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AchievementUnlockListener> createState() => _AchievementUnlockListenerState();
}

class _AchievementUnlockListenerState extends ConsumerState<AchievementUnlockListener> {
  Set<String> _knownUnlocked = {};
  bool _loaded = false;
  String? _loadedForUserId;

  Future<void> _loadKnown(String? userId) async {
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _knownUnlocked = {};
        _loaded = true;
        _loadedForUserId = null;
      });
      return;
    }
    final known = await ref.read(adhdSettingsStorageProvider).loadUnlockedAchievementIds(userId);
    if (!mounted) return;
    setState(() {
      _knownUnlocked = known;
      _loaded = true;
      _loadedForUserId = userId;
    });
  }

  void _checkUnlocks(AchievementStats stats) {
    if (!_loaded) return;
    for (final def in achievementDefinitions) {
      final id = def.unlockKey(stats);
      if (def.isUnlocked(stats) && !_knownUnlocked.contains(id)) {
        final userId = ref.read(authStateProvider).valueOrNull?.userId;
        if (userId == null) return;
        _knownUnlocked = {..._knownUnlocked, id};
        ref.read(adhdSettingsStorageProvider).saveUnlockedAchievementIds(userId, _knownUnlocked);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showUnlock(def);
        });
      }
    }
  }

  void _showUnlock(AchievementDefinition def) {
    final s = ref.read(stringsProvider);
    showFlorienSoftDialog(
      context: context,
      builder: (dialogCtx) => FlorienSoftCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(def.icon, size: 36, color: def.color),
            const SizedBox(height: 10),
            Text(
              s.achievementUnlocked,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: dialogCtx.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s.achievementTitle(def),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: dialogCtx.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FlorienSoftTextButton(
                label: s.awesome,
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authStateProvider.select((auth) => auth.valueOrNull?.userId));
    if (userId != _loadedForUserId) {
      _loaded = false;
      _loadKnown(userId);
    }

    ref.listen(achievementStatsProvider, (prev, next) {
      final stats = next.valueOrNull;
      if (stats != null) _checkUnlocks(stats);
    });
    return widget.child;
  }
}
