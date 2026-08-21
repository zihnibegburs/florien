import 'dart:convert';

enum FlorienNotificationKind {
  taskReminder,
  taskBatch,
  morningSummary,
  motivation,
  dailyReview,
  weeklyReview,
  focusTimer,
}

enum NotificationTargetScreen {
  taskFocus,
  dailyPlan,
  dailyReview,
  weeklyPlanMonday,
}

class FlorienNotificationPayload {
  const FlorienNotificationPayload({
    required this.kind,
    required this.accountId,
    required this.target,
    this.taskId,
    this.occurrenceKey,
    this.taskIds = const [],
  });

  final FlorienNotificationKind kind;
  final String accountId;
  final NotificationTargetScreen target;
  final String? taskId;
  final String? occurrenceKey;
  final List<String> taskIds;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'accountId': accountId,
    'target': target.name,
    if (taskId != null) 'taskId': taskId,
    if (occurrenceKey != null) 'occurrenceKey': occurrenceKey,
    if (taskIds.isNotEmpty) 'taskIds': taskIds,
  };

  String encode() => jsonEncode(toJson());

  static FlorienNotificationPayload? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final kindName = json['kind'] as String?;
      final targetName = json['target'] as String?;
      final accountId = json['accountId'] as String?;
      if (kindName == null || targetName == null || accountId == null) {
        return null;
      }
      final kind = FlorienNotificationKind.values.firstWhere(
        (value) => value.name == kindName,
        orElse: () => FlorienNotificationKind.taskReminder,
      );
      final target = NotificationTargetScreen.values.firstWhere(
        (value) => value.name == targetName,
        orElse: () => NotificationTargetScreen.dailyPlan,
      );
      final taskIdsRaw = json['taskIds'];
      return FlorienNotificationPayload(
        kind: kind,
        accountId: accountId,
        target: target,
        taskId: json['taskId'] as String?,
        occurrenceKey: json['occurrenceKey'] as String?,
        taskIds: taskIdsRaw is List
            ? taskIdsRaw.map((e) => e.toString()).toList()
            : const [],
      );
    } catch (_) {
      // Legacy payloads were bare task ids.
      return FlorienNotificationPayload(
        kind: FlorienNotificationKind.taskReminder,
        accountId: '',
        target: NotificationTargetScreen.taskFocus,
        taskId: raw,
      );
    }
  }
}
