enum RecurrenceType { none, daily, weekly, monthly, yearly, custom }

enum RecurrenceUnit { days, weeks, months }

enum RecurrenceScope { thisOccurrence, all, future }

enum RecurrenceExceptionKind { none, override, skip }

extension RecurrenceScopeX on RecurrenceScope {
  String apiValue() => switch (this) {
    RecurrenceScope.thisOccurrence => 'THIS',
    RecurrenceScope.all => 'ALL',
    RecurrenceScope.future => 'FUTURE',
  };
}

class RecurrenceSelection {
  const RecurrenceSelection({
    this.type = RecurrenceType.none,
    this.interval = 1,
    this.unit = RecurrenceUnit.days,
  });

  final RecurrenceType type;
  final int interval;
  final RecurrenceUnit unit;

  bool get hasRecurrence => type != RecurrenceType.none;

  RecurrenceSelection copyWith({
    RecurrenceType? type,
    int? interval,
    RecurrenceUnit? unit,
  }) => RecurrenceSelection(
    type: type ?? this.type,
    interval: interval ?? this.interval,
    unit: unit ?? this.unit,
  );

  String apiType() => switch (type) {
    RecurrenceType.none => 'NONE',
    RecurrenceType.daily => 'DAILY',
    RecurrenceType.weekly => 'WEEKLY',
    RecurrenceType.monthly => 'MONTHLY',
    RecurrenceType.yearly => 'YEARLY',
    RecurrenceType.custom => 'CUSTOM',
  };

  String? apiUnit() => type == RecurrenceType.custom
      ? switch (unit) {
          RecurrenceUnit.days => 'DAYS',
          RecurrenceUnit.weeks => 'WEEKS',
          RecurrenceUnit.months => 'MONTHS',
        }
      : null;

  Map<String, dynamic> toApiJson() => {
    'recurrenceType': apiType(),
    if (hasRecurrence) 'recurrenceInterval': interval,
    if (type == RecurrenceType.custom) 'recurrenceUnit': apiUnit(),
  };
}

abstract final class RecurrenceOccurrence {
  static const prefix = 'r:';

  static String dateKey(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime? parseDateKey(String? value) {
    if (value == null || value.length < 10) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String id(String seriesId, DateTime date) =>
      '$prefix$seriesId:${dateKey(date)}';

  static bool isVirtualId(String id) {
    if (!id.startsWith(prefix)) return false;
    final parts = id.split(':');
    return parts.length == 3 && parts[1].isNotEmpty && parts[2].length == 10;
  }

  static ({String seriesId, String dateKey})? parse(String id) {
    if (!isVirtualId(id)) return null;
    final parts = id.split(':');
    return (seriesId: parts[1], dateKey: parts[2]);
  }
}
