import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/services/home_screen_widget_service.dart';

void main() {
  test('parses supported focus durations from home widget links', () {
    final command = HomeScreenWidgetService.commandFromUri(
      Uri.parse('florien://widget/focus?minutes=30&homeWidget=1'),
    );

    expect(command?.action, HomeWidgetLaunchAction.focus);
    expect(command?.durationMinutes, 30);
  });

  test('uses the prepared focus duration for invalid links', () {
    final command = HomeScreenWidgetService.commandFromUri(
      Uri.parse('florien://widget/focus?minutes=45&homeWidget=1'),
    );

    expect(command?.durationMinutes, 15);
  });

  test('parses task list and quick add widget links', () {
    expect(
      HomeScreenWidgetService.commandFromUri(
        Uri.parse('florien://widget/today?homeWidget=1'),
      )?.action,
      HomeWidgetLaunchAction.today,
    );
    expect(
      HomeScreenWidgetService.commandFromUri(
        Uri.parse('florien://widget/todo/add?homeWidget=1'),
      )?.action,
      HomeWidgetLaunchAction.todoAdd,
    );
    expect(
      HomeScreenWidgetService.commandFromUri(
        Uri.parse('florien://widget/todo?homeWidget=1'),
      )?.action,
      HomeWidgetLaunchAction.todo,
    );
    expect(
      HomeScreenWidgetService.commandFromUri(
        Uri.parse('florien://widget/daily/add?homeWidget=1'),
      )?.action,
      HomeWidgetLaunchAction.dailyAdd,
    );
  });

  test('parses the quick action widget destinations', () {
    expect(
      HomeScreenWidgetService.commandFromUri(
        Uri.parse('florien://widget/ai?homeWidget=1'),
      )?.action,
      HomeWidgetLaunchAction.ai,
    );
    expect(
      HomeScreenWidgetService.commandFromUri(
        Uri.parse('florien://widget/focus/screen?homeWidget=1'),
      )?.action,
      HomeWidgetLaunchAction.focusScreen,
    );
    expect(
      HomeScreenWidgetService.commandFromUri(
        Uri.parse('florien://widget/focus/stop?homeWidget=1'),
      )?.action,
      HomeWidgetLaunchAction.focusStop,
    );
  });

  test('parses task completion links from list widgets', () {
    final command = HomeScreenWidgetService.commandFromUri(
      Uri.parse('florien://widget/task/complete?taskId=task-42&source=daily'),
    );

    expect(command?.action, HomeWidgetLaunchAction.taskComplete);
    expect(command?.taskId, 'task-42');
    expect(command?.isDailyPlan, isTrue);
  });
}
