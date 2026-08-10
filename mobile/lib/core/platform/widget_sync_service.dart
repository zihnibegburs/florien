import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:florien/core/config/platform_config.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/models.dart';

class WidgetSyncService {
  static const _activeTitle = 'active_task_title';
  static const _activeRemaining = 'active_task_remaining';
  static const _nextTitle = 'next_task_title';
  static const _nextTime = 'next_task_time';
  static const _taskCount = 'task_count';
  static const _dateLabel = 'date_label';
  static const _subtitle = 'widget_subtitle';
  static const _widgetTitle = 'widget_title';
  static const _taskCountLabel = 'task_count_label';

  static bool _available = false;

  static bool get isAvailable => _available;

  static Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await HomeWidget.setAppGroupId(PlatformConfig.appGroupId);
      _available = true;
    } on PlatformException catch (e) {
      _available = false;
      debugPrint('Widget init skipped (App Group not configured): ${e.message}');
    } catch (e) {
      _available = false;
      debugPrint('Widget init: $e');
    }
  }

  static Future<void> syncTimeline(
    TimelineModel timeline, {
    FocusSessionModel? session,
    String language = 'tr',
  }) async {
    if (kIsWeb || !_available) return;

    final s = S(language);
    final dateLocale = dateLocaleFor(language);

    try {
      final pending = timeline.tasks.where((t) => !t.isCompleted).toList();
      final next = pending.isEmpty
          ? null
          : pending.firstWhere(
              (t) => session == null || t.id != session.taskId,
              orElse: () => pending.first,
            );

      final dateLabel = DateFormat('d MMM', dateLocale).format(timeline.date);
      String subtitle;
      String title;

      if (session != null && (session.isActive || session.isPaused)) {
        title = session.title;
        final remaining = session.remainingFormatted;
        subtitle = session.isPaused
            ? s.widgetPausedSubtitle(remaining)
            : s.widgetActiveSubtitle(remaining);
        await HomeWidget.saveWidgetData<String>(_activeTitle, title);
        await HomeWidget.saveWidgetData<String>(_activeRemaining, remaining);
      } else if (next != null) {
        title = next.title;
        final time = next.scheduledAt != null
            ? DateFormat('HH:mm').format(next.scheduledAt!.toLocal())
            : '--:--';
        subtitle = s.widgetNextSubtitle(time);
        await HomeWidget.saveWidgetData<String>(_nextTitle, title);
        await HomeWidget.saveWidgetData<String>(_nextTime, time);
      } else {
        title = s.noPlanWidget;
        subtitle = 'Florien · $dateLabel';
      }

      await HomeWidget.saveWidgetData<String>(_subtitle, subtitle);
      await HomeWidget.saveWidgetData<String>(_widgetTitle, title);
      await HomeWidget.saveWidgetData<int>(_taskCount, timeline.tasks.length);
      await HomeWidget.saveWidgetData<String>(_taskCountLabel, s.taskCount(timeline.tasks.length));
      await HomeWidget.saveWidgetData<String>(_dateLabel, dateLabel);
      await HomeWidget.saveWidgetData<String>(
        'tasks_json',
        jsonEncode(timeline.tasks.take(5).map((t) => {
              'title': t.title,
              'time': t.scheduledAt != null
                  ? DateFormat('HH:mm').format(t.scheduledAt!.toLocal())
                  : '--:--',
              'color': t.color,
              'done': t.isCompleted,
            }).toList()),
      );

      await HomeWidget.updateWidget(
        iOSName: PlatformConfig.iosWidgetName,
        androidName: PlatformConfig.androidWidgetClass,
      );
    } on PlatformException catch (e) {
      debugPrint('Widget sync skipped: ${e.message}');
    } catch (e) {
      debugPrint('Widget sync error: $e');
    }
  }
}
