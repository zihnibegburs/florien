import 'package:florien/core/models/models.dart';
import 'package:florien/core/models/recurrence.dart';

TaskModel mergeRecurrenceException({
  required TaskModel template,
  required TaskModel exception,
}) {
  final owned = exception.recurrenceOwnedFields;
  if (owned == null) {
    return exception.copyWith(
      recurrenceType: template.recurrenceType,
      recurrenceInterval: template.recurrenceInterval,
      recurrenceUnit: template.recurrenceUnit,
    );
  }
  final fields = owned.toSet();
  T pick<T>(String field, T exceptionValue, T templateValue) =>
      fields.contains(field) ? exceptionValue : templateValue;

  final scheduledAt = pick(
    RecurrencePatch.scheduledAt,
    exception.scheduledAt,
    template.scheduledAt,
  );
  return template.copyWith(
    id: exception.id,
    title: pick(RecurrencePatch.title, exception.title, template.title),
    description: pick(
      RecurrencePatch.description,
      exception.description,
      template.description,
    ),
    color: pick(RecurrencePatch.color, exception.color, template.color),
    icon: pick(RecurrencePatch.icon, exception.icon, template.icon),
    durationMinutes: pick(
      RecurrencePatch.durationMinutes,
      exception.durationMinutes,
      template.durationMinutes,
    ),
    scheduledAt: scheduledAt,
    clearScheduledAt: scheduledAt == null,
    status: exception.status,
    sortOrder: exception.sortOrder,
    isInbox: pick(RecurrencePatch.isInbox, exception.isInbox, false),
    startedAt: exception.startedAt,
    clearStartedAt: exception.startedAt == null,
    completedAt: exception.completedAt,
    clearCompletedAt: exception.completedAt == null,
    alarmAt: pick(RecurrencePatch.alarmAt, exception.alarmAt, template.alarmAt),
    clearAlarmAt:
        pick(RecurrencePatch.alarmAt, exception.alarmAt, template.alarmAt) ==
        null,
    reminderLeadMinutes: pick(
      RecurrencePatch.reminderLeadMinutes,
      exception.reminderLeadMinutes,
      template.reminderLeadMinutes,
    ),
    clearReminderLeadMinutes:
        pick(
          RecurrencePatch.reminderLeadMinutes,
          exception.reminderLeadMinutes,
          template.reminderLeadMinutes,
        ) ==
        null,
    isTimed: pick(RecurrencePatch.isTimed, exception.isTimed, template.isTimed),
    dayPeriod: pick(
      RecurrencePatch.dayPeriod,
      exception.dayPeriod,
      template.dayPeriod,
    ),
    recurrenceSeriesId:
        exception.recurrenceSeriesId ?? template.recurrenceSeriesId,
    recurrenceRootId: exception.recurrenceRootId ?? template.recurrenceRootId,
    occurrenceDate: exception.occurrenceDate ?? template.occurrenceDate,
    recurrenceException: exception.recurrenceException,
    recurrenceOwnedFields: exception.recurrenceOwnedFields,
    todoListId: exception.todoListId,
    clearTodoListId: exception.todoListId == null,
  );
}
