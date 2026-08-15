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
  final bool isTimed;
  final String? parentTaskId;
  final List<TaskModel> subtasks;
  final String? reward;
  final EnergyLevel? energyLevel;
  final String? motivation;
  final int transitionBufferMinutes;
  final RecurrenceType recurrenceType;
  final String? recurrenceSeriesId;
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
    this.isTimed = false,
    this.parentTaskId,
    this.subtasks = const [],
    this.reward,
    this.energyLevel,
    this.motivation,
    this.transitionBufferMinutes = 0,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceSeriesId,
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
    recurrenceSeriesId: json['recurrenceSeriesId'] as String?,
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
    isTimed: data['isTimed'] as bool? ?? false,
    parentTaskId: data['parentTaskId'] as String?,
    subtasks: subtasks,
    reward: data['reward'] as String?,
    energyLevel: EnergyLevelX.fromApiNullable(data['energyLevel'] as String?),
    motivation: data['motivation'] as String?,
    transitionBufferMinutes:
        (data['transitionBufferMinutes'] as num?)?.toInt() ?? 0,
    recurrenceType: _parseRecurrenceType(data['recurrenceType'] as String?),
    recurrenceSeriesId: data['recurrenceSeriesId'] as String?,
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
    'isTimed': isTimed,
    'parentTaskId': parentTaskId,
    'reward': reward,
    'energyLevel': energyLevel?.apiValue,
    'motivation': motivation,
    'transitionBufferMinutes': transitionBufferMinutes,
    'recurrenceType': _recurrenceTypeApi(recurrenceType),
    'recurrenceSeriesId': recurrenceSeriesId,
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
    bool? isTimed,
    String? parentTaskId,
    List<TaskModel>? subtasks,
    String? reward,
    EnergyLevel? energyLevel,
    String? motivation,
    int? transitionBufferMinutes,
    RecurrenceType? recurrenceType,
    String? recurrenceSeriesId,
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
    isTimed: isTimed ?? this.isTimed,
    parentTaskId: parentTaskId ?? this.parentTaskId,
    subtasks: subtasks ?? this.subtasks,
    reward: reward ?? this.reward,
    energyLevel: energyLevel ?? this.energyLevel,
    motivation: motivation ?? this.motivation,
    transitionBufferMinutes:
        transitionBufferMinutes ?? this.transitionBufferMinutes,
    recurrenceType: recurrenceType ?? this.recurrenceType,
    recurrenceSeriesId: recurrenceSeriesId ?? this.recurrenceSeriesId,
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
  bool get isRecurring =>
      recurrenceSeriesId != null || recurrenceType != RecurrenceType.none;

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
  const CompletionCounts({required this.today, required this.thisWeek});

  final int today;
  final int thisWeek;
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
