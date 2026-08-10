import 'dart:convert';

import 'package:florien/core/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalFocusSessionData {
  const LocalFocusSessionData({
    required this.taskId,
    required this.title,
    required this.color,
    required this.durationMinutes,
    required this.startedAt,
    this.accumulatedPauseMs = 0,
    this.pausedAt,
  });

  final String taskId;
  final String title;
  final String color;
  final int durationMinutes;
  final DateTime startedAt;
  final int accumulatedPauseMs;
  final DateTime? pausedAt;

  bool get isPaused => pausedAt != null;
  bool get isStandalone => taskId == FocusSessionModel.standaloneTaskId;

  factory LocalFocusSessionData.standalone({
    required String title,
    int durationMinutes = 25,
    String color = '#4F52B2',
  }) => LocalFocusSessionData(
    taskId: FocusSessionModel.standaloneTaskId,
    title: title,
    color: color,
    durationMinutes: durationMinutes,
    startedAt: DateTime.now(),
  );

  factory LocalFocusSessionData.fromTask(TaskModel task) =>
      LocalFocusSessionData(
        taskId: task.id,
        title: task.title,
        color: task.color,
        durationMinutes: task.durationMinutes,
        startedAt: DateTime.now(),
      );

  factory LocalFocusSessionData.fromJson(Map<String, dynamic> json) =>
      LocalFocusSessionData(
        taskId: json['taskId'] as String,
        title: json['title'] as String,
        color: json['color'] as String,
        durationMinutes: json['durationMinutes'] as int,
        startedAt: DateTime.parse(json['startedAt'] as String),
        accumulatedPauseMs: json['accumulatedPauseMs'] as int? ?? 0,
        pausedAt: json['pausedAt'] != null
            ? DateTime.parse(json['pausedAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'title': title,
    'color': color,
    'durationMinutes': durationMinutes,
    'startedAt': startedAt.toIso8601String(),
    'accumulatedPauseMs': accumulatedPauseMs,
    if (pausedAt != null) 'pausedAt': pausedAt!.toIso8601String(),
  };

  LocalFocusSessionData copyWith({
    String? taskId,
    String? title,
    String? color,
    int? durationMinutes,
    DateTime? startedAt,
    int? accumulatedPauseMs,
    DateTime? pausedAt,
    bool clearPausedAt = false,
  }) => LocalFocusSessionData(
    taskId: taskId ?? this.taskId,
    title: title ?? this.title,
    color: color ?? this.color,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    startedAt: startedAt ?? this.startedAt,
    accumulatedPauseMs: accumulatedPauseMs ?? this.accumulatedPauseMs,
    pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
  );

  DateTime get timerEndDate {
    final totalMs = durationMinutes * 60 * 1000;
    return startedAt.add(Duration(milliseconds: totalMs + accumulatedPauseMs));
  }

  FocusSessionModel toFocusSessionModel([DateTime? now]) {
    final current = now ?? DateTime.now();
    final totalSeconds = durationMinutes * 60;
    var pauseMs = accumulatedPauseMs;
    if (pausedAt != null) {
      pauseMs += current.difference(pausedAt!).inMilliseconds;
    }
    final elapsedMs = current.difference(startedAt).inMilliseconds - pauseMs;
    final elapsedSeconds = elapsedMs ~/ 1000;
    final clampedElapsed = elapsedSeconds.clamp(0, totalSeconds);
    final remainingSeconds = (totalSeconds - clampedElapsed).clamp(
      0,
      totalSeconds,
    );
    final progress = totalSeconds > 0
        ? (clampedElapsed * 100.0 / totalSeconds)
        : 0.0;

    return FocusSessionModel(
      taskId: taskId,
      title: title,
      color: color,
      durationMinutes: durationMinutes,
      status: isPaused ? TaskStatus.paused : TaskStatus.inProgress,
      startedAt: startedAt,
      elapsedSeconds: clampedElapsed,
      remainingSeconds: remainingSeconds,
      progressPercent: progress.clamp(0, 100).toDouble(),
    );
  }
}

class LocalFocusStorage {
  static const _sessionKey = 'local_focus_session';

  Future<LocalFocusSessionData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return LocalFocusSessionData.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> save(LocalFocusSessionData session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
