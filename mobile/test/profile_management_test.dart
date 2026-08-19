import 'package:florien/core/storage/profile_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/profile_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _initialProfiles = AppProfilesState(
  profiles: [
    AppProfile(id: 'primary', name: 'Florien'),
    AppProfile(id: 'work', name: 'İş'),
  ],
  activeProfileId: 'primary',
);

class _TestProfilesNotifier extends AppProfilesNotifier {
  String? createdName;

  @override
  Future<AppProfilesState> build() async => _initialProfiles;

  @override
  Future<void> create(String name) async {
    createdName = name;
    final current = state.requireValue;
    state = AsyncData(
      AppProfilesState(
        profiles: [
          ...current.profiles,
          AppProfile(id: 'created', name: name),
        ],
        activeProfileId: current.activeProfileId,
      ),
    );
  }

  @override
  Future<void> select(String profileId) async {
    final current = state.requireValue;
    state = AsyncData(
      AppProfilesState(profiles: current.profiles, activeProfileId: profileId),
    );
  }
}

class _ProfileSwitcherHarness extends ConsumerWidget {
  const _ProfileSwitcherHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeName = ref.watch(activeAppProfileProvider)?.name ?? '';
    return Scaffold(
      body: Column(
        children: [
          Text(activeName, key: const ValueKey('active-profile-name')),
          FilledButton(
            key: const ValueKey('open-profile-switcher'),
            onPressed: () => showProfileSwitcher(context, ref),
            child: const Text('Profil değiştir'),
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('creating a profile does not reuse a disposed controller', (
    tester,
  ) async {
    final notifier = _TestProfilesNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProfilesProvider.overrideWith(() => notifier)],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const ProfileManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-profile-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Kişisel');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(notifier.createdName, 'Kişisel');
    expect(find.text('Kişisel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile switcher lists profiles and changes active profile', (
    tester,
  ) async {
    final notifier = _TestProfilesNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProfilesProvider.overrideWith(() => notifier)],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const _ProfileSwitcherHarness(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('active-profile-name')))
          .data,
      'Florien',
    );
    await tester.tap(find.byKey(const ValueKey('open-profile-switcher')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile-switcher-sheet')),
      findsOneWidget,
    );
    expect(find.text('Florien'), findsWidgets);
    expect(find.text('İş'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('switch-profile-work')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('active-profile-name')))
          .data,
      'İş',
    );
    expect(tester.takeException(), isNull);
  });
}
