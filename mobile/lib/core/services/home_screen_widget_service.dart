import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/models.dart';
import 'package:home_widget/home_widget.dart';

enum HomeWidgetLaunchAction {
  focus,
  focusScreen,
  focusStop,
  today,
  todo,
  todoAdd,
  dailyAdd,
  ai,
  taskComplete,
}

class HomeWidgetLaunchCommand {
  const HomeWidgetLaunchCommand({
    required this.action,
    this.durationMinutes,
    this.taskId,
    this.isDailyPlan = false,
  });

  final HomeWidgetLaunchAction action;
  final int? durationMinutes;
  final String? taskId;
  final bool isDailyPlan;
}

abstract final class HomeScreenWidgetService {
  static const _appGroupId = 'group.com.florien.app';
  static const _widgetProviders = [
    (androidName: 'Focus15WidgetProvider', iOSName: 'FlorienFocus15Widget'),
    (
      androidName: 'FocusPresetsWidgetProvider',
      iOSName: 'FlorienFocusPresetsWidget',
    ),
    (androidName: 'FlorienWidgetProvider', iOSName: 'FlorienWidget'),
    (androidName: 'TodoWidgetProvider', iOSName: 'FlorienTodoWidget'),
    (androidName: 'QuickAddWidgetProvider', iOSName: 'FlorienQuickAddWidget'),
    (
      androidName: 'QuickActionsWidgetProvider',
      iOSName: 'FlorienQuickActionsWidget',
    ),
  ];

