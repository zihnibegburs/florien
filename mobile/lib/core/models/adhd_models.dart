enum EnergyLevel { low, medium, high }

extension EnergyLevelX on EnergyLevel {
  String get apiValue => name;

  static EnergyLevel? fromApiNullable(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return EnergyLevel.values.byName(value.toLowerCase());
    } catch (_) {
      return null;
    }
  }
}

class AdhdPreferences {
  const AdhdPreferences({
    this.onboardingCompleted = false,
    this.overwhelmMode = false,
    this.preferListView = true,
    this.defaultRemind10Min = true,
    this.defaultRemind5Min = false,
    this.defaultRemind1Min = true,
    this.transitionAlerts = true,
    this.breakAfterFocus = true,
    this.breakDurationMinutes = 10,
    this.bodyDoublingEnabled = false,
    this.dailyEnergyLevel,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.streakReminders = true,
    this.dailySummary = false,
    this.rewardTimerMinutes = 15,
  });

  final bool onboardingCompleted;
  final bool overwhelmMode;
  final bool preferListView;
  final bool defaultRemind10Min;
  final bool defaultRemind5Min;
  final bool defaultRemind1Min;
  final bool transitionAlerts;
  final bool breakAfterFocus;
  final int breakDurationMinutes;
  final bool bodyDoublingEnabled;
  final EnergyLevel? dailyEnergyLevel;
  final int? quietHoursStart;
  final int? quietHoursEnd;
  final bool streakReminders;
  final bool dailySummary;
  final int rewardTimerMinutes;

  AdhdPreferences copyWith({
    bool? onboardingCompleted,
    bool? overwhelmMode,
    bool? preferListView,
    bool? defaultRemind10Min,
    bool? defaultRemind5Min,
    bool? defaultRemind1Min,
    bool? transitionAlerts,
    bool? breakAfterFocus,
    int? breakDurationMinutes,
    bool? bodyDoublingEnabled,
    EnergyLevel? dailyEnergyLevel,
    bool clearDailyEnergy = false,
    int? quietHoursStart,
    int? quietHoursEnd,
    bool clearQuietHours = false,
    bool? streakReminders,
    bool? dailySummary,
    int? rewardTimerMinutes,
  }) => AdhdPreferences(
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    overwhelmMode: overwhelmMode ?? this.overwhelmMode,
    preferListView: preferListView ?? this.preferListView,
    defaultRemind10Min: defaultRemind10Min ?? this.defaultRemind10Min,
    defaultRemind5Min: defaultRemind5Min ?? this.defaultRemind5Min,
    defaultRemind1Min: defaultRemind1Min ?? this.defaultRemind1Min,
    transitionAlerts: transitionAlerts ?? this.transitionAlerts,
    breakAfterFocus: breakAfterFocus ?? this.breakAfterFocus,
    breakDurationMinutes: breakDurationMinutes ?? this.breakDurationMinutes,
    bodyDoublingEnabled: bodyDoublingEnabled ?? this.bodyDoublingEnabled,
    dailyEnergyLevel: clearDailyEnergy
        ? null
        : (dailyEnergyLevel ?? this.dailyEnergyLevel),
    quietHoursStart: clearQuietHours
        ? null
        : (quietHoursStart ?? this.quietHoursStart),
    quietHoursEnd: clearQuietHours
        ? null
        : (quietHoursEnd ?? this.quietHoursEnd),
    streakReminders: streakReminders ?? this.streakReminders,
    dailySummary: dailySummary ?? this.dailySummary,
    rewardTimerMinutes: rewardTimerMinutes ?? this.rewardTimerMinutes,
  );

  Map<String, dynamic> toJson() => {
    'onboardingCompleted': onboardingCompleted,
    'overwhelmMode': overwhelmMode,
    'preferListView': preferListView,
    'defaultRemind10Min': defaultRemind10Min,
    'defaultRemind5Min': defaultRemind5Min,
    'defaultRemind1Min': defaultRemind1Min,
    'transitionAlerts': transitionAlerts,
    'breakAfterFocus': breakAfterFocus,
    'breakDurationMinutes': breakDurationMinutes,
    'bodyDoublingEnabled': bodyDoublingEnabled,
    'dailyEnergyLevel': dailyEnergyLevel?.name,
    'quietHoursStart': quietHoursStart,
    'quietHoursEnd': quietHoursEnd,
    'streakReminders': streakReminders,
    'dailySummary': dailySummary,
    'rewardTimerMinutes': rewardTimerMinutes,
  };

  factory AdhdPreferences.fromJson(Map<String, dynamic> json) =>
      AdhdPreferences(
        onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
        overwhelmMode: json['overwhelmMode'] as bool? ?? false,
        preferListView: json['preferListView'] as bool? ?? true,
        defaultRemind10Min: json['defaultRemind10Min'] as bool? ?? true,
        defaultRemind5Min: json['defaultRemind5Min'] as bool? ?? false,
        defaultRemind1Min: json['defaultRemind1Min'] as bool? ?? true,
        transitionAlerts: json['transitionAlerts'] as bool? ?? true,
        breakAfterFocus: json['breakAfterFocus'] as bool? ?? true,
        breakDurationMinutes: json['breakDurationMinutes'] as int? ?? 10,
        bodyDoublingEnabled: json['bodyDoublingEnabled'] as bool? ?? false,
        dailyEnergyLevel: json['dailyEnergyLevel'] != null
            ? EnergyLevelX.fromApiNullable(json['dailyEnergyLevel'] as String)
            : null,
        quietHoursStart: json['quietHoursStart'] as int?,
        quietHoursEnd: json['quietHoursEnd'] as int?,
        streakReminders: json['streakReminders'] as bool? ?? true,
        dailySummary: json['dailySummary'] as bool? ?? false,
        rewardTimerMinutes: json['rewardTimerMinutes'] as int? ?? 15,
      );
}

class RoutineTemplateStep {
  const RoutineTemplateStep({
    required this.title,
    required this.durationMinutes,
    required this.color,
    this.icon = 'task',
  });

  final String title;
  final int durationMinutes;
  final String color;
  final String icon;
}

class RoutineTemplate {
  const RoutineTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.steps,
  });

  final String id;
  final String name;
  final String icon;
  final String color;
  final List<RoutineTemplateStep> steps;
}

class MedicationPreset {
  const MedicationPreset({
    required this.title,
    required this.durationMinutes,
    required this.color,
    this.icon = 'medication',
  });

  final String title;
  final int durationMinutes;
  final String color;
  final String icon;
}
