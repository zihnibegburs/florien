import 'package:florien/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 8, 23);

  test('many tasks on the same day still count as one streak day', () {
    expect(
      florienCompletionStreak([
        DateTime(2026, 8, 23, 9),
        DateTime(2026, 8, 23, 11),
        DateTime(2026, 8, 23, 18),
      ], today),
      1,
    );
  });

  test('counts consecutive days and ignores a gap', () {
    expect(
      florienCompletionStreak([
        DateTime(2026, 8, 23),
        DateTime(2026, 8, 22),
        DateTime(2026, 8, 21),
        DateTime(2026, 8, 19),
      ], today),
      3,
    );
  });

  test('keeps yesterday’s streak if nothing is done yet today', () {
    expect(
      florienCompletionStreak([
        DateTime(2026, 8, 22),
        DateTime(2026, 8, 21),
      ], today),
      2,
    );
  });

  test('breaks when yesterday was missed', () {
    expect(
      florienCompletionStreak([DateTime(2026, 8, 21)], today),
      0,
    );
  });
}
