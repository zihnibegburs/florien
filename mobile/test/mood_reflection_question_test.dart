import 'package:florien/features/todo/statistics_tab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 8, 20);

  test('uses a natural prompt for today and yesterday', () {
    expect(
      moodReflectionQuestion(DateTime(2026, 8, 20), today: today),
      'Bugün nasılsın?',
    );
    expect(
      moodReflectionQuestion(DateTime(2026, 8, 19), today: today),
      'Dün nasıldın?',
    );
  });

  test('formats earlier dates with Turkish month and weekday names', () {
    expect(
      moodReflectionQuestion(DateTime(2026, 8, 18), today: today),
      '18 Ağustos Salı günü nasıldın?',
    );
    expect(
      moodReflectionQuestion(DateTime(2025, 12, 31), today: today),
      '31 Aralık 2025 Çarşamba günü nasıldın?',
    );
  });
}
