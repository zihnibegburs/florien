import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/data/routine_catalog.dart';
import 'package:florien/features/todo/routine_discovery_screen.dart';

void main() {
  test('routine catalog tasks have durations and predefined subtasks', () {
    expect(routineThemes, isNotEmpty);
    for (final theme in routineThemes) {
      expect(theme.tasks, isNotEmpty);
      for (final task in theme.tasks) {
        expect(task.durationMinutes, greaterThan(0));
        expect(task.subtasks, isNotEmpty);
      }
    }
  });

  testWidgets('searches and selects a ready task', (tester) async {
    RoutinePresetTask? selectedTask;

    await tester.pumpWidget(
      MaterialApp(
        home: RoutineDiscoveryScreen(
          onTaskSelected: (task, _) async => selectedTask = task,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('routine-search-field')),
      'Kahvaltı',
    );
    await tester.pump();
    expect(find.text('Kahvaltı yap'), findsOneWidget);
    expect(find.text('Mutfağı toparla'), findsNothing);

    await tester.tap(find.text('Kahvaltı yap'));
    await tester.pumpAndSettle();
    expect(selectedTask?.title, 'Kahvaltı yap');
  });
}
