import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/models/mood_entry.dart';

void main() {
  test('ruh hali kaydı valence ve yansımayı korur', () {
    final entry = MoodEntry(
      date: DateTime(2026, 8, 15, 18),
      mood: MoodLevel.good,
      reflection: 'Kısa bir yürüyüş iyi geldi.',
    );

    final restored = MoodEntry.fromJson(entry.toJson());

    expect(restored.day, DateTime(2026, 8, 15));
    expect(restored.mood, MoodLevel.good);
    expect(restored.reflection, 'Kısa bir yürüyüş iyi geldi.');
    expect(MoodLevelDetails.fromValence(.8), MoodLevel.veryGood);
    expect(MoodLevelDetails.fromValence(-.4), MoodLevel.low);
  });
}
