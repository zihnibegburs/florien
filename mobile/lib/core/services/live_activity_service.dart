import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:live_activities/live_activities.dart';

class FlorienLiveActivityService {
  FlorienLiveActivityService();

  static const _appGroupId = 'group.com.florien.app';
  static const _focusId = 'florien-focus';
  static const _nextPlanId = 'florien-next-plan';
  static const _dailyProgressId = 'florien-daily-progress';
  static const _reminderId = 'florien-upcoming-reminder';
  final LiveActivities _activities = LiveActivities();
  bool _initialized = false;
  DateTime? _lastFocusUpdateAt;
  String? _lastFocusSignature;

  Future<void> syncFocus({
    required String title,
    required String? taskIcon,
    required bool usesDefaultFocusIcon,
    required int remainingSeconds,
    required int totalSeconds,
    required bool isRunning,
    required LiveActivityPreferences preferences,
  }) async {
    if (!preferences.focusTimerEnabled || remainingSeconds <= 0) {
      await _end(_focusId, 'focus');
      _lastFocusUpdateAt = null;
      _lastFocusSignature = null;
      return;
    }
    final now = DateTime.now();
    final signature =
        '$title:$taskIcon:$usesDefaultFocusIcon:$totalSeconds:$isRunning';
    if (_lastFocusSignature == signature &&
        _lastFocusUpdateAt != null &&
        now.difference(_lastFocusUpdateAt!) < const Duration(seconds: 30)) {
      return;
    }
    _lastFocusSignature = signature;
    _lastFocusUpdateAt = now;
    await _upsert(
      _focusId,
      'focus',
      _data(
        kind: 'focus',
        title: title,
        taskIcon: taskIcon,
        usesDefaultFocusIcon: usesDefaultFocusIcon,
        subtitle: isRunning
            ? ActiveLanguage.s('Odaklanma sürüyor')
            : ActiveLanguage.s('Odaklanma duraklatıldı'),
        remaining: _durationLabel(remainingSeconds),
        start: now.subtract(Duration(seconds: totalSeconds - remainingSeconds)),
        end: now.add(Duration(seconds: remainingSeconds)),
        paused: !isRunning,
      ),
    );
  }

  Future<void> applyPreferences(LiveActivityPreferences preferences) async {
    if (!preferences.focusTimerEnabled) await _end(_focusId, 'focus');
    await _end(_nextPlanId, 'next-plan');
    await _end(_dailyProgressId, 'daily-progress');
    await _end(_reminderId, 'upcoming-reminder');
  }

  Future<void> endFocus() async {
    await _end(_focusId, 'focus');
    _lastFocusUpdateAt = null;
    _lastFocusSignature = null;
  }

  Future<void> syncDailyPlan({
    required DateTime date,
    required List<TaskModel> tasks,
    required LiveActivityPreferences preferences,
  }) async {
    await applyPreferences(preferences);
  }

  Future<void> _upsert(String id, String tag, Map<String, dynamic> data) async {
    if (!await _initialize()) return;
    try {
      await _activities.createOrUpdateActivity(
        id,
        data,
        activityTag: tag,
        iOSEnableRemoteUpdates: false,
      );
    } catch (error) {
      debugPrint('Live activity could not be updated: $error');
    }
  }

  Future<void> _end(String id, String tag) async {
    if (!await _initialize()) return;
    try {
      await _activities.endActivity(id, activityTag: tag);
    } catch (_) {}
  }

  Future<bool> _initialize() async {
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return false;
    if (_initialized) return true;
    try {
      await _activities.init(
        appGroupId: _appGroupId,
        urlScheme: 'florien',
        requestAndroidNotificationPermission: false,
      );
      _initialized = true;
      return true;
    } catch (error) {
      debugPrint('Live activities could not be initialized: $error');
      return false;
    }
  }

  Map<String, dynamic> _data({
    required String kind,
    required String title,
    required String? taskIcon,
    required bool usesDefaultFocusIcon,
    required String subtitle,
    required String remaining,
    required DateTime start,
    required DateTime end,
    bool paused = false,
  }) => {
    'activityKind': kind,
    'taskTitle': title,
    'taskIcon': taskIcon ?? '',
    'usesDefaultFocusIcon': usesDefaultFocusIcon ? 1 : 0,
    'statusLabel': subtitle,
    'remaining': remaining,
    'timerStartDate': start.millisecondsSinceEpoch,
    'timerEndDate': end.millisecondsSinceEpoch,
    'paused': paused ? 1 : 0,
    'color': '#8FB6A0',
  };

  String _durationLabel(int seconds) {
    final minutes = seconds ~/ 60;
    return '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  }
}
