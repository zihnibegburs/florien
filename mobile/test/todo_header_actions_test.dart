import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/todo_list_tab.dart';

class _TestInboxNotifier extends InboxNotifier {
  @override
  Future<List<TaskModel>> build() async => const [];
}

class _TestTodoListsNotifier extends TodoListsNotifier {
  @override
  Future<List<TodoListDefinition>> build() async => const [];
}

class _NamedTodoListsNotifier extends TodoListsNotifier {
  @override
  Future<List<TodoListDefinition>> build() async => const [
    TodoListDefinition(id: 'list-1', name: 'Deneme', description: ''),
  ];
}

void main() {
  testWidgets('todo header actions have a size and open their overlays', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxProvider.overrideWith(_TestInboxNotifier.new),
          todoListsProvider.overrideWith(_TestTodoListsNotifier.new),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: TodoListTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Yeni liste oluştur'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni liste'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Liste seçenekleri'));
    await tester.pumpAndSettle();
    expect(find.text('Düzenleme listeleri'), findsOneWidget);
    await tester.tapAt(const Offset(8, 300));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Yeni yapılacak ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Ne yapman gerekiyor?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('new list button follows the final list title', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxProvider.overrideWith(_TestInboxNotifier.new),
          todoListsProvider.overrideWith(_NamedTodoListsNotifier.new),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(body: TodoListTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final finalTitle = find.text('Deneme');
    final addButton = find.byTooltip('Yeni liste oluştur');
    expect(finalTitle, findsOneWidget);
    expect(addButton, findsOneWidget);
    expect(
      tester.getTopLeft(addButton).dx,
      greaterThan(tester.getTopRight(finalTitle).dx),
    );
  });
}
