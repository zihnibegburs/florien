import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/services/planner_ai_service.dart';
import 'package:florien/core/services/qwen_ai_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ActiveLanguage.code = 'tr');

  test('parses planner JSON even when wrapped in markdown', () {
    final reply = parseQwenPlannerChat('''
Here you go
```json
{"reply":"Hazır","tasks":[{"title":"Kahvaltı","durationMinutes":20},{"title":"Toplantı","durationMinutes":45}]}
```
''');

    expect(reply.message, 'Hazır');
    expect(reply.tasks.map((task) => task.title), ['Kahvaltı', 'Toplantı']);
    expect(reply.tasks.first.durationMinutes, 20);
  });

  test('keeps raw text when planner JSON is missing', () {
    final reply = parseQwenPlannerChat('Planı biraz daha anlatır mısın?');
    expect(reply.message, 'Planı biraz daha anlatır mısın?');
    expect(reply.tasks, isEmpty);
  });

  test('builds Qwen ChatML without extra wrapping', () {
    expect(
      buildQwenChatPrompt(
        systemPrompt: 'JSON only',
        conversation: const [
          PlannerChatTurn(role: 'user', content: 'kahvaltı'),
        ],
      ),
      '<|im_start|>system\nJSON only\n<|im_end|>\n'
      '<|im_start|>user\nkahvaltı\n<|im_end|>\n'
      '<|im_start|>assistant\n',
    );
  });

  test('parses breakdown steps from JSON', () {
    expect(
      parseQwenBreakdownSteps(
        '{"steps":[{"title":"Çantayı hazırla"},{"title":"Yola çık"}]}',
      ),
      ['Çantayı hazırla', 'Yola çık'],
    );
  });
}
