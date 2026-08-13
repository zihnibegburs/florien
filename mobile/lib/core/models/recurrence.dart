enum RecurrenceType { none, daily, weekly, monthly, yearly, custom }

enum RecurrenceUnit { days, weeks, months }

enum DeleteRecurrenceScope { thisOccurrence, all, future }

extension DeleteRecurrenceScopeX on DeleteRecurrenceScope {
  String apiValue() => switch (this) {
    DeleteRecurrenceScope.thisOccurrence => 'THIS',
    DeleteRecurrenceScope.all => 'ALL',
    DeleteRecurrenceScope.future => 'FUTURE',
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
