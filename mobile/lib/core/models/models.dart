import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/models/recurrence.dart';

enum TaskStatus { pending, inProgress, paused, completed, skipped }

/// Priority is used by the standalone To-do list. Older tasks safely default
/// to [none] when the field is absent in Firestore.
enum TaskPriority { high, medium, low, none }

/// Daily planner section. Tasks without this field remain compatible and are
/// shown in the catch-all [anytime] section.
enum DayPeriod { anytime, morning, daytime, evening }

class AuthResponse {
  /// Firebase ID token when available (widgets / Siri), otherwise empty.
  final String token;
  final String userId;
  final String email;
  final String displayName;
  final String avatarColor;

  const AuthResponse({
    this.token = '',
    required this.userId,
    required this.email,
    required this.displayName,
    required this.avatarColor,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    token: json['token'] as String? ?? '',
    userId: json['userId'] as String,
    email: json['email'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
    avatarColor: json['avatarColor'] as String? ?? '#4F52B2',
  );

  String get firstName {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  AuthResponse copyWith({
    String? token,
    String? userId,
    String? email,
    String? displayName,
    String? avatarColor,
  }) => AuthResponse(
    token: token ?? this.token,
    userId: userId ?? this.userId,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    avatarColor: avatarColor ?? this.avatarColor,
  );
}

class TaskModel {
  static const int aiSubtaskLimit = 5;
  static const int userSubtaskLimit = 30;

  final String id;
  final String title;
  final String? description;
  final String color;
  final String icon;
  final int durationMinutes;
  final DateTime? scheduledAt;
  final TaskStatus status;
  final int sortOrder;
  final bool isInbox;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? alarmAt;

  /// Minutes before [scheduledAt]. `null` means use the account default.
  final int? reminderLeadMinutes;
  final bool isTimed;
  final String? parentTaskId;
  final List<TaskModel> subtasks;
  final String? reward;
  final EnergyLevel? energyLevel;
  final String? motivation;
  final int transitionBufferMinutes;
  final RecurrenceType recurrenceType;
  final int recurrenceInterval;
  final RecurrenceUnit? recurrenceUnit;
  final String? recurrenceSeriesId;
  final String? recurrenceRootId;
  final String? recurrenceUntil;
  final String? occurrenceDate;
  final RecurrenceExceptionKind recurrenceException;

  /// Sparse OVERRIDE keys. `null` is a legacy full clone; `[]` inherits all
  /// template fields except status / completion.
  final List<String>? recurrenceOwnedFields;
  final TaskPriority priority;
  final DayPeriod dayPeriod;

  /// `null` means the built-in To-do list; custom lists use their local id.
  final String? todoListId;

  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.color,
    required this.icon,
    required this.durationMinutes,
    this.scheduledAt,
    required this.status,
    required this.sortOrder,
    required this.isInbox,
    this.startedAt,
    this.completedAt,
    this.alarmAt,
    this.reminderLeadMinutes,
    this.isTimed = false,
    this.parentTaskId,
    this.subtasks = const [],
    this.reward,
    this.energyLevel,
    this.motivation,
    this.transitionBufferMinutes = 0,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceInterval = 1,
    this.recurrenceUnit,
    this.recurrenceSeriesId,
    this.recurrenceRootId,
    this.recurrenceUntil,
    this.occurrenceDate,
    this.recurrenceException = RecurrenceExceptionKind.none,
    this.recurrenceOwnedFields,
    this.priority = TaskPriority.none,
    this.dayPeriod = DayPeriod.anytime,
    this.todoListId,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    color: json['color'] as String,
    icon: json['icon'] as String? ?? 'task',
    durationMinutes: json['durationMinutes'] as int,
    scheduledAt: _parseDateTime(json['scheduledAt']),
    status: _parseStatus(json['status'] as String),
    sortOrder: json['sortOrder'] as int,
    isInbox: json['isInbox'] as bool,
    startedAt: _parseDateTime(json['startedAt']),
    completedAt: _parseDateTime(json['completedAt']),
    alarmAt: _parseDateTime(json['alarmAt']),
    reminderLeadMinutes: json['reminderLeadMinutes'] as int?,
    isTimed: json['isTimed'] as bool? ?? false,
    parentTaskId: json['parentTaskId'] as String?,
    subtasks: json['subtasks'] != null
        ? (json['subtasks'] as List)
              .map((t) => TaskModel.fromJson(t as Map<String, dynamic>))
              .toList()
        : const [],
    reward: json['reward'] as String?,
    energyLevel: EnergyLevelX.fromApiNullable(json['energyLevel'] as String?),
    motivation: json['motivation'] as String?,
    transitionBufferMinutes: json['transitionBufferMinutes'] as int? ?? 0,
    recurrenceType: _parseRecurrenceType(json['recurrenceType'] as String?),
    recurrenceInterval: (json['recurrenceInterval'] as num?)?.toInt() ?? 1,
    recurrenceUnit: _parseRecurrenceUnit(json['recurrenceUnit'] as String?),
    recurrenceSeriesId: json['recurrenceSeriesId'] as String?,
    recurrenceRootId: json['recurrenceRootId'] as String?,
    recurrenceUntil: json['recurrenceUntil'] as String?,
    occurrenceDate: json['occurrenceDate'] as String?,
    recurrenceException: _parseRecurrenceException(
      json['recurrenceException'] as String?,
    ),
    recurrenceOwnedFields: _parseOwnedFields(json['recurrenceOwnedFields']),
    priority: _parsePriority(json['priority'] as String?),
    dayPeriod: _parseDayPeriod(json['dayPeriod'] as String?),
    todoListId: json['todoListId'] as String?,
  );

  factory TaskModel.fromFirestore(
    String id,
    Map<String, dynamic> data, {
    List<TaskModel> subtasks = const [],
  }) => TaskModel(
    id: id,
    title: data['title'] as String? ?? '',
    description: data['description'] as String?,
    color: data['color'] as String? ?? '#4F52B2',
    icon: data['icon'] as String? ?? 'task',
    durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 30,
    scheduledAt: _parseDateTime(data['scheduledAt']),
    status: _parseStatus(data['status'] as String? ?? 'PENDING'),
    sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
    isInbox: data['isInbox'] as bool? ?? false,
    startedAt: _parseDateTime(data['startedAt']),
    completedAt: _parseDateTime(data['completedAt']),
    alarmAt: _parseDateTime(data['alarmAt']),
    reminderLeadMinutes: (data['reminderLeadMinutes'] as num?)?.toInt(),
    isTimed: data['isTimed'] as bool? ?? false,
    parentTaskId: data['parentTaskId'] as String?,
    subtasks: subtasks,
    reward: data['reward'] as String?,
    energyLevel: EnergyLevelX.fromApiNullable(data['energyLevel'] as String?),
    motivation: data['motivation'] as String?,
    transitionBufferMinutes:
        (data['transitionBufferMinutes'] as num?)?.toInt() ?? 0,
    recurrenceType: _parseRecurrenceType(data['recurrenceType'] as String?),
    recurrenceInterval: (data['recurrenceInterval'] as num?)?.toInt() ?? 1,
    recurrenceUnit: _parseRecurrenceUnit(data['recurrenceUnit'] as String?),
    recurrenceSeriesId: data['recurrenceSeriesId'] as String?,
    recurrenceRootId: data['recurrenceRootId'] as String?,
    recurrenceUntil: data['recurrenceUntil'] as String?,
    occurrenceDate: data['occurrenceDate'] as String?,
    recurrenceException: _parseRecurrenceException(
      data['recurrenceException'] as String?,
    ),
    recurrenceOwnedFields: _parseOwnedFields(data['recurrenceOwnedFields']),
    priority: _parsePriority(data['priority'] as String?),
    dayPeriod: _parseDayPeriod(data['dayPeriod'] as String?),
    todoListId: data['todoListId'] as String?,
  );

  Map<String, dynamic> toFirestoreMap({bool includeId = false}) => {
    if (includeId) 'id': id,
    'title': title,
    'description': description,
    'color': color,
    'icon': icon,
    'durationMinutes': durationMinutes,
    'scheduledAt': scheduledAt != null
        ? Timestamp.fromDate(scheduledAt!.toUtc())
        : null,
    'status': statusApiValue,
    'sortOrder': sortOrder,
    'isInbox': isInbox,
    'startedAt': startedAt != null
        ? Timestamp.fromDate(startedAt!.toUtc())
        : null,
    'completedAt': completedAt != null
        ? Timestamp.fromDate(completedAt!.toUtc())
        : null,
    'alarmAt': alarmAt != null ? Timestamp.fromDate(alarmAt!.toUtc()) : null,
    'reminderLeadMinutes': reminderLeadMinutes,
    'isTimed': isTimed,
    'parentTaskId': parentTaskId,
    'reward': reward,
    'energyLevel': energyLevel?.apiValue,
    'motivation': motivation,
    'transitionBufferMinutes': transitionBufferMinutes,
    'recurrenceType': _recurrenceTypeApi(recurrenceType),
    'recurrenceInterval': recurrenceInterval,
    'recurrenceUnit': _recurrenceUnitApi(recurrenceUnit),
    'recurrenceSeriesId': recurrenceSeriesId,
    'recurrenceRootId': recurrenceRootId,
    'recurrenceUntil': recurrenceUntil,
    'occurrenceDate': occurrenceDate,
    'recurrenceException': _recurrenceExceptionApi(recurrenceException),
    'recurrenceOwnedFields': recurrenceOwnedFields,
    'priority': priorityApiValue,
    'dayPeriod': dayPeriodApiValue,
    'todoListId': todoListId,
  };

  String get statusApiValue => switch (status) {
    TaskStatus.pending => 'PENDING',
    TaskStatus.inProgress => 'IN_PROGRESS',
    TaskStatus.paused => 'PAUSED',
    TaskStatus.completed => 'COMPLETED',
    TaskStatus.skipped => 'SKIPPED',
  };

  String get priorityApiValue => switch (priority) {
    TaskPriority.high => 'HIGH',
    TaskPriority.medium => 'MEDIUM',
    TaskPriority.low => 'LOW',
    TaskPriority.none => 'NONE',
  };

  String get dayPeriodApiValue => switch (dayPeriod) {
    DayPeriod.anytime => 'ANYTIME',
    DayPeriod.morning => 'MORNING',
    DayPeriod.daytime => 'DAYTIME',
    DayPeriod.evening => 'EVENING',
  };

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? color,
    String? icon,
    int? durationMinutes,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
    TaskStatus? status,
    int? sortOrder,
    bool? isInbox,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? alarmAt,
    bool clearAlarmAt = false,
    int? reminderLeadMinutes,
    bool clearReminderLeadMinutes = false,
    bool? isTimed,
    String? parentTaskId,
    List<TaskModel>? subtasks,
    String? reward,
    EnergyLevel? energyLevel,
    String? motivation,
    int? transitionBufferMinutes,
    RecurrenceType? recurrenceType,
    int? recurrenceInterval,
    RecurrenceUnit? recurrenceUnit,
    String? recurrenceSeriesId,
    String? recurrenceRootId,
    String? recurrenceUntil,
    bool clearRecurrenceUntil = false,
    String? occurrenceDate,
    RecurrenceExceptionKind? recurrenceException,
    List<String>? recurrenceOwnedFields,
    TaskPriority? priority,
    DayPeriod? dayPeriod,
    String? todoListId,
    bool clearTodoListId = false,
  }) => TaskModel(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    color: color ?? this.color,
    icon: icon ?? this.icon,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    scheduledAt: clearScheduledAt ? null : (scheduledAt ?? this.scheduledAt),
    status: status ?? this.status,
    sortOrder: sortOrder ?? this.sortOrder,
    isInbox: isInbox ?? this.isInbox,
    startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
    completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    alarmAt: clearAlarmAt ? null : (alarmAt ?? this.alarmAt),
    reminderLeadMinutes: clearReminderLeadMinutes
        ? null
        : (reminderLeadMinutes ?? this.reminderLeadMinutes),
    isTimed: isTimed ?? this.isTimed,
    parentTaskId: parentTaskId ?? this.parentTaskId,
    subtasks: subtasks ?? this.subtasks,
    reward: reward ?? this.reward,
    energyLevel: energyLevel ?? this.energyLevel,
    motivation: motivation ?? this.motivation,
    transitionBufferMinutes:
        transitionBufferMinutes ?? this.transitionBufferMinutes,
    recurrenceType: recurrenceType ?? this.recurrenceType,
    recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
    recurrenceUnit: recurrenceUnit ?? this.recurrenceUnit,
    recurrenceSeriesId: recurrenceSeriesId ?? this.recurrenceSeriesId,
    recurrenceRootId: recurrenceRootId ?? this.recurrenceRootId,
    recurrenceUntil: clearRecurrenceUntil
        ? null
        : (recurrenceUntil ?? this.recurrenceUntil),
    occurrenceDate: occurrenceDate ?? this.occurrenceDate,
    recurrenceException: recurrenceException ?? this.recurrenceException,
    recurrenceOwnedFields: recurrenceOwnedFields ?? this.recurrenceOwnedFields,
    priority: priority ?? this.priority,
    dayPeriod: dayPeriod ?? this.dayPeriod,
    todoListId: clearTodoListId ? null : (todoListId ?? this.todoListId),
  );

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    if (value is String) return DateTime.parse(value).toLocal();
    return null;
  }

  static String _recurrenceTypeApi(RecurrenceType type) => switch (type) {
    RecurrenceType.none => 'NONE',
    RecurrenceType.daily => 'DAILY',
    RecurrenceType.weekly => 'WEEKLY',
    RecurrenceType.monthly => 'MONTHLY',
    RecurrenceType.yearly => 'YEARLY',
    RecurrenceType.custom => 'CUSTOM',
  };

  static RecurrenceType _parseRecurrenceType(String? value) => switch (value) {
    'DAILY' => RecurrenceType.daily,
    'WEEKLY' => RecurrenceType.weekly,
    'MONTHLY' => RecurrenceType.monthly,
    'YEARLY' => RecurrenceType.yearly,
    'CUSTOM' => RecurrenceType.custom,
    _ => RecurrenceType.none,
  };

  static RecurrenceUnit? _parseRecurrenceUnit(String? value) => switch (value) {
    'DAYS' => RecurrenceUnit.days,
    'WEEKS' => RecurrenceUnit.weeks,
    'MONTHS' => RecurrenceUnit.months,
    _ => null,
  };

  static String? _recurrenceUnitApi(RecurrenceUnit? unit) => switch (unit) {
    RecurrenceUnit.days => 'DAYS',
    RecurrenceUnit.weeks => 'WEEKS',
    RecurrenceUnit.months => 'MONTHS',
    null => null,
  };

  static RecurrenceExceptionKind _parseRecurrenceException(String? value) =>
      switch (value) {
        'OVERRIDE' => RecurrenceExceptionKind.override,
        'SKIP' => RecurrenceExceptionKind.skip,
        _ => RecurrenceExceptionKind.none,
      };

  static List<String>? _parseOwnedFields(dynamic value) {
    if (value is! List) return null;
    return [for (final item in value) '$item'];
  }

  static String? _recurrenceExceptionApi(RecurrenceExceptionKind kind) =>
      switch (kind) {
        RecurrenceExceptionKind.override => 'OVERRIDE',
        RecurrenceExceptionKind.skip => 'SKIP',
        RecurrenceExceptionKind.none => null,
      };

  static TaskStatus _parseStatus(String status) => switch (status) {
    'PENDING' => TaskStatus.pending,
    'IN_PROGRESS' => TaskStatus.inProgress,
    'PAUSED' => TaskStatus.paused,
    'COMPLETED' => TaskStatus.completed,
    'SKIPPED' => TaskStatus.skipped,
    _ => TaskStatus.pending,
  };

  static TaskPriority _parsePriority(String? value) => switch (value) {
    'HIGH' => TaskPriority.high,
    'MEDIUM' => TaskPriority.medium,
    'LOW' => TaskPriority.low,
    _ => TaskPriority.none,
  };

  static DayPeriod _parseDayPeriod(String? value) => switch (value) {
    'MORNING' => DayPeriod.morning,
    'DAYTIME' => DayPeriod.daytime,
    'EVENING' => DayPeriod.evening,
    _ => DayPeriod.anytime,
  };

  bool get isActive => status == TaskStatus.inProgress;
  bool get isCompleted => status == TaskStatus.completed;
  bool get hasSubtasks => subtasks.isNotEmpty;
  bool get hasReward => reward != null && reward!.isNotEmpty;
  bool get hasMotivation => motivation != null && motivation!.isNotEmpty;
  bool get isVirtualOccurrence => RecurrenceOccurrence.isVirtualId(id);

  bool get isSeriesMaster =>
      !isVirtualOccurrence &&
      recurrenceType != RecurrenceType.none &&
      occurrenceDate == null &&
      recurrenceException == RecurrenceExceptionKind.none;

  bool get isRecurring =>
      recurrenceSeriesId != null || recurrenceType != RecurrenceType.none;

  /// THIS rename (or any owned title). Group-only / status-only overrides
  /// are not unique; those still inherit the series name.
  bool get hasUniqueOccurrenceTitle =>
      recurrenceException == RecurrenceExceptionKind.override &&
      (recurrenceOwnedFields?.contains(RecurrencePatch.title) ?? false);

  int get completedSubtaskCount => subtasks.where((s) => s.isCompleted).length;

  DateTime get endTime {
    final start = scheduledAt ?? DateTime.now();
    return start.add(
      Duration(minutes: durationMinutes + transitionBufferMinutes),
    );
  }

  DateTime get taskEndTime {
    final start = scheduledAt ?? DateTime.now();
    return start.add(Duration(minutes: durationMinutes));
  }
}

