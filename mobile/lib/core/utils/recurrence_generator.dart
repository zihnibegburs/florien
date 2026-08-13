import 'package:florien/core/models/recurrence.dart';

class RecurrenceGenerator {
  RecurrenceGenerator._();

  static List<DateTime> generateOccurrences({
    required DateTime start,
    required RecurrenceType type,
    int interval = 1,
    RecurrenceUnit? unit,
  }) {
    if (type == RecurrenceType.none) return const [];

    final safeInterval = interval < 1 ? 1 : interval;
    final max = _maxOccurrences(type, safeInterval, unit);
    var cursor = start.toUtc();
    final occurrences = <DateTime>[];

    for (var i = 0; i < max; i++) {
      cursor = _next(cursor, type, safeInterval, unit);
      occurrences.add(cursor);
    }
    return occurrences;
  }

  static int _maxOccurrences(
    RecurrenceType type,
    int interval,
    RecurrenceUnit? unit,
  ) {
    return switch (type) {
      RecurrenceType.daily => 89,
      RecurrenceType.weekly => 51,
      RecurrenceType.monthly => 11,
      RecurrenceType.yearly => 4,
      RecurrenceType.custom => switch (unit) {
        RecurrenceUnit.days => (89 / interval).floor().clamp(1, 89),
        RecurrenceUnit.weeks => (51 / interval).floor().clamp(1, 51),
        RecurrenceUnit.months => (11 / interval).floor().clamp(1, 11),
        null => 0,
      },
      RecurrenceType.none => 0,
    };
  }

  static DateTime _next(
    DateTime current,
    RecurrenceType type,
    int interval,
    RecurrenceUnit? unit,
  ) {
    return switch (type) {
      RecurrenceType.daily => current.add(Duration(days: interval)),
      RecurrenceType.weekly => current.add(Duration(days: 7 * interval)),
      RecurrenceType.monthly => DateTime.utc(
        current.year,
        current.month + interval,
        current.day,
        current.hour,
        current.minute,
        current.second,
      ),
      RecurrenceType.yearly => DateTime.utc(
        current.year + interval,
        current.month,
        current.day,
        current.hour,
        current.minute,
        current.second,
      ),
      RecurrenceType.custom => switch (unit) {
        RecurrenceUnit.days => current.add(Duration(days: interval)),
        RecurrenceUnit.weeks => current.add(Duration(days: 7 * interval)),
        RecurrenceUnit.months => DateTime.utc(
          current.year,
          current.month + interval,
          current.day,
          current.hour,
          current.minute,
          current.second,
        ),
        null => current,
      },
      RecurrenceType.none => current,
    };
  }
}
