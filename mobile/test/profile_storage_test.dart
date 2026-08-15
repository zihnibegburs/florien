import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/storage/profile_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps one profile and persists profile changes', () async {
    final storage = ProfileStorage();

    final initial = await storage.load(
      ownerId: 'user-1',
      fallbackName: 'Deniz',
    );
    expect(initial.profiles, hasLength(1));
    expect(initial.activeProfile.name, 'Deniz');

    final renamed = await storage.rename(
      ownerId: 'user-1',
      fallbackName: 'Deniz',
      profileId: initial.activeProfileId,
      name: 'Deniz A.',
    );
    expect(renamed.activeProfile.name, 'Deniz A.');

    final withSecond = await storage.create(
      ownerId: 'user-1',
      fallbackName: 'Deniz',
      name: 'Ece',
    );
    expect(withSecond.profiles, hasLength(2));

    final secondProfile = withSecond.profiles.last;
    final selected = await storage.select(
      ownerId: 'user-1',
      fallbackName: 'Deniz',
      profileId: secondProfile.id,
    );
    expect(selected.activeProfile.name, 'Ece');

    final afterDelete = await storage.delete(
      ownerId: 'user-1',
      fallbackName: 'Deniz',
      profileId: secondProfile.id,
    );
    expect(afterDelete.profiles, hasLength(1));
    expect(afterDelete.activeProfile.name, 'Deniz A.');

    await expectLater(
      storage.delete(
        ownerId: 'user-1',
        fallbackName: 'Deniz',
        profileId: afterDelete.activeProfileId,
      ),
      throwsStateError,
    );
  });
}
