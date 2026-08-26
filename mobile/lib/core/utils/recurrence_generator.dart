import 'package:florien/core/models/recurrence.dart';

class RecurrenceGenerator {
  RecurrenceGenerator._();

  static bool occursOn({
    required DateTime date,
    required DateTime start,
    required RecurrenceType type,
    int interval = 1,
    RecurrenceUnit? unit,
    DateTime? until,
  }) {
    if (type == RecurrenceType.none) return false;
    final day = RecurrenceOccurrence.dateOnly(date);
    final startDay = RecurrenceOccurrence.dateOnly(start);
    if (day.isBefore(startDay)) return false;
    if (until != null && !day.isBefore(RecurrenceOccurrence.dateOnly(until))) {
      return false;
    }

    final safeInterval = interval < 1 ? 1 : interval;
    return switch (type) {
      RecurrenceType.daily =>
        day.difference(startDay).inDays % safeInterval == 0,
      RecurrenceType.weekly =>
        day.weekday == startDay.weekday &&
            day.difference(startDay).inDays % (7 * safeInterval) == 0,
      RecurrenceType.monthly => _monthlyOccurs(day, startDay, safeInterval),
      RecurrenceType.yearly =>
        day.month == startDay.month &&
            day.day == startDay.day &&
            (day.year - startDay.year) % safeInterval == 0,
      RecurrenceType.custom => switch (unit) {
        RecurrenceUnit.days =>
          day.difference(startDay).inDays % safeInterval == 0,
        RecurrenceUnit.weeks =>
          day.weekday == startDay.weekday &&
              day.difference(startDay).inDays % (7 * safeInterval) == 0,
        RecurrenceUnit.months => _monthlyOccurs(day, startDay, safeInterval),
        null => false,
      },
      RecurrenceType.none => false,
    };
  }

  static DateTime scheduledAtFor({
    required DateTime start,
    required DateTime date,
  }) {
    final localStart = start.toLocal();
    final day = RecurrenceOccurrence.dateOnly(date);
    return DateTime(
      day.year,
      day.month,
      day.day,
      localStart.hour,
      localStart.minute,
      localStart.second,
    );
  }

  static DateTime? alarmAtFor({
    required DateTime? alarmAt,
    required DateTime occurrence,
  }) {
    if (alarmAt == null) return null;
    final localAlarm = alarmAt.toLocal();
    final localOccurrence = occurrence.toLocal();
    return DateTime(
      localOccurrence.year,
      localOccurrence.month,
      localOccurrence.day,
      localAlarm.hour,
      localAlarm.minute,
    );
  }

  static bool _monthlyOccurs(DateTime day, DateTime startDay, int interval) {
    if (day.day != startDay.day) return false;
    final months =
        (day.year - startDay.year) * 12 + (day.month - startDay.month);
    return months >= 0 && months % interval == 0;
  }
}
