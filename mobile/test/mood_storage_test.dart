import 'package:florien/core/models/mood_entry.dart';
import 'package:florien/core/storage/mood_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps reflections separated by user and profile', () async {
    final storage = MoodStorage();
    final entry = MoodEntry(
      date: DateTime(2026, 8, 20),
      mood: MoodLevel.good,
      reflection: 'Bugün daha sakindim.',
    );

    await storage.save('user-1:primary', [entry]);

    expect(
      (await storage.load('user-1:primary')).single.reflection,
      'Bugün daha sakindim.',
    );
    expect(await storage.load('user-1:work'), isEmpty);
    expect(await storage.load('user-2:primary'), isEmpty);
  });
}
