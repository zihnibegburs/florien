import 'package:florien/core/widgets/delayed_scroll_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hides after a long drag and returns after release', (
    tester,
  ) async {
    var visible = true;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 300,
          child: DelayedScrollChrome(
            onVisibilityChanged: (value) => visible = value,
            child: ListView(children: const [SizedBox(height: 1200)]),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(200, 220));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 499));
    expect(visible, isTrue);

    await tester.pump(const Duration(milliseconds: 1));
    expect(visible, isFalse);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 499));
    expect(visible, isFalse);

    await tester.pump(const Duration(milliseconds: 1));
    expect(visible, isTrue);
  });

  testWidgets('does not hide after a short drag', (tester) async {
    var visible = true;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 300,
          child: DelayedScrollChrome(
            onVisibilityChanged: (value) => visible = value,
            child: ListView(children: const [SizedBox(height: 1200)]),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(200, 220));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 600));

    expect(visible, isTrue);
  });

  testWidgets('does not hide when content cannot scroll', (tester) async {
    var visible = true;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 300,
          child: DelayedScrollChrome(
            onVisibilityChanged: (value) => visible = value,
            child: ListView(children: const [SizedBox(height: 80)]),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(200, 220));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();

    expect(visible, isTrue);
  });
}
