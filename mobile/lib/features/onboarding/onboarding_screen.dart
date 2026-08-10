import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/storage/adhd_settings_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_logo.dart';
import 'package:florien/features/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.themeOnly = false});

  final bool themeOnly;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _page = 0;
  ThemeMode? _themeMode;
  bool _preferList = true;
  bool _remind10 = true;
  bool _remind5 = false;
  bool _rewards = true;

  bool get _canAdvance => _page != 0 || _themeMode != null;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);

    if (widget.themeOnly) {
      return Scaffold(
        backgroundColor: context.palette.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildThemePage(s)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _themeMode == null ? null : _finishThemeOnly,
                  child: Text(s.getStarted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_page > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => setState(() => _page--),
                  ),
                ),
              Expanded(child: _buildPage(s)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: !_canAdvance
                    ? null
                    : _page < 3
                        ? () => setState(() => _page++)
                        : _finish,
                child: Text(_page < 3 ? s.nextStep : s.getStarted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemePage(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.onboardingThemePref, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(s.onboardingThemeSubtitle, style: TextStyle(color: context.palette.textSecondary, height: 1.4)),
        const SizedBox(height: 24),
        _ThemeOption(
          label: s.themeLight,
          icon: Icons.light_mode_outlined,
          selected: _themeMode == ThemeMode.light,
          onTap: () => _selectTheme(ThemeMode.light),
        ),
        const SizedBox(height: 12),
        _ThemeOption(
          label: s.themeDark,
          icon: Icons.dark_mode_outlined,
          selected: _themeMode == ThemeMode.dark,
          onTap: () => _selectTheme(ThemeMode.dark),
        ),
      ],
    );
  }

  Widget _buildPage(S s) {
    return switch (_page) {
      0 => _buildThemePage(s),
      1 => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FlorienLogo(size: 72),
            const SizedBox(height: 24),
            Text(s.onboardingWelcome, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(s.onboardingSubtitle, textAlign: TextAlign.center, style: TextStyle(color: context.palette.textSecondary, height: 1.5)),
          ],
        ),
      2 => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.onboardingViewPref, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            RadioListTile<bool>(
              title: Text(s.listView),
              value: true,
              groupValue: _preferList,
              onChanged: (v) => setState(() => _preferList = v!),
            ),
            RadioListTile<bool>(
              title: Text(s.hourView),
              value: false,
              groupValue: _preferList,
              onChanged: (v) => setState(() => _preferList = v!),
            ),
            const SizedBox(height: 24),
            Text(s.onboardingReminderPref, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            SwitchListTile(title: Text(s.remind10Min), value: _remind10, onChanged: (v) => setState(() => _remind10 = v)),
            SwitchListTile(title: Text(s.remind5Min), value: _remind5, onChanged: (v) => setState(() => _remind5 = v)),
          ],
        ),
      _ => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.onboardingRewardsPref, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(s.yourReward),
              value: _rewards,
              onChanged: (v) => setState(() => _rewards = v),
            ),
            const SizedBox(height: 16),
            Text(s.dailyEnergy, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: EnergyLevel.values.map((e) {
                return ChoiceChip(
                  label: Text(s.energyLabel(e)),
                  selected: false,
                  onSelected: (_) {},
                );
              }).toList(),
            ),
          ],
        ),
    };
  }

  void _selectTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
    ref.read(appThemeModeProvider.notifier).setThemeMode(mode);
  }

  Future<void> _finishThemeOnly() async {
    final mode = _themeMode;
    if (mode == null) return;
    await ref.read(appThemeModeProvider.notifier).setThemeMode(mode);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _finish() async {
    final mode = _themeMode;
    if (mode == null) return;
    await ref.read(appThemeModeProvider.notifier).setThemeMode(mode);
    await ref.read(adhdPreferencesProvider.notifier).patch((p) => p.copyWith(
          onboardingCompleted: true,
          preferListView: _preferList,
          defaultRemind10Min: _remind10,
          defaultRemind5Min: _remind5,
        ));
    ref.read(timelineViewModeProvider.notifier).state =
        _preferList ? TimelineViewMode.list : TimelineViewMode.grid;
    if (mounted) Navigator.of(context).pop();
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = Theme.of(context).colorScheme.primary;

    return Material(
      color: selected ? accent.withValues(alpha: 0.12) : palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? accent : palette.border, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? accent : palette.textSecondary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check_circle_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
