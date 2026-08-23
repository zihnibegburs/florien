import 'package:florien/core/widgets/florien_keyboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EditableText _editable(WidgetTester tester, Key key) {
  return tester.widget<EditableText>(
    find.descendant(of: find.byKey(key), matching: find.byType(EditableText)),
  );
}

void main() {
  testWidgets('inputs do not steal focus until tapped', (tester) async {
    const titleKey = ValueKey('title');
    await tester.pumpWidget(
      const MaterialApp(
        home: FlorienKeyboardDismiss(
          child: Scaffold(body: TextField(key: titleKey)),
        ),
      ),
    );

    expect(tester.widget<TextField>(find.byKey(titleKey)).autofocus, isFalse);
    expect(_editable(tester, titleKey).focusNode.hasFocus, isFalse);
  });

  testWidgets('tapping empty space closes the keyboard', (tester) async {
    const titleKey = ValueKey('title');
    await tester.pumpWidget(
      MaterialApp(
        home: FlorienKeyboardDismiss(
          child: Scaffold(
            body: Column(
              children: [
                const TextField(key: titleKey),
                const SizedBox(height: 80, width: double.infinity),
                TextButton(onPressed: () {}, child: const Text('Kaydet')),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(titleKey));
    await tester.pump();
    expect(_editable(tester, titleKey).focusNode.hasFocus, isTrue);

    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(_editable(tester, titleKey).focusNode.hasFocus, isFalse);
  });

  testWidgets('tapping another text field keeps the keyboard', (tester) async {
    const titleKey = ValueKey('title');
    const notesKey = ValueKey('notes');
    await tester.pumpWidget(
      const MaterialApp(
        home: FlorienKeyboardDismiss(
          child: Scaffold(
            body: Column(
              children: [
                TextField(key: titleKey),
                TextField(key: notesKey),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(titleKey));
    await tester.pump();
    expect(_editable(tester, titleKey).focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(notesKey));
    await tester.pump();
    expect(_editable(tester, notesKey).focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
}
