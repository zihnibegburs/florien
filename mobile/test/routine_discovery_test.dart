import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/data/routine_catalog.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/models/task_usage_summary.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/presentation/task_icon_badge.dart';
import 'package:florien/features/todo/routine_discovery_screen.dart';

TaskModel _task(String id, String title) => TaskModel(
  id: id,
  title: title,
  color: '#FFF76A',
  icon: 'other',
  durationMinutes: 15,
  status: TaskStatus.pending,
  sortOrder: 0,
  isInbox: false,
);

void main() {
  test('routine catalog exposes 12 accordion groups and 120 local presets', () {
    expect(FlorienColors.fromHex(readyRoutineTaskColor), FlorienColors.accent);
    expect(routineThemes, hasLength(12));
    expect(
      routineThemes.fold<int>(0, (total, theme) => total + theme.tasks.length),
      120,
    );
    for (final theme in routineThemes) {
      expect(theme.tasks, hasLength(10));
      expect(theme.icon, isNot('other'));
      expect(taskCategoryByStorageName.containsKey(theme.icon), isTrue);
      final taskIcons = theme.tasks.map((task) => task.icon).toSet();
      expect(taskIcons, isNot(equals({theme.icon})), reason: theme.name);
      for (final task in theme.tasks) {
        expect(task.durationMinutes, greaterThan(0));
        expect(task.subtasks, isNotEmpty);
        expect(task.icon, isNotEmpty);
        expect(task.icon, isNot('other'));
        expect(taskCategoryByStorageName.containsKey(task.icon), isTrue);
      }
    }
  });

  test('ready routine copy has English translations', () {
    final keys = <String>{};
    for (final theme in routineThemes) {
      keys.add(theme.name);
      keys.add(theme.description);
      for (final task in theme.tasks) {
        keys.add(task.title);
        keys.addAll(task.subtasks);
      }
    }
    for (final key in keys) {
      expect(const S('en')(key), isNot(key), reason: key);
    }
  });

  test('frequent tasks rank by count, then latest creation time', () {
    final ranked = rankFrequentlyUsedTasks([
      TaskUsageCandidate(
        task: _task('focus-old', 'Odaklan'),
        createdAt: DateTime(2026, 8, 10),
      ),
      TaskUsageCandidate(
        task: _task('walk', 'Yürü'),
        createdAt: DateTime(2026, 8, 19),
      ),
      TaskUsageCandidate(
        task: _task('focus-new', '  ODAKLAN '),
        createdAt: DateTime(2026, 8, 18),
      ),
      TaskUsageCandidate(
        task: _task('plan', 'Plan yap'),
        createdAt: DateTime(2026, 8, 17),
      ),
    ]);

    expect(ranked.map((summary) => summary.task.id), [
      'focus-new',
      'walk',
      'plan',
    ]);
    expect(ranked.first.usageCount, 2);
  });

  testWidgets('ready routines open as calm rows with visible durations', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: RoutineDiscoveryScreen(onTaskSelected: (_, _) async {}),
      ),
    );

    expect(
      find.byKey(const ValueKey('routine-task-10 Dakikada Ayağa Kalk')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('routine-task-15 Dakikada Evden Çık')),
      findsNothing,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('routine-task-Sakin Sabah Başlangıcı')),
          )
          .dy,
      greaterThan(
        tester
            .getBottomLeft(
              find.byKey(const ValueKey('routine-task-10 Dakikada Ayağa Kalk')),
            )
            .dy,
      ),
    );
    expect(
      find.byKey(
        const ValueKey('routine-task-duration-10 Dakikada Ayağa Kalk'),
      ),
      findsOneWidget,
    );
    expect(find.text('10 dk'), findsOneWidget);

    await tester.ensureVisible(find.text('Evden Hazır Çık'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evden Hazır Çık'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('routine-task-10 Dakikada Ayağa Kalk')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('routine-task-15 Dakikada Evden Çık')),
      findsOneWidget,
    );
    expect(find.textContaining('Hazır şablon'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready routines can use a task-specific icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: RoutineDiscoveryScreen(onTaskSelected: (_, _) async {}),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('routine-search-field')),
      'Spor Çantanı Topla',
    );
    await tester.pumpAndSettle();

    final themeIcon = tester.widget<TaskIconBadge>(
      find.byKey(const ValueKey('routine-theme-icon-Evden Hazır Çık')),
    );
    final taskIcon = tester.widget<TaskIconBadge>(
      find.byKey(const ValueKey('routine-task-icon-Spor Çantanı Topla')),
    );
    expect(themeIcon.category, TaskCategory.home);
    expect(taskIcon.category, TaskCategory.gym);
  });

  testWidgets('searches and selects a ready routine without an API step', (
    tester,
  ) async {
    RoutinePresetTask? selectedTask;

    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: RoutineDiscoveryScreen(
          onTaskSelected: (task, _) async => selectedTask = task,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('routine-search-field')),
      'Kahvaltıyla',
    );
    await tester.pumpAndSettle();
    expect(find.text('Kahvaltıyla Güç Topla'), findsOneWidget);
    expect(find.text('Mutfağı Temiz Bırak'), findsNothing);
    expect(find.text('25 dk'), findsOneWidget);

    await tester.tap(find.text('Kahvaltıyla Güç Topla'));
    await tester.pumpAndSettle();
    expect(selectedTask?.title, 'Kahvaltıyla Güç Topla');
    expect(selectedTask?.subtasks, isNotEmpty);
  });

  testWidgets('passes the localized title into the add form', (tester) async {
    ActiveLanguage.code = 'en';
    addTearDown(() => ActiveLanguage.code = 'tr');
    RoutinePresetTask? selectedTask;

    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: RoutineDiscoveryScreen(
          onTaskSelected: (task, _) async => selectedTask = task,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('routine-task-10 Dakikada Ayağa Kalk')),
    );
    await tester.pumpAndSettle();

    expect(selectedTask?.title, 'Get up in 10 minutes');
    expect(selectedTask?.description, isEmpty);
    expect(selectedTask?.subtasks.first, 'Drink water and wake your body');
  });

  testWidgets('shows frequently used tasks in a horizontal slider', (
    tester,
  ) async {
    TaskUsageSummary? selected;
    final summary = TaskUsageSummary(
      task: _task('frequent-focus', 'Odaklan'),
      usageCount: 4,
      lastCreatedAt: DateTime(2026, 8, 19),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: RoutineDiscoveryScreen(
          frequentlyUsedTasks: [summary],
          onFrequentlyUsedTaskSelected: (value) async => selected = value,
          onTaskSelected: (_, _) async {},
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('routine-frequently-used-slider')),
      findsOneWidget,
    );
    expect(find.text('4 kullanım'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('frequently-used-task-frequent-focus')),
    );
    await tester.pumpAndSettle();
    expect(selected?.task.id, 'frequent-focus');
  });

  testWidgets(
    'frequently used cards use theme surface instead of solid yellow',
    (tester) async {
      final summary = TaskUsageSummary(
        task: _task('frequent-focus', 'Odaklan'),
        usageCount: 4,
        lastCreatedAt: DateTime(2026, 8, 19),
      );

      for (final theme in [FlorienTheme.light, FlorienTheme.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: RoutineDiscoveryScreen(
              frequentlyUsedTasks: [summary],
              onTaskSelected: (_, _) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final card = tester.widget<Ink>(
          find.descendant(
            of: find.byKey(
              const ValueKey('frequently-used-task-frequent-focus'),
            ),
            matching: find.byType(Ink),
          ),
        );
        final decoration = card.decoration! as BoxDecoration;
        final palette = theme.extension<FlorienPalette>()!;
        expect(decoration.color, palette.surface);
        expect(decoration.color, isNot(FlorienColors.primary));
      }
    },
  );
}
