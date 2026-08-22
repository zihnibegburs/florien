import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/todo/daily_plan_share_sheet.dart';

void main() {
  testWidgets('daily plan share exports the selected visual theme', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    MethodCall? shareCall;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      shareCall = call;
      return 'com.apple.UIKit.activity.CopyToPasteboard';
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    final task = TaskModel(
      id: 'share-task',
      title: 'Raporu tamamla',
      color: '#F2BC52',
      icon: 'task',
      durationMinutes: 30,
      scheduledAt: DateTime(2026, 8, 18, 10),
      status: TaskStatus.pending,
      sortOrder: 0,
      isInbox: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: const [FlorienPalette.light],
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDailyPlanShareSheet(
                context,
                date: DateTime(2026, 8, 18),
                tasks: [task],
              ),
              child: const Text('Paylaşımı aç'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Paylaşımı aç'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('daily-share-status-menu-share-task')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('daily-share-status-incomplete-share-task')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('daily-share-continue')));
    await tester.pumpAndSettle();
    expect(find.text('1 tamamlanamadı'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('daily-share-theme-florien')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('daily-share-theme-night')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('daily-share-theme-ocean')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('daily-share-theme-sunset')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('daily-share-theme-pop')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('daily-share-theme-night')));
    await tester.pumpAndSettle();
    final shareButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('daily-share-submit')),
    );
    await tester.runAsync(() async {
      shareButton.onPressed!.call();
      for (var attempt = 0; attempt < 20 && shareCall == null; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();

    expect(shareCall?.method, 'shareFiles');
    final arguments = shareCall?.arguments as Map<Object?, Object?>;
    expect(arguments['mimeTypes'], contains('image/png'));
    expect(arguments['originWidth'], greaterThan(0));
    expect(arguments['originHeight'], greaterThan(0));
    final paths = arguments['paths'];
    expect(paths, isA<List>());
    expect((paths as List).single, isNotEmpty);
  });
}
