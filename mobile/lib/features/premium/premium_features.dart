import 'package:florien/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';

enum PremiumFeature {
  aiChat,
  subtasks,
  multipleProfiles,
  calendarImport,
  reminders,
  exactTaskTime,
}

extension PremiumFeatureCopy on PremiumFeature {
  String titleFor(S strings) => switch (this) {
    PremiumFeature.aiChat => strings.aiPlanAssistant,
    PremiumFeature.subtasks => strings.subtasks,
    PremiumFeature.multipleProfiles => strings.multipleProfiles,
    PremiumFeature.calendarImport => strings.calendarImport,
    PremiumFeature.reminders => strings.reminders,
    PremiumFeature.exactTaskTime => strings.exactTaskTime,
  };

  IconData get icon => switch (this) {
    PremiumFeature.aiChat => Icons.auto_awesome_rounded,
    PremiumFeature.subtasks => Icons.account_tree_rounded,
    PremiumFeature.multipleProfiles => Icons.people_alt_rounded,
    PremiumFeature.calendarImport => Icons.calendar_month_rounded,
    PremiumFeature.reminders => Icons.alarm_rounded,
    PremiumFeature.exactTaskTime => Icons.schedule_rounded,
  };
}

const premiumFeatures = PremiumFeature.values;

class PlanComparisonFeature {
  const PlanComparisonFeature({
    required this.id,
    required this.icon,
    required this.includedInStandard,
    this.premiumFeature,
  });

  final String id;
  final IconData icon;
  final bool includedInStandard;
  final PremiumFeature? premiumFeature;

  String titleFor(S strings) {
    final premium = premiumFeature;
    if (premium != null) return premium.titleFor(strings);
    return switch (id) {
      'tasksAndDailyPlan' => strings.tasksAndDailyPlan,
      'focusTimer' => strings.focusTimer,
      'readyRoutines' => strings.readyRoutines,
      'dailyReflections' => strings.dailyReflections,
      _ => id,
    };
  }
}

final planComparisonFeatures = <PlanComparisonFeature>[
  const PlanComparisonFeature(
    id: 'tasksAndDailyPlan',
    icon: Icons.checklist_rounded,
    includedInStandard: true,
  ),
  const PlanComparisonFeature(
    id: 'focusTimer',
    icon: Icons.timer_outlined,
    includedInStandard: true,
  ),
  const PlanComparisonFeature(
    id: 'readyRoutines',
    icon: Icons.repeat_rounded,
    includedInStandard: true,
  ),
  const PlanComparisonFeature(
    id: 'dailyReflections',
    icon: Icons.auto_stories_rounded,
    includedInStandard: true,
  ),
  for (final feature in premiumFeatures)
    PlanComparisonFeature(
      id: feature.name,
      icon: feature.icon,
      includedInStandard: false,
      premiumFeature: feature,
    ),
];
