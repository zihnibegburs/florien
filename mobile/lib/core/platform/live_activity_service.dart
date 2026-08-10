import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:live_activities/live_activities.dart';
import 'package:florien/core/config/platform_config.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/storage/local_focus_storage.dart';

class LiveActivityService {
  LiveActivityService._();
  static final LiveActivityService instance = LiveActivityService._();

  final LiveActivities _plugin = LiveActivities();
  String? _activeTaskId;
  bool _initialized = false;

  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await _plugin.init(
        appGroupId: PlatformConfig.appGroupId,
        urlScheme: 'florien',
        requestAndroidNotificationPermission: true,
      );
      _initialized = true;
    } on PlatformException catch (e) {
      _initialized = false;
      debugPrint('Live Activity init skipped: ${e.message}');
    } catch (e) {
      _initialized = false;
      debugPrint('Live Activity init: $e');
    }
  }

  Future<void> syncSession(LocalFocusSessionData data, {String language = 'tr'}) async {
    if (!_initialized) return;

    final session = data.toFocusSessionModel();
    final s = S(language);
    final now = DateTime.now();
    final timerEndDate = data.isPaused
        ? now.add(Duration(seconds: session.remainingSeconds))
        : data.timerEndDate;

    final payload = <String, dynamic>{
      'taskTitle': data.title,
      'remaining': session.remainingFormatted,
      'progress': session.progressPercent,
      'color': data.color,
      'paused': data.isPaused ? 1 : 0,
      'statusLabel': data.isPaused ? s.paused : s.focus,
      'timerStartDate': data.startedAt.millisecondsSinceEpoch,
      'timerEndDate': timerEndDate.millisecondsSinceEpoch,
    };

    try {
      final enabled = await _plugin.areActivitiesEnabled();
      if (!enabled) return;

      if (_activeTaskId != null && _activeTaskId != data.taskId) {
        await endActivity();
      }

      await _plugin.createOrUpdateActivity(
        data.taskId,
        payload,
        activityTag: 'florien_focus',
        removeWhenAppIsKilled: false,
      );
      _activeTaskId = data.taskId;
    } on PlatformException catch (e) {
      debugPrint('Live Activity sync skipped: ${e.message}');
    } catch (e) {
      debugPrint('Live Activity sync: $e');
    }
  }

  Future<void> endActivity() async {
    if (!_initialized || _activeTaskId == null) return;
    try {
      await _plugin.endActivity(_activeTaskId!, activityTag: 'florien_focus');
    } on PlatformException catch (e) {
      debugPrint('Live Activity end skipped: ${e.message}');
    } catch (e) {
      debugPrint('Live Activity end: $e');
    } finally {
      _activeTaskId = null;
    }
  }

  LiveActivities get plugin => _plugin;
  bool get isInitialized => _initialized;
}