  static Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      if (Platform.isIOS) await HomeWidget.setAppGroupId(_appGroupId);
      await syncChrome();
    } catch (error) {
      debugPrint('Home widgets could not be initialized: $error');
    }
  }

  static Future<void> syncChrome() async {
    if (kIsWeb) return;
    String s(String source, [Map<String, String> params = const {}]) =>
        ActiveLanguage.s(source, params);
    try {
      if (Platform.isIOS) await HomeWidget.setAppGroupId(_appGroupId);
      await Future.wait([
        HomeWidget.saveWidgetData<String>(
          'chrome_daily_title',
          s('Günlük plan'),
        ),
        HomeWidget.saveWidgetData<String>('chrome_todo_title', s('To-do')),
        HomeWidget.saveWidgetData<String>(
          'chrome_daily_empty',
          s('Bugün için planın boş'),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_todo_empty',
          s('To-do listen şu an boş'),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_empty_hint',
          s('Kendine biraz alan aç.'),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_open_tasks',
          s('{count} tamamlanmamış görev'),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_open_short',
          s('{count} tamamlanmamış'),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_incomplete',
          s('Tamamlanmamış görevler'),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_focus_brand',
          s('Florien · Odaklan'),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_focus_ready',
          s('15 dakikalık alanın hazır'),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_focus_ready_nl',
          s('15 dakikalık\nalanın hazır'),
        ),
        HomeWidget.saveWidgetData<String>('chrome_start', s('▶ Başla')),
        HomeWidget.saveWidgetData<String>(
          'chrome_focus_how_long',
          s('Ne kadar odaklanmak istersin?'),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_min_5',
          s('{minutes} dk', {'minutes': '5'}),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_min_10',
          s('{minutes} dk', {'minutes': '10'}),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_min_15',
          s('{minutes} dk', {'minutes': '15'}),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_min_30',
          s('{minutes} dk', {'minutes': '30'}),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_quick_prompt',
          s('Aklına bir şey mi geldi?'),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_quick_cta',
          s('＋ To-do ekle'),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_ai_prompt',
          s('Planın nedir?'),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_ai_prompt_star',
          s('Planın nedir?   ✦'),
        ),
        HomeWidget.saveWidgetData<String>('chrome_stop', s('Durdur')),
        HomeWidget.saveWidgetData<String>(
          'chrome_stop_a11y',
          s('Odaklanmayı durdur'),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_name_daily',
          s('Günlük Plan'),
        ),
        HomeWidget.saveWidgetData<String>('chrome_name_todo', s('To-do')),
        HomeWidget.saveWidgetData<String>(
          'chrome_name_focus15',
          s('15 dk Odaklan'),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_name_presets',
          s('Odak Süresi'),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_name_quick_add',
          s('Hızlı To-do'),
        ),
        HomeWidget.saveWidgetData<String>(
          'chrome_name_quick_actions',
          s('Florien Hızlı Eylemler'),
        ),
      ]);
      await _refreshWidgets();
    } catch (error) {
      debugPrint('Home widget chrome could not be saved: $error');
    }
  }

  static Future<void> syncDailyPlan({
    required DateTime date,
    required List<TaskModel> tasks,
    required String profileId,
  }) async {
    if (kIsWeb) return;
    final pending = tasks.where((task) => !task.isCompleted).toList();
    final visibleTasks = pending.take(6).toList(growable: false);
    try {
      await initialize();
      await Future.wait([
        HomeWidget.saveWidgetData<int>('daily_pending_count', pending.length),
        HomeWidget.saveWidgetData<String>('widget_profile_id', profileId),
        HomeWidget.saveWidgetData<String>('date_label', _dateLabel(date)),
        for (var index = 0; index < 6; index++)
          ..._saveTaskData(
            prefix: 'daily_task',
            index: index,
            task: index < visibleTasks.length ? visibleTasks[index] : null,
          ),
      ]);
      await _refreshWidgets();
    } catch (error) {
      debugPrint('Home widgets could not be refreshed: $error');
    }
  }

  static Future<void> syncTodo({
    required List<TaskModel> tasks,
    required String profileId,
  }) async {
    if (kIsWeb) return;
    final pending = tasks.where((task) => !task.isCompleted).toList();
    final visibleTasks = pending.take(6).toList(growable: false);
    try {
      await initialize();
      await Future.wait([
        HomeWidget.saveWidgetData<int>('todo_pending_count', pending.length),
        HomeWidget.saveWidgetData<String>('widget_profile_id', profileId),
        for (var index = 0; index < 6; index++)
          ..._saveTaskData(
            prefix: 'todo_task',
            index: index,
            task: index < visibleTasks.length ? visibleTasks[index] : null,
          ),
      ]);
      await _refreshWidgets();
    } catch (error) {
      debugPrint('Home widgets could not be refreshed: $error');
    }
  }

  static Future<void> _refreshWidgets() => Future.wait(
    _widgetProviders.map(
      (provider) => HomeWidget.updateWidget(
        androidName: provider.androidName,
        iOSName: provider.iOSName,
      ),
    ),
  );

  static Future<void> removeCompletedTask({
    required String taskId,
    required bool isDailyPlan,
  }) async {
    if (kIsWeb) return;
    final prefix = isDailyPlan ? 'daily_task' : 'todo_task';
    final countKey = isDailyPlan ? 'daily_pending_count' : 'todo_pending_count';
    try {
      await initialize();
      final taskIds = await Future.wait([
        for (var index = 1; index <= 6; index++)
          HomeWidget.getWidgetData<String>('${prefix}_${index}_id'),
      ]);
      final completedIndex = taskIds.indexOf(taskId);
      if (completedIndex == -1) return;

      final values = await Future.wait([
        for (var index = 1; index <= 6; index++)
          Future.wait([
            HomeWidget.getWidgetData<String>('${prefix}_$index'),
            HomeWidget.getWidgetData<String>('${prefix}_${index}_id'),
            HomeWidget.getWidgetData<String>('${prefix}_${index}_icon'),
          ]),
      ]);
      final remaining = values
          .where(
            (value) => value[1] != taskId && (value[1]?.isNotEmpty ?? false),
          )
          .toList(growable: false);
      final currentCount =
          await HomeWidget.getWidgetData<int>(countKey, defaultValue: 0) ?? 0;

      await Future.wait([
        HomeWidget.saveWidgetData<int>(
          countKey,
          currentCount > 0 ? currentCount - 1 : 0,
        ),
        for (var index = 0; index < 6; index++) ...[
          HomeWidget.saveWidgetData<String>(
            '${prefix}_${index + 1}',
            index < remaining.length ? remaining[index][0] ?? '' : '',
          ),
          HomeWidget.saveWidgetData<String>(
            '${prefix}_${index + 1}_id',
            index < remaining.length ? remaining[index][1] ?? '' : '',
          ),
          HomeWidget.saveWidgetData<String>(
            '${prefix}_${index + 1}_icon',
            index < remaining.length ? remaining[index][2] ?? '' : '',
          ),
        ],
      ]);
      await _refreshWidgets();
    } catch (error) {
      debugPrint('Completed home widget task could not be removed: $error');
    }
  }

  static HomeWidgetLaunchCommand? commandFromUri(Uri? uri) {
    if (uri == null || uri.scheme != 'florien' || uri.host != 'widget') {
      return null;
    }
    return switch (uri.path) {
      '/focus' => HomeWidgetLaunchCommand(
        action: HomeWidgetLaunchAction.focus,
        durationMinutes: _supportedDuration(uri.queryParameters['minutes']),
      ),
      '/focus/screen' => const HomeWidgetLaunchCommand(
        action: HomeWidgetLaunchAction.focusScreen,
      ),
      '/focus/stop' => const HomeWidgetLaunchCommand(
        action: HomeWidgetLaunchAction.focusStop,
      ),
      '/today' => const HomeWidgetLaunchCommand(
        action: HomeWidgetLaunchAction.today,
      ),
      '/todo' => const HomeWidgetLaunchCommand(
        action: HomeWidgetLaunchAction.todo,
      ),
      '/todo/add' => const HomeWidgetLaunchCommand(
        action: HomeWidgetLaunchAction.todoAdd,
      ),
      '/daily/add' => const HomeWidgetLaunchCommand(
        action: HomeWidgetLaunchAction.dailyAdd,
      ),
      '/ai' => const HomeWidgetLaunchCommand(action: HomeWidgetLaunchAction.ai),
      '/task/complete' => _taskCompletionCommand(uri),
      _ => null,
    };
  }

  static HomeWidgetLaunchCommand? _taskCompletionCommand(Uri uri) {
    final taskId = uri.queryParameters['taskId'];
    if (taskId == null || taskId.isEmpty) return null;
    return HomeWidgetLaunchCommand(
      action: HomeWidgetLaunchAction.taskComplete,
      taskId: taskId,
      isDailyPlan: uri.queryParameters['source'] == 'daily',
    );
  }

  static List<Future<void>> _saveTaskData({
    required String prefix,
    required int index,
    required TaskModel? task,
  }) {
    final key = '${prefix}_${index + 1}';
    return [
      HomeWidget.saveWidgetData<String>(key, task?.title ?? ''),
      HomeWidget.saveWidgetData<String>('${key}_id', task?.id ?? ''),
      HomeWidget.saveWidgetData<String>('${key}_icon', task?.icon ?? ''),
    ];
  }

  static int _supportedDuration(String? value) {
    final duration = int.tryParse(value ?? '');
    return switch (duration) {
      5 || 10 || 15 || 30 => duration!,
      _ => 15,
    };
  }

  static String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
}
