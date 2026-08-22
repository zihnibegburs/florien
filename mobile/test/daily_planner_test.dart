import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide DayPeriod;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/services/task_alarm_service.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/premium/premium_membership.dart';
import 'package:florien/features/premium/premium_membership_screen.dart';
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

class _AvailableListsNotifier extends TodoListsNotifier {
  @override
  Future<List<TodoListDefinition>> build() async => const [
    TodoListDefinition(
      id: 'work-list',
      name: 'İşlerim',
      description: 'İş görevleri',
    ),
  ];
}

class _ReadyTaskAlarmService extends TaskAlarmService {
  _ReadyTaskAlarmService() : super(SettingsStorage());

  @override
  Future<TaskAlarmReadiness> prepareTaskAlarm(DateTime alarmAt) async =>
      TaskAlarmReadiness.ready;
}

class _NonPremiumMembershipNotifier extends PremiumMembershipNotifier {
  @override
  Future<PremiumMembership> build() async =>
      const PremiumMembership(storeAvailable: false);
}

class _ActivePremiumMembershipNotifier extends PremiumMembershipNotifier {
  @override
  Future<PremiumMembership> build() async =>
      const PremiumMembership(storeAvailable: false, isPremium: true);
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
          premiumMembershipProvider.overrideWith(
            _ActivePremiumMembershipNotifier.new,
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

    await tester.tap(find.text('Bu gruba görev ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Sırada ne var?'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-quick-submit')), findsOneWidget);
    expect(find.text('Vazgeç'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('daily-period-chip')));
    await tester.pumpAndSettle();
    expect(find.text('Günün saati'), findsOneWidget);
    expect(find.text('Her zaman'), findsOneWidget);
    expect(find.text('Sabah'), findsOneWidget);
    expect(find.text('Gündüz'), findsOneWidget);
    expect(find.text('Akşam'), findsOneWidget);
    expect(find.text('Etkinlik'), findsOneWidget);
    expect(find.text('Zamanında'), findsOneWidget);
    expect(find.text('Tüm gün'), findsNothing);
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
    expect(find.text('Planlama'), findsNothing);
    expect(find.text('Günün saati'), findsOneWidget);
    expect(find.text('Tarih'), findsOneWidget);
    expect(find.text('Süre'), findsOneWidget);
    expect(find.text('Yinelemek'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-alarm-toggle')), findsNothing);
    expect(
      find.byKey(const ValueKey('daily-detail-subtask-input')),
      findsNothing,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('daily-subtasks-section-toggle')),
    );
    await tester.tap(
      find.byKey(const ValueKey('daily-subtasks-section-toggle')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('daily-detail-subtask-input')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('daily-notes-section-toggle')),
    );
    await tester.tap(find.byKey(const ValueKey('daily-notes-section-toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey('daily-detail-notes')), findsOneWidget);

    await tester.tap(find.text('Günün saati'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('daily-timed-choice')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('daily-alarm-toggle')), findsOneWidget);
    expect(find.text('Görev başladığında çalar'), findsOneWidget);
  });

  test('daily alarm defaults to the next half or full hour', () {
    expect(
      nextDailyAlarmSlot(DateTime(2026, 8, 14, 1, 12)),
      DateTime(2026, 8, 14, 1, 30),
    );
    expect(
      nextDailyAlarmSlot(DateTime(2026, 8, 14, 1, 51)),
      DateTime(2026, 8, 14, 2),
    );
    expect(
      nextDailyAlarmSlot(DateTime(2026, 8, 14, 1, 30)),
      DateTime(2026, 8, 14, 2),
    );
    expect(
      nextDailyAlarmSlot(DateTime(2026, 8, 14, 23, 45)),
      DateTime(2026, 8, 15),
    );
  });

  test(
    'scheduled progress selects the earliest overlapping task for today',
    () {
      final now = DateTime(2026, 8, 14, 10, 30);
      final ended = TaskModel(
        id: 'ended',
        title: 'Biten',
        color: '#6C5CE7',
        icon: 'task',
        durationMinutes: 20,
        scheduledAt: DateTime(2026, 8, 14, 9),
        status: TaskStatus.pending,
        sortOrder: 0,
        isInbox: false,
        isTimed: true,
      );
      final first = TaskModel(
        id: 'first',
        title: 'Önce başlayan',
        color: '#6C5CE7',
        icon: 'task',
        durationMinutes: 60,
        scheduledAt: DateTime(2026, 8, 14, 10),
        status: TaskStatus.pending,
        sortOrder: 1,
        isInbox: false,
        isTimed: true,
      );
      final second = TaskModel(
        id: 'second',
        title: 'Sonra başlayan',
        color: '#6C5CE7',
        icon: 'task',
        durationMinutes: 60,
        scheduledAt: DateTime(2026, 8, 14, 10, 15),
        status: TaskStatus.pending,
        sortOrder: 2,
        isInbox: false,
        isTimed: true,
      );

      expect(
        activeScheduledTaskAt(
          tasks: [second, ended, first],
          selectedDate: now,
          now: now,
        )?.id,
        first.id,
      );
      expect(scheduledTaskProgressAt(first, now), closeTo(.5, .001));
      expect(
        activeScheduledTaskAt(
          tasks: [second, first],
          selectedDate: now,
          now: DateTime(2026, 8, 14, 11, 5),
        )?.id,
        second.id,
      );
      expect(
        activeScheduledTaskAt(
          tasks: [first],
          selectedDate: DateTime(2026, 8, 13),
          now: now,
        ),
        isNull,
      );
    },
  );

  testWidgets('Yapılacaklar choice switches to the shared todo quick add', (
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
          premiumMembershipProvider.overrideWith(
            _ActivePremiumMembershipNotifier.new,
          ),
          todoListsProvider.overrideWith(_AvailableListsNotifier.new),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: DailyPlannerTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bu gruba görev ekle'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('daily-quick-voice')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('daily-quick-title')),
      'Raporu hazırla',
    );
    await tester.tap(find.byKey(const ValueKey('daily-period-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('daily-todo-choice')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('todo-quick-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('todo-quick-voice')), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-quick-voice')), findsNothing);
    expect(find.text('Ne yapman gerekiyor?'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('todo-quick-title')))
          .controller!
          .text,
      'Raporu hazırla',
    );
    expect(find.byKey(const ValueKey('todo-quick-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('todo-quick-duration')), findsOneWidget);
    expect(find.byKey(const ValueKey('todo-quick-details')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('todo-quick-list')));
    await tester.pumpAndSettle();
    expect(find.text('Liste seç'), findsOneWidget);
    expect(find.text('To-do'), findsWidgets);
    expect(find.text('İşlerim'), findsOneWidget);
    await tester.tap(find.text('İşlerim'));
    await tester.pumpAndSettle();
    expect(find.text('İşlerim'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('todo-quick-duration')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 dk'));
    await tester.pumpAndSettle();
    expect(find.text('30 DK'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('todo-quick-details')));
    await tester.pumpAndSettle();
    expect(find.text('Görev ekle'), findsOneWidget);
    expect(find.text('Liste'), findsOneWidget);
    expect(find.text('Süre'), findsOneWidget);
  });

  testWidgets('timed daily task exposes a five minute start and end range', (
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
          premiumMembershipProvider.overrideWith(
            _ActivePremiumMembershipNotifier.new,
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: DailyPlannerTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bu gruba görev ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('daily-period-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('daily-timed-choice')));
    await tester.pumpAndSettle();

    expect(find.text('Görev ekle'), findsOneWidget);
    expect(find.text('Zamanında'), findsOneWidget);
    expect(find.text('Başlar'), findsOneWidget);
    expect(find.text('Biter'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-start-date')), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-end-date')), findsOneWidget);

    final startTimeText = tester.widgetList<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('daily-start-time')),
        matching: find.byType(Text),
      ),
    );
    final startTime = startTimeText.single.data!;
    expect(int.parse(startTime.split(':').last) % 5, 0);

    await tester.tap(find.byKey(const ValueKey('daily-start-time')));
    await tester.pumpAndSettle();
    final picker = tester.widget<CupertinoDatePicker>(
      find.byKey(const ValueKey('daily-five-minute-picker')),
    );
    expect(picker.minuteInterval, 5);
  });

  testWidgets('free account opens Premium for an exact task time', (
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
          premiumMembershipProvider.overrideWith(
            _NonPremiumMembershipNotifier.new,
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: DailyPlannerTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bu gruba görev ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('daily-period-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('daily-timed-choice')));
    await tester.pumpAndSettle();

    expect(find.text('Florien özellikleri'), findsOneWidget);
    expect(find.text('Görev için özel saat'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-start-time')), findsNothing);
  });

  testWidgets('free account opens Premium before enabling a task alarm', (
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
          premiumMembershipProvider.overrideWith(
            _NonPremiumMembershipNotifier.new,
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: DailyPlannerTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bu gruba görev ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('daily-quick-title')),
      'Doktor randevusu',
    );
    await tester.tap(find.byKey(const ValueKey('daily-details-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Günün saati'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('daily-timed-choice')));
    await tester.pumpAndSettle();

    expect(find.text('Florien özellikleri'), findsOneWidget);
    expect(find.text('Görev için özel saat'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-alarm-toggle')), findsNothing);
  });

  testWidgets('daily grouping switches between list and timeline views', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateTime.now();
    final timedStart = DateTime(
      today.year,
      today.month,
      today.day,
      today.hour <= 21 ? today.hour + 2 : today.hour - 2,
    );
    final timedEnd = timedStart.add(const Duration(minutes: 30));
    String clockLabel(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    final tasks = [
      TaskModel(
        id: 'timed-task',
        title: 'Saatli görüşme',
        color: '#6C5CE7',
        icon: 'task',
        durationMinutes: 30,
        scheduledAt: timedStart,
        status: TaskStatus.pending,
        sortOrder: 0,
        isInbox: false,
        isTimed: true,
        dayPeriod: DayPeriod.morning,
      ),
      TaskModel(
        id: 'anytime-task',
        title: 'Saati olmayan görev',
        color: '#6C5CE7',
        icon: 'task',
        durationMinutes: 15,
        scheduledAt: DateTime(today.year, today.month, today.day, 8),
        status: TaskStatus.pending,
        sortOrder: 1,
        isInbox: false,
        dayPeriod: DayPeriod.morning,
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyTimelineProvider.overrideWith(
            (ref, date) async => TimelineModel(date: date, tasks: tasks),
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: DailyPlannerTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('daily-list-view')), findsOneWidget);
    expect(
      find.text('${clockLabel(timedStart)} → ${clockLabel(timedEnd)}'),
      findsOneWidget,
    );

    expect(find.byKey(const ValueKey('daily-menu-reschedule')), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-menu-routines')), findsOneWidget);
    expect(find.text('Yeniden zamanla'), findsOneWidget);
    expect(find.text('Rutinler'), findsOneWidget);
    expect(find.text('Günlük modu'), findsNothing);

    await tester.tap(find.byTooltip('Görünüm seçenekleri'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('daily-grouping-submenu')),
      findsOneWidget,
    );
    expect(find.text('Liste'), findsOneWidget);
    expect(find.text('Zaman çizelgesi'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('daily-grouping-timeline')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('daily-timeline-view')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('daily-timeline-anytime')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('daily-timeline-anytime')),
        matching: find.text('Saati olmayan görev'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('timeline-task-timed-task')),
      findsOneWidget,
    );
    expect(find.text(clockLabel(timedStart)), findsOneWidget);
    expect(find.text(clockLabel(timedEnd)), findsOneWidget);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('daily-timeline-sun-marker')))
          .dx,
      moreOrLessEquals(
        tester.getTopLeft(find.text(clockLabel(timedStart))).dx,
        epsilon: .1,
      ),
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('daily-timeline-moon-marker')))
          .dx,
      moreOrLessEquals(
        tester
            .getTopLeft(find.byKey(const ValueKey('daily-timeline-day-end')))
            .dx,
        epsilon: .1,
      ),
    );

    await tester.tap(find.byTooltip('Görünüm seçenekleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('daily-grouping-list')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('daily-list-view')), findsOneWidget);
  });

  testWidgets(
    'overlapping scheduled cards stay ordered with one progress ring',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.now();
      final first = TaskModel(
        id: 'overlap-first',
        title: 'İlk başlayan',
        color: '#EAA4C4',
        icon: 'task',
        durationMinutes: 120,
        scheduledAt: now.subtract(const Duration(minutes: 30)),
        status: TaskStatus.pending,
        sortOrder: 1,
        isInbox: false,
        isTimed: true,
      );
      final second = TaskModel(
        id: 'overlap-second',
        title: 'İkinci başlayan',
        color: '#6C5CE7',
        icon: 'task',
        durationMinutes: 120,
        scheduledAt: now.subtract(const Duration(minutes: 10)),
        status: TaskStatus.pending,
        sortOrder: 0,
        isInbox: false,
        isTimed: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyTimelineProvider.overrideWith(
              (ref, date) async =>
                  TimelineModel(date: date, tasks: [second, first]),
            ),
          ],
          child: MaterialApp(
            theme: FlorienTheme.light,
            home: const Scaffold(body: DailyPlannerTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('daily-task-progress-overlap-first')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('daily-task-progress-overlap-second')),
        findsNothing,
      );
      final listStatus = tester.widget<Text>(
        find.byKey(const ValueKey('daily-task-status-overlap-first')),
      );
      expect(listStatus.data, matches(RegExp(r'^\d+:\d{2}:\d{2}$')));

      await tester.tap(find.byTooltip('Görünüm seçenekleri'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('daily-grouping-timeline')));
      await tester.pumpAndSettle();

      expect(find.text('PLANLANDI (2)'), findsOneWidget);
      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('timeline-task-overlap-first')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('timeline-task-overlap-second')),
              )
              .dy,
        ),
      );
      expect(
        find.byKey(const ValueKey('daily-task-progress-overlap-first')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('daily-task-progress-overlap-second')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('timeline-task-status-overlap-first')),
        findsOneWidget,
      );
    },
  );

  testWidgets('daily destination is between todo and stats', (tester) async {
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
    expect(find.text('İstatistik'), findsOneWidget);
    expect(find.text('Odaklan'), findsNothing);

    await tester.tap(find.text('Günlük'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('daily-planner-page')), findsOneWidget);
  });

  testWidgets('premium upsell is available in todo and daily lists', (
    tester,
  ) async {
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
          premiumMembershipProvider.overrideWith(
            _NonPremiumMembershipNotifier.new,
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const TodoHomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('premium-upsell-button')), findsOneWidget);

    await tester.tap(find.text('Günlük'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('premium-upsell-button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('premium-upsell-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PremiumMembershipScreen), findsOneWidget);
  });

  testWidgets('premium upsell stays hidden for premium users', (tester) async {
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
          premiumMembershipProvider.overrideWith(
            _ActivePremiumMembershipNotifier.new,
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const TodoHomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('premium-upsell-button')), findsNothing);

    await tester.tap(find.text('Günlük'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('premium-upsell-button')), findsNothing);
  });

  testWidgets('daily header stays fixed above the scrolling task list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final tasks = List.generate(
      12,
      (index) => TaskModel(
        id: 'scroll-task-$index',
        title: 'Odak görevi $index',
        color: '#6C5CE7',
        icon: 'task',
        durationMinutes: 15,
        scheduledAt: DateTime.now(),
        status: TaskStatus.pending,
        sortOrder: index,
        isInbox: false,
        dayPeriod: DayPeriod.daytime,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyTimelineProvider.overrideWith(
            (ref, date) async => TimelineModel(date: date, tasks: tasks),
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: DailyPlannerTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('daily-date-header'));
    expect(header, findsOneWidget);
    final headerBottom = tester.getBottomLeft(header).dy;

    await tester.drag(
      find.byKey(const ValueKey('daily-planner-list')),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();

    expect(header, findsOneWidget);
    expect(find.byKey(const ValueKey('daily-focused-header')), findsNothing);
    expect(find.byTooltip('Görünüm seçenekleri'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-top-add')), findsNothing);
    expect(tester.getBottomLeft(header).dy, headerBottom);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('daily-planner-list'))).dy,
      greaterThanOrEqualTo(headerBottom - 0.5),
    );
  });

  testWidgets('daily planner can pick any date and quickly return to today', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
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

    expect(
      find.byKey(const ValueKey('daily-open-date-picker')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('daily-date-picker-trigger')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('daily-date-picker-sheet')),
      findsOneWidget,
    );

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(tomorrow);
    await tester.pump();
    await tester.tap(find.byTooltip('Seçilen tarihe git'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('daily-return-today')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('daily-return-today')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('daily-open-date-picker')),
      findsOneWidget,
    );
  });

  testWidgets('daily task copy opens a prefilled detailed creation page', (
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
    await tester.pumpAndSettle();
    expect(deleted, isFalse);
    expect(find.text('Görev ekle'), findsOneWidget);
    expect(find.text('Günün saati'), findsOneWidget);
    expect(find.text('Tarih'), findsOneWidget);
    expect(find.text('Süre'), findsOneWidget);
    expect(find.text('Sırada ne var?'), findsNothing);
    final copyTitle = tester.widget<TextField>(
      find.byKey(const ValueKey('daily-detail-title')),
    );
    expect(copyTitle.controller?.text, '${task.title} (Kopya)');

    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(task.title));
    await tester.pumpAndSettle();

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

  testWidgets('daily task edit opens prefilled and updates the same task', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    DailyTaskEditInput? savedInput;
    final task = TaskModel(
      id: 'editable-daily-task',
      title: 'Eski günlük görev',
      description: 'Eski not',
      color: '#6C5CE7',
      icon: 'task',
      durationMinutes: 30,
      scheduledAt: DateTime(2026, 8, 14, 13),
      alarmAt: DateTime(2026, 8, 14, 12, 30),
      status: TaskStatus.pending,
      sortOrder: 0,
      isInbox: false,
      isTimed: true,
      dayPeriod: DayPeriod.daytime,
      subtasks: const [
        TaskModel(
          id: 'editable-subtask',
          title: 'İlk adım',
          color: '#6C5CE7',
          icon: 'task',
          durationMinutes: 5,
          status: TaskStatus.pending,
          sortOrder: 0,
          isInbox: false,
          parentTaskId: 'editable-daily-task',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyTimelineProvider.overrideWith(
            (ref, date) async => TimelineModel(date: date, tasks: [task]),
          ),
          dailyTaskUpdaterProvider.overrideWithValue((
            updatedTask,
            input,
          ) async {
            expect(updatedTask.id, task.id);
            savedInput = input;
          }),
          taskAlarmServiceProvider.overrideWithValue(_ReadyTaskAlarmService()),
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
    await tester.tap(find.text('Görevi düzenle'));
    await tester.pumpAndSettle();

    final title = tester.widget<TextField>(
      find.byKey(const ValueKey('daily-detail-title')),
    );
    expect(title.controller?.text, task.title);
    expect(find.text(task.description!), findsOneWidget);
    expect(find.text('İlk adım'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-alarm-toggle')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('daily-detail-title')),
      'Güncellenen günlük görev',
    );
    await tester.tap(find.text('Görevi kaydet'));
    await tester.pumpAndSettle();

    expect(savedInput?.title, 'Güncellenen günlük görev');
    expect(savedInput?.description, 'Eski not');
    expect(savedInput?.durationMinutes, 30);
    expect(savedInput?.period, DayPeriod.daytime);
    expect(savedInput?.alarmEnabled, isTrue);
    expect(savedInput?.subtasks, ['İlk adım']);
  });

  testWidgets('manually completing a daily task celebrates in place', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? completedTaskId;
    final task = TaskModel(
      id: 'manual-daily-completion',
      title: 'Elle tamamlanacak görev',
      color: '#6C5CE7',
      icon: 'task',
      durationMinutes: 15,
      scheduledAt: DateTime.now(),
      status: TaskStatus.pending,
      sortOrder: 0,
      isInbox: false,
      dayPeriod: DayPeriod.morning,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyTimelineProvider.overrideWith(
            (ref, date) async => TimelineModel(date: date, tasks: [task]),
          ),
          dailyTaskCompleterProvider.overrideWithValue((taskId) async {
            completedTaskId = taskId;
            return const CompletionCounts(today: 2, thisWeek: 5);
          }),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: DailyPlannerTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final taskTile = find.ancestor(
      of: find.text(task.title),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: taskTile,
        matching: find.byIcon(Icons.circle_outlined),
      ),
    );
    await tester.pump();

    expect(completedTaskId, task.id);
    expect(
      find.byKey(const ValueKey('task-completion-bubbles')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('completion-celebration-page')),
      findsNothing,
    );
    expect(find.text(task.title), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();
  });

  testWidgets('daily task asks for a todo list before moving', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? movedTaskId;
    String? movedListId;
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
          todoListsProvider.overrideWith(_AvailableListsNotifier.new),
          dailyMoveToTodoProvider.overrideWithValue((id, listId) async {
            movedTaskId = id;
            movedListId = listId;
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

    expect(movedTaskId, isNull);
    expect(
      find.byKey(const ValueKey('daily-move-to-todo-sheet')),
      findsOneWidget,
    );
    expect(find.text('To-do'), findsOneWidget);
    expect(find.text('İşlerim'), findsOneWidget);

    await tester.tap(find.text('İşlerim'));
    await tester.pumpAndSettle();
    expect(movedTaskId, task.id);
    expect(movedListId, 'work-list');
    expect(find.text('Yapılacaklara taşı'), findsNothing);

    movedTaskId = null;
    movedListId = 'not-null';
    await tester.tap(find.text(task.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yapılacaklara taşı'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('To-do'));
    await tester.pumpAndSettle();
    expect(movedTaskId, task.id);
    expect(movedListId, isNull);
  });

  testWidgets('daily task can be rescheduled while keeping its group', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    TaskModel? rescheduledTask;
    DateTime? rescheduledDate;
    final taskDate = DateTime(2026, 8, 14);
    final task = TaskModel(
      id: 'reschedule-task',
      title: 'Yeniden planlanacak',
      color: '#6C5CE7',
      icon: 'task',
      durationMinutes: 20,
      scheduledAt: taskDate,
      status: TaskStatus.pending,
      sortOrder: 0,
      isInbox: false,
      dayPeriod: DayPeriod.morning,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyTimelineProvider.overrideWith(
            (ref, date) async => TimelineModel(date: date, tasks: [task]),
          ),
          dailyTaskReschedulerProvider.overrideWithValue((task, date) async {
            rescheduledTask = task;
            rescheduledDate = date;
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
    await tester.tap(find.text('Yeniden planla'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('daily-reschedule-sheet')),
      findsOneWidget,
    );
    final customDate = DateTime(2026, 9, 3);
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(customDate);
    await tester.pump();
    await tester.tap(find.byTooltip('Tarihi onayla'));
    await tester.pumpAndSettle();

    expect(rescheduledTask?.id, task.id);
    expect(rescheduledTask?.dayPeriod, DayPeriod.morning);
    expect(rescheduledDate, customDate);

    rescheduledDate = null;
    await tester.tap(find.text(task.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeniden planla'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Bugün ('));
    await tester.pumpAndSettle();
    final today = DateTime.now();
    expect(rescheduledDate?.year, today.year);
    expect(rescheduledDate?.month, today.month);
    expect(rescheduledDate?.day, today.day);

    rescheduledDate = null;
    await tester.tap(find.text(task.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeniden planla'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Gelecek hafta'));
    await tester.pumpAndSettle();

    expect(rescheduledDate, taskDate.add(const Duration(days: 7)));
  });

  testWidgets('tomorrow action reschedules into the same group', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    DateTime? rescheduledDate;
    DayPeriod? rescheduledPeriod;
    final today = DateTime.now();
    final task = TaskModel(
      id: 'tomorrow-task',
      title: 'Yarına taşınacak',
      color: '#6C5CE7',
      icon: 'task',
      durationMinutes: 15,
      scheduledAt: today,
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
          dailyTaskReschedulerProvider.overrideWithValue((task, date) async {
            rescheduledDate = date;
            rescheduledPeriod = task.dayPeriod;
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
    await tester.tap(find.text('Yarın için yeniden planla'));
    await tester.pumpAndSettle();

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect(rescheduledDate?.year, tomorrow.year);
    expect(rescheduledDate?.month, tomorrow.month);
    expect(rescheduledDate?.day, tomorrow.day);
    expect(rescheduledPeriod, DayPeriod.evening);
  });

  testWidgets(
    'daily review shows completed tasks then repeatedly moves selected tasks',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final today = DateTime.now();
      final completed = TaskModel(
        id: 'review-completed',
        title: 'Biten görev',
        color: '#6C5CE7',
        icon: 'task',
        durationMinutes: 15,
        scheduledAt: today,
        completedAt: today,
        status: TaskStatus.completed,
        sortOrder: 0,
        isInbox: false,
      );
      final first = TaskModel(
        id: 'review-first',
        title: 'İlk kalan',
        color: '#6C5CE7',
        icon: 'task',
        durationMinutes: 20,
        scheduledAt: today,
        status: TaskStatus.pending,
        sortOrder: 1,
        isInbox: false,
      );
      final second = TaskModel(
        id: 'review-second',
        title: 'İkinci kalan',
        color: '#6C5CE7',
        icon: 'task',
        durationMinutes: 25,
        scheduledAt: today,
        status: TaskStatus.pending,
        sortOrder: 2,
        isInbox: false,
      );
      final movedDates = <String, DateTime>{};
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyTimelineProvider.overrideWith(
              (ref, date) async =>
                  TimelineModel(date: date, tasks: [completed, first, second]),
            ),
            dailyTaskReschedulerProvider.overrideWithValue((task, date) async {
              movedDates[task.id] = date;
            }),
          ],
          child: MaterialApp(
            theme: FlorienTheme.light,
            home: const Scaffold(body: DailyPlannerTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('daily-menu-reschedule')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('daily-review-completed')),
        findsOneWidget,
      );
      expect(find.text('1 görev tamamladın'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('daily-review-completed')),
          matching: find.text(completed.title),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('daily-review-close')), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('daily-review-remaining')),
        findsOneWidget,
      );
      expect(find.text('2 yarın taşınsın mı?'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('daily-review-task-review-second')),
      );
      await tester.pump();
      expect(find.text('1 yarın taşınsın mı?'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('daily-review-move-tomorrow')),
      );
      await tester.pumpAndSettle();
      expect(movedDates.keys, contains(first.id));
      expect(movedDates.keys, isNot(contains(second.id)));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('daily-review-remaining')),
          matching: find.text(first.title),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('daily-review-remaining')),
          matching: find.text(second.title),
        ),
        findsOneWidget,
      );
      expect(find.text('1 yarın taşınsın mı?'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('daily-review-more-dates')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('daily-review-date-picker')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('daily-review-date-close')),
        findsOneWidget,
      );
      final customDate = DateTime(today.year, today.month, today.day + 4);
      tester
          .widget<CalendarDatePicker>(
            find.byKey(const ValueKey('daily-review-date-picker')),
          )
          .onDateChanged(customDate);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('daily-review-date-apply')));
      await tester.pumpAndSettle();

      expect(movedDates[second.id], customDate);
      expect(
        find.byKey(const ValueKey('daily-review-finished')),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('daily-planner-page')), findsOneWidget);
      expect(find.byKey(const ValueKey('daily-review-finished')), findsNothing);
    },
  );

  testWidgets('daily review can finish manually when no task is completed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final task = TaskModel(
      id: 'review-pending-only',
      title: 'Kalan görev',
      color: '#6C5CE7',
      icon: 'task',
      durationMinutes: 15,
      scheduledAt: DateTime.now(),
      status: TaskStatus.pending,
      sortOrder: 0,
      isInbox: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyTimelineProvider.overrideWith(
            (ref, date) async => TimelineModel(date: date, tasks: [task]),
          ),
          dailyTaskReschedulerProvider.overrideWithValue((_, _) async {}),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: DailyPlannerTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('daily-menu-reschedule')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('daily-review-completed')), findsNothing);
    expect(
      find.byKey(const ValueKey('daily-review-remaining')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('daily-review-finish')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('daily-review-finished')), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-review-close')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('daily-review-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('daily-planner-page')), findsOneWidget);
  });
}
