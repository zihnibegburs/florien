import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/models/ai_models.dart';
import 'package:florien/core/models/recurrence.dart';
import 'package:florien/core/platform/notification_service.dart';
import 'package:florien/core/repositories/ai_repository.dart';
import 'package:florien/features/providers.dart';

class TaskDraft {
  const TaskDraft({
    this.title = '',
    this.useAiDuration = true,
    this.addToInbox = false,
    this.energyLevel,
    this.transitionBuffer = 0,
    this.remind5Min = false,
    this.duration = 30,
    this.selectedColor = '#4F52B2',
    this.time,
    this.recurrence = const RecurrenceSelection(),
    this.splitIntoSubtasks = false,
    this.remind10Min = false,
    this.remind1Min = false,
    this.previewSteps,
    this.reward = '',
    this.motivation = '',
  });

  final String title;
  final bool useAiDuration;
  final bool addToInbox;
  final EnergyLevel? energyLevel;
  final int transitionBuffer;
  final bool remind5Min;
  final int duration;
  final String selectedColor;
  final TimeOfDay? time;
  final RecurrenceSelection recurrence;
  final bool splitIntoSubtasks;
  final bool remind10Min;
  final bool remind1Min;
  final List<AiStepModel>? previewSteps;
  final String reward;
  final String motivation;

  TaskDraft copyWith({
    String? title,
    bool? useAiDuration,
    bool? addToInbox,
    EnergyLevel? energyLevel,
    bool clearEnergyLevel = false,
    int? transitionBuffer,
    bool? remind5Min,
    int? duration,
    String? selectedColor,
    TimeOfDay? time,
    RecurrenceSelection? recurrence,
    bool? splitIntoSubtasks,
    bool? remind10Min,
    bool? remind1Min,
    List<AiStepModel>? previewSteps,
    bool clearPreviewSteps = false,
    String? reward,
    String? motivation,
  }) {
    return TaskDraft(
      title: title ?? this.title,
      useAiDuration: useAiDuration ?? this.useAiDuration,
      addToInbox: addToInbox ?? this.addToInbox,
      energyLevel: clearEnergyLevel ? null : (energyLevel ?? this.energyLevel),
      transitionBuffer: transitionBuffer ?? this.transitionBuffer,
      remind5Min: remind5Min ?? this.remind5Min,
      duration: duration ?? this.duration,
      selectedColor: selectedColor ?? this.selectedColor,
      time: time ?? this.time,
      recurrence: recurrence ?? this.recurrence,
      splitIntoSubtasks: splitIntoSubtasks ?? this.splitIntoSubtasks,
      remind10Min: remind10Min ?? this.remind10Min,
      remind1Min: remind1Min ?? this.remind1Min,
      previewSteps: clearPreviewSteps
          ? null
          : (previewSteps ?? this.previewSteps),
      reward: reward ?? this.reward,
      motivation: motivation ?? this.motivation,
    );
  }

  DateTime scheduledAt(DateTime selectedDate) {
    final t = time ?? TimeOfDay.now();
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      t.hour,
      t.minute,
    );
  }
}

Future<void> submitTaskDraft({
  required WidgetRef ref,
  required TaskDraft draft,
  required DateTime selectedDate,
}) async {
  final title = draft.title.trim();
  if (title.isEmpty) return;

  final reminders = TaskReminderSettings(
    remind10Min: draft.remind10Min,
    remind5Min: draft.remind5Min,
    remind1Min: draft.remind1Min,
    transitionEnd: true,
  );

  if (draft.splitIntoSubtasks) {
    var steps = draft.previewSteps;
    if (steps == null || steps.isEmpty) {
      final result = await ref.read(aiRepositoryProvider).breakdown(title);
      steps = result.steps;
    }

    await ref
        .read(timelineProvider.notifier)
        .createTaskWithSubtasks(
          title: title,
          scheduledAt: draft.scheduledAt(selectedDate),
          color: draft.selectedColor,
          subtasks: steps
              .map(
                (s) => (
                  title: s.title,
                  durationMinutes: s.durationMinutes,
                  color: s.color,
                ),
              )
              .toList(),
        );
    return;
  }

  var duration = draft.duration;
  if (draft.useAiDuration) {
    final result = await ref.read(aiRepositoryProvider).breakdown(title);
    duration = result.steps.fold<int>(
      0,
      (sum, step) => sum + step.durationMinutes,
    );
    if (duration <= 0) duration = 30;
  }

  await ref
      .read(timelineProvider.notifier)
      .createTask(
        title: title,
        durationMinutes: duration,
        color: draft.selectedColor,
        scheduledAt: draft.addToInbox ? null : draft.scheduledAt(selectedDate),
        isInbox: draft.addToInbox,
        recurrence: draft.recurrence,
        reward: draft.reward.trim().isEmpty ? null : draft.reward.trim(),
        reminders: reminders,
        energyLevel: draft.energyLevel,
        motivation: draft.motivation.trim().isEmpty
            ? null
            : draft.motivation.trim(),
        transitionBufferMinutes: draft.transitionBuffer,
      );
}