class TimelineModel {
  final DateTime date;
  final List<TaskModel> tasks;
  final TaskModel? activeTask;

  const TimelineModel({
    required this.date,
    required this.tasks,
    this.activeTask,
  });

  factory TimelineModel.fromJson(Map<String, dynamic> json) => TimelineModel(
    date: DateTime.parse(json['date'] as String),
    tasks: (json['tasks'] as List)
        .map((t) => TaskModel.fromJson(t as Map<String, dynamic>))
        .toList(),
    activeTask: json['activeTask'] != null
        ? TaskModel.fromJson(json['activeTask'] as Map<String, dynamic>)
        : null,
  );
}

class CompletionCounts {
  const CompletionCounts({
    required this.today,
    required this.thisWeek,
    this.total = 0,
    this.streak = 0,
  });

  final int today;
  final int thisWeek;
  final int total;
  final int streak;
}

/// Consecutive days with at least one completed task.
/// Today is optional: if nothing is done yet today, yesterday still counts.
int florienCompletionStreak(Iterable<DateTime> completionDays, DateTime now) {
  final days = {
    for (final day in completionDays) DateTime(day.year, day.month, day.day),
  };
  final today = DateTime(now.year, now.month, now.day);
  var cursor = days.contains(today)
      ? today
      : today.subtract(const Duration(days: 1));
  if (!days.contains(cursor)) return 0;
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// True when [targetDate] is a different calendar day than [now].
/// Moving a started task off today should clear start state and close focus.
bool florienRescheduleLeavesToday(DateTime targetDate, DateTime now) {
  return DateTime(targetDate.year, targetDate.month, targetDate.day) !=
      DateTime(now.year, now.month, now.day);
}

class FocusSessionModel {
  static const standaloneTaskId = '__standalone__';

  final String taskId;
  final String title;
  final String color;
  final int durationMinutes;
  final TaskStatus status;
  final DateTime startedAt;
  final int elapsedSeconds;
  final int remainingSeconds;
  final double progressPercent;

  const FocusSessionModel({
    required this.taskId,
    required this.title,
    required this.color,
    required this.durationMinutes,
    required this.status,
    required this.startedAt,
    required this.elapsedSeconds,
    required this.remainingSeconds,
    required this.progressPercent,
  });

  factory FocusSessionModel.fromJson(Map<String, dynamic> json) =>
      FocusSessionModel(
        taskId: json['taskId'] as String,
        title: json['title'] as String,
        color: json['color'] as String,
        durationMinutes: json['durationMinutes'] as int,
        status: TaskModel._parseStatus(json['status'] as String),
        startedAt: DateTime.parse(json['startedAt'] as String),
        elapsedSeconds: json['elapsedSeconds'] as int,
        remainingSeconds: json['remainingSeconds'] as int,
        progressPercent: (json['progressPercent'] as num).toDouble(),
      );

  bool get isStandalone => taskId == standaloneTaskId;
  bool get isPaused => status == TaskStatus.paused;
  bool get isActive => status == TaskStatus.inProgress;

  String get remainingFormatted {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
