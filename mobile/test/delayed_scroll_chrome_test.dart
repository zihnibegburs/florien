import 'package:florien/core/widgets/delayed_scroll_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hides after the focus offset and stays hidden after release', (
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
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump();
    expect(visible, isFalse);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 600));
    expect(visible, isFalse);

    final revealGesture = await tester.startGesture(const Offset(200, 120));
    await revealGesture.moveBy(const Offset(0, 30));
    await tester.pump();
    expect(visible, isTrue);
    await revealGesture.up();
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
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    await gesture.up();

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
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump();
    await gesture.up();

    expect(visible, isTrue);
  });

  testWidgets('does not immediately hide again after revealing far down', (
    tester,
  ) async {
    var visible = true;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 300,
          child: DelayedScrollChrome(
            onVisibilityChanged: (value) => visible = value,
            child: ListView(children: const [SizedBox(height: 1600)]),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pump();
    expect(visible, isFalse);

    final revealGesture = await tester.startGesture(const Offset(200, 120));
    await revealGesture.moveBy(const Offset(0, 32));
    await tester.pump();
    expect(visible, isTrue);
    await revealGesture.up();

    final shortUpwardGesture = await tester.startGesture(
      const Offset(200, 220),
    );
    await shortUpwardGesture.moveBy(const Offset(0, -12));
    await tester.pump();
    expect(visible, isTrue);
    await shortUpwardGesture.up();
  });
}
