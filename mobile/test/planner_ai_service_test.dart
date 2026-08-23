import 'package:florien/core/services/planner_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trimConversationForAiRequest keeps only the last four turns', () {
    final conversation = List.generate(
      8,
      (index) => PlannerChatTurn(
        role: index.isEven ? 'user' : 'assistant',
        content: 'message-$index',
      ),
    );

    final trimmed = trimConversationForAiRequest(conversation);

    expect(trimmed, hasLength(4));
    expect(trimmed.first.content, 'message-4');
    expect(trimmed.last.content, 'message-7');
  });

  test('selectAiSubtaskAdditions skips duplicates and caps at five', () {
    final additions = selectAiSubtaskAdditions(
      generated: const [
        'Hazırlık yap',
        'başla',
        'Bitir',
        'Kontrol et',
        'Paylaş',
        'Fazladan adım',
      ],
      existing: const ['Başla'],
    );

    expect(additions, [
      'Hazırlık yap',
      'Bitir',
      'Kontrol et',
      'Paylaş',
      'Fazladan adım',
    ]);
  });
}
