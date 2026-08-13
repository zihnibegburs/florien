import 'package:flutter/material.dart' hide DayPeriod;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/daily_planner_tab.dart';
import 'package:florien/features/todo/todo_home_screen.dart';

class _EmptyInboxNotifier extends InboxNotifier {
  @override
  Future<List<TaskModel>> build() async => const [];
}

class _EmptyListsNotifier extends TodoListsNotifier {
  @override
  Future<List<TodoListDefinition>> build() async => const [];
}

void main() {
  testWidgets('daily planner opens its quick and detailed creation flows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyTimelineProvider.overrideWith(
            (ref, date) async => TimelineModel(date: date, tasks: const []),
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: DailyPlannerTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HER ZAMAN (0)'), findsOneWidget);
    expect(find.text('SABAH (0)'), findsOneWidget);
    expect(find.text('GÜNDÜZ (0)'), findsOneWidget);
    expect(find.text('AKŞAM (0)'), findsOneWidget);

    await tester.tap(find.byTooltip('Günlük görev ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Sırada ne var?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('daily-period-chip')));
    await tester.pumpAndSettle();
    expect(find.text('Günün saati'), findsOneWidget);
    expect(find.text('Her zaman'), findsOneWidget);
    expect(find.text('Sabah'), findsOneWidget);
    expect(find.text('Gündüz'), findsOneWidget);
    expect(find.text('Akşam'), findsOneWidget);
    expect(find.text('Etkinlik'), findsOneWidget);
    expect(find.text('Zamanında'), findsOneWidget);
    expect(find.text('Tüm gün'), findsOneWidget);
    expect(find.text('Yapılacaklar'), findsOneWidget);

    await tester.tap(find.text('Sabah'));
    await tester.pumpAndSettle();
    expect(find.text('SABAH'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('daily-recurrence-chip')));
    await tester.pumpAndSettle();
    expect(find.text('Yinelemek'), findsOneWidget);
    await tester.tap(find.text('Her hafta'));
    await tester.pumpAndSettle();
    expect(find.text('HER HAFTA'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('daily-details-chip')));
    await tester.pumpAndSettle();
    expect(find.text('Görev ekle'), findsOneWidget);
    expect(find.text('Günün saati'), findsOneWidget);
    expect(find.text('Tarih'), findsOneWidget);
    expect(find.text('Süre'), findsOneWidget);
    expect(find.text('Yinelemek'), findsOneWidget);
  });

  testWidgets('daily destination is between todo and focus', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxProvider.overrideWith(_EmptyInboxNotifier.new),
          todoListsProvider.overrideWith(_EmptyListsNotifier.new),
          dailyTimelineProvider.overrideWith(
            (ref, date) async => TimelineModel(date: date, tasks: const []),
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const TodoHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('To-do'), findsWidgets);
    expect(find.text('Günlük'), findsOneWidget);
    expect(find.text('Odaklan'), findsOneWidget);

    await tester.tap(find.text('Günlük'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('daily-planner-page')), findsOneWidget);
  });

  testWidgets('daily task opens actions and only delete removes it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var deleted = false;
    final task = TaskModel(
      id: 'daily-task-1',
      title: 'Günlük deneme görevi',
      color: '#6C5CE7',
      icon: 'task',
      durationMinutes: 15,
      scheduledAt: DateTime.now(),
      status: TaskStatus.pending,
      sortOrder: 0,
      isInbox: false,
      dayPeriod: DayPeriod.daytime,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyTimelineProvider.overrideWith(
            (ref, date) async =>
                TimelineModel(date: date, tasks: deleted ? const [] : [task]),
          ),
          dailyDeleteTaskProvider.overrideWithValue((id) async {
            expect(id, 'daily-task-1');
            deleted = true;
          }),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: DailyPlannerTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Günlük deneme görevi'));
    await tester.pumpAndSettle();
    expect(find.text('Bir kopya oluştur'), findsOneWidget);
    expect(find.text('Yapılacaklara taşı'), findsOneWidget);
    expect(find.text('Yeniden planla'), findsOneWidget);
    expect(find.text('Yarın için yeniden planla'), findsOneWidget);
    expect(find.text('Ayrım öner'), findsOneWidget);
    expect(find.text('Görevi başlat'), findsOneWidget);
    expect(find.text('Görevi düzenle'), findsOneWidget);
    expect(find.text('Görevi sil'), findsOneWidget);

    await tester.tap(find.text('Bir kopya oluştur'));
    await tester.pump();
    expect(deleted, isFalse);
    expect(find.text('Görevi sil'), findsOneWidget);

    await tester.tap(find.text('Görevi sil'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
    expect(find.text('Günlük deneme görevi'), findsNothing);
  });

  testWidgets('completed daily tasks move to the conditional final group', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final completed = TaskModel(
      id: 'completed-daily-task',
      title: 'Biten günlük görev',
      color: '#6C5CE7',
      icon: 'task',
      durationMinutes: 15,
      scheduledAt: DateTime.now(),
      status: TaskStatus.completed,
      sortOrder: 0,
      isInbox: false,
      dayPeriod: DayPeriod.daytime,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyTimelineProvider.overrideWith(
            (ref, date) async => TimelineModel(date: date, tasks: [completed]),
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: DailyPlannerTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GÜNDÜZ (0)'), findsOneWidget);
    expect(find.text('TAMAMLANDI (1)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('daily-completed-section')),
      findsOneWidget,
    );
    expect(find.text(completed.title), findsOneWidget);
  });

  testWidgets('daily task action moves the task to default todo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? movedTaskId;
    final task = TaskModel(
      id: 'move-to-todo-task',
      title: 'To-do listesine taşınacak',
      color: '#6C5CE7',
      icon: 'task',
      durationMinutes: 20,
      scheduledAt: DateTime.now(),
      status: TaskStatus.pending,
      sortOrder: 0,
      isInbox: false,
      dayPeriod: DayPeriod.evening,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyTimelineProvider.overrideWith(
            (ref, date) async => TimelineModel(date: date, tasks: [task]),
          ),
          dailyMoveToTodoProvider.overrideWithValue((id) async {
            movedTaskId = id;
          }),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: DailyPlannerTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(task.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yapılacaklara taşı'));
    await tester.pumpAndSettle();

    expect(movedTaskId, task.id);
    expect(find.text('Yapılacaklara taşı'), findsNothing);
  });
}
