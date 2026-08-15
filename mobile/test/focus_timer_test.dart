import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/focus_timer_tab.dart';

void main() {
  testWidgets('task timer reports completion when its duration ends', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? completedTaskId;
    ActiveFocusTask? progress;
    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: Scaffold(
          body: FocusTimerTab(
            launchRequest: const FocusTaskLaunch(
              taskId: 'finishing-task',
              title: 'Bitecek görev',
              durationMinutes: 1,
              icon: 'task',
              color: '#6C5CE7',
            ),
            onTaskProgressChanged: (value) => progress = value,
            onTaskCompleted: (taskId) async => completedTaskId = taskId,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(progress?.taskId, 'finishing-task');

    await tester.pump(const Duration(seconds: 60));
    await tester.pump();

    expect(completedTaskId, 'finishing-task');
    expect(progress, isNull);
  });

  testWidgets('reset signal stops an active task timer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ActiveFocusTask? progress;
    const launch = FocusTaskLaunch(
      taskId: 'moved-task',
      title: 'Taşınan görev',
      durationMinutes: 15,
      icon: 'task',
      color: '#6C5CE7',
    );

    Widget buildTimer(int resetSignal) => MaterialApp(
      theme: FlorienTheme.light,
      home: Scaffold(
        body: FocusTimerTab(
          launchRequest: launch,
          resetSignal: resetSignal,
          onTaskProgressChanged: (value) => progress = value,
        ),
      ),
    );

    await tester.pumpWidget(buildTimer(0));
    await tester.pump();
    expect(progress?.taskId, launch.taskId);
    expect(find.byKey(const ValueKey('active-timer')), findsOneWidget);

    await tester.pumpWidget(buildTimer(1));
    await tester.pump();
    await tester.pump();

    expect(progress, isNull);
    expect(find.byKey(const ValueKey('timer-setup')), findsOneWidget);
  });

  testWidgets('automatic scheduled focus uses its remaining range', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    String? completedTaskId;
    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: Scaffold(
          body: FocusTimerTab(
            launchRequest: FocusTaskLaunch(
              taskId: 'automatic-task',
              title: 'Planlı odak',
              durationMinutes: 30,
              icon: 'task',
              color: '#6C5CE7',
              startedAt: now.subtract(const Duration(minutes: 10)),
              endsAt: now.add(const Duration(minutes: 20)),
              automatic: true,
            ),
            onTaskCompleted: (taskId) async => completedTaskId = taskId,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('active-timer')), findsOneWidget);
    expect(find.text('Planlı odak'), findsOneWidget);
    expect(find.text('30:00'), findsNothing);
    expect(completedTaskId, isNull);
  });

  testWidgets('setup dial defaults to 5 and selects every minute', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: const Scaffold(body: FocusTimerTab()),
      ),
    );

    expect(find.text('5'), findsOneWidget);

    final dial = find.byKey(const ValueKey('setup-focus-dial'));
    final handle = find.descendant(
      of: dial,
      matching: find.byKey(const ValueKey('focus-dial-handle')),
    );
    final center = tester.getCenter(dial);
    final gesture = await tester.startGesture(tester.getCenter(handle));
    final sixMinuteAngle = -math.pi / 2 + math.pi * 2 * 6 / 60;
    await gesture.moveTo(
      center +
          Offset(
            math.cos(sixMinuteAngle) * 120,
            math.sin(sixMinuteAngle) * 120,
          ),
    );
    await tester.pump();
    expect(find.text('6'), findsOneWidget);

    await gesture.moveTo(center + const Offset(0, -120));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    await gesture.up();
  });

  testWidgets('timer switches to the active session layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: const Scaffold(body: FocusTimerTab()),
      ),
    );

    expect(find.text('Odaklanmaya başla'), findsOneWidget);
    expect(find.text('+ 1 dk'), findsNothing);

    await tester.tap(find.text('Odaklanmaya başla'));
    await tester.pumpAndSettle();
    expect(find.text('30 dk.'), findsOneWidget);
    await tester.tap(find.text('30 dk.'));
    await tester.pumpAndSettle();

    expect(find.text('Alarm açık'), findsOneWidget);
    expect(find.text('+ 1 dk'), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_bottom_rounded), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.tap(find.text('Alarm açık'));
    await tester.pumpAndSettle();
    expect(find.text('Alarm kapalı'), findsOneWidget);
    expect(find.byIcon(Icons.alarm_off_rounded), findsOneWidget);

    await tester.tap(find.text('Alarm kapalı'));
    await tester.pumpAndSettle();
    expect(find.text('Alarm açık'), findsOneWidget);
    expect(find.byIcon(Icons.alarm_on_rounded), findsOneWidget);
  });

  testWidgets('timer starts when standalone task persistence fails', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: Scaffold(
          body: FocusTimerTab(
            onStandaloneFocusStarted: (_) async =>
                throw StateError('Network unavailable'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Başla'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('active-timer')), findsOneWidget);
    expect(find.text('Odaklanma görevi oluşturulamadı.'), findsNothing);
  });

  testWidgets('custom duration supports selections up to 24 hours', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: const Scaffold(body: FocusTimerTab()),
      ),
    );

    await tester.tap(find.text('Odaklanmaya başla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Özel'));
    await tester.pumpAndSettle();

    expect(find.text('Özel süre'), findsOneWidget);
    final sliders = tester.widgetList<Slider>(find.byType(Slider));
    expect(sliders.any((slider) => slider.max == 24), isTrue);
    expect(find.text('Uygula'), findsOneWidget);

    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();
    expect(find.text('Alarm açık'), findsOneWidget);
    expect(find.text('+ 1 dk'), findsOneWidget);
  });

  testWidgets('active dial completes only after a full clockwise turn', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: const Scaffold(body: FocusTimerTab()),
      ),
    );

    await tester.tap(find.text('Odaklanmaya başla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 dk.'));
    await tester.pump(const Duration(milliseconds: 300));

    final dial = find.byKey(const ValueKey('active-focus-dial'));
    final handle = find.descendant(
      of: dial,
      matching: find.byKey(const ValueKey('focus-dial-handle')),
    );
    final center = tester.getCenter(dial);
    final initialHandleCenter = tester.getCenter(handle);

    final partialGesture = await tester.startGesture(
      center + const Offset(0, -120),
    );
    await partialGesture.moveTo(center + const Offset(120, 0));
    await partialGesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Alarm açık'), findsOneWidget);
    expect(
      (tester.getCenter(handle) - initialHandleCenter).distance,
      lessThan(3),
    );

    final fullGesture = await tester.startGesture(
      center + const Offset(0, -120),
    );
    for (var step = 1; step <= 48; step++) {
      final angle = -math.pi / 2 + math.pi * 2 * step / 48;
      await fullGesture.moveTo(
        center + Offset(math.cos(angle) * 120, math.sin(angle) * 120),
      );
      await tester.pump(const Duration(milliseconds: 4));
    }
    await fullGesture.moveTo(center + const Offset(120, 0));
    await tester.pump();
    expect(
      (tester.getCenter(handle) - (center + const Offset(0, -133))).distance,
      lessThan(3),
    );
    await fullGesture.up();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const ValueKey('focus-dial-celebration')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('focus-top-controls-hidden')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('focus-timer-controls-hidden')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byKey(const ValueKey('active-timer')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('Odaklanmaya başla'), findsOneWidget);
    expect(find.text('Alarm açık'), findsNothing);
  });

  testWidgets('setup dial stops at the top instead of wrapping', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: const Scaffold(body: FocusTimerTab()),
      ),
    );

    final dial = find.byKey(const ValueKey('setup-focus-dial'));
    final handle = find.descendant(
      of: dial,
      matching: find.byKey(const ValueKey('focus-dial-handle')),
    );
    final center = tester.getCenter(dial);
    final gesture = await tester.startGesture(tester.getCenter(handle));

    for (final position in [
      center + const Offset(0, 120),
      center + const Offset(-120, 0),
      center + const Offset(0, -120),
      center + const Offset(120, 0),
    ]) {
      await gesture.moveTo(position);
      await tester.pump();
    }

    expect(
      (tester.getCenter(handle) - (center + const Offset(0, -133))).distance,
      lessThan(3),
    );
    await gesture.up();
  });

  testWidgets('adding one minute updates the active dial position', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: const Scaffold(body: FocusTimerTab()),
      ),
    );

    await tester.tap(find.text('Odaklanmaya başla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 dk.'));
    await tester.pump(const Duration(seconds: 60));

    final dial = find.byKey(const ValueKey('active-focus-dial'));
    final handle = find.descendant(
      of: dial,
      matching: find.byKey(const ValueKey('focus-dial-handle')),
    );
    final center = tester.getCenter(dial);
    final handleBefore = tester.getCenter(handle);

    await tester.tap(find.text('+ 1 dk'));
    await tester.pump();

    final handleAfter = tester.getCenter(handle);
    expect(find.text('5:00'), findsOneWidget);
    expect((handleAfter - handleBefore).distance, greaterThan(10));

    // 1 dakika geçti, yeni toplam 6 dakika: gösterge 1/6 konumunda olmalı.
    final expectedAngle = -math.pi / 2 + math.pi * 2 / 6;
    final expectedHandle =
        center +
        Offset(math.cos(expectedAngle) * 133, math.sin(expectedAngle) * 133);
    expect((handleAfter - expectedHandle).distance, lessThan(3));
  });
}
