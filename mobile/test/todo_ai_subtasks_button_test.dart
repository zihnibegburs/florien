import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/services/planner_ai_service.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/utils/subtask_sequence.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/todo_detail_screen.dart';

class _NoListsNotifier extends TodoListsNotifier {
  @override
  Future<List<TodoListDefinition>> build() async => const [];
}

class _FakeTaskBreakdownService implements TaskBreakdownService {
  @override
  Future<List<String>> generateSubtasks(String title) async => const [
    'İlk adımı hazırla',
    'Başla',
  ];
}

void main() {
  testWidgets('AI alt görev butonu başlıkla görünür ve görev ekler', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todoListsProvider.overrideWith(_NoListsNotifier.new),
          taskBreakdownServiceProvider.overrideWithValue(
            _FakeTaskBreakdownService(),
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const TodoDetailScreen(
            initialTitle: '',
            initialDuration: 15,
            todoListId: null,
          ),
        ),
      ),
    );

    const buttonKey = ValueKey('todo-ai-subtasks-button');
    expect(find.byKey(buttonKey), findsNothing);
    expect(find.text('Görev ayarları'), findsNothing);
    expect(find.text('Liste'), findsNothing);
    expect(
      find.byKey(const ValueKey('todo-detail-subtask-input')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('todo-detail-notes')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('todo-subtasks-section-toggle')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('todo-detail-subtask-input')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('todo-notes-section-toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey('todo-detail-notes')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('todo-detail-title')),
      'Sunum hazırla',
    );
    await tester.pump();
    expect(find.byKey(buttonKey), findsOneWidget);

    await tester.ensureVisible(find.byKey(buttonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(buttonKey));
    await tester.pump();
    await tester.pump();
    expect(find.text('İlk adımı hazırla'), findsOneWidget);
    expect(find.text('Başla'), findsNothing);
    await tester.pump(subtaskCreationStagger);
    expect(find.text('Başla'), findsOneWidget);
  });

  testWidgets('kullanıcı beşten fazla alt görev ekleyebilir', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [todoListsProvider.overrideWith(_NoListsNotifier.new)],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: TodoDetailScreen(
            initialTitle: 'Sunum hazırla',
            initialDuration: 15,
            todoListId: null,
            initialSubtasks: List.generate(5, (index) => 'Adım $index'),
          ),
        ),
      ),
    );

    const inputKey = ValueKey('todo-detail-subtask-input');
    await tester.ensureVisible(find.byKey(inputKey));
    await tester.enterText(find.byKey(inputKey), 'Altıncı adım');
    await tester.tap(find.byTooltip('Alt görev ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Altıncı adım'), findsOneWidget);
    expect(find.text('5/5 adım eklendi'), findsNothing);
  });

  testWidgets('otuz birinci alt görev için uyarı gösterilir', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [todoListsProvider.overrideWith(_NoListsNotifier.new)],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: TodoDetailScreen(
            initialTitle: 'Sunum hazırla',
            initialDuration: 15,
            todoListId: null,
            initialSubtasks: List.generate(30, (index) => 'Adım $index'),
          ),
        ),
      ),
    );

    const inputKey = ValueKey('todo-detail-subtask-input');
    await tester.ensureVisible(find.byKey(inputKey));
    await tester.enterText(find.byKey(inputKey), 'Otuz birinci adım');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('En fazla 30 alt görev ekleyebilirsin.'), findsOneWidget);
  });
}
