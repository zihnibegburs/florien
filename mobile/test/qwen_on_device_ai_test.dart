import 'dart:io';

import 'package:florien/core/services/planner_ai_service.dart';
import 'package:florien/core/services/qwen_on_device_ai.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCompleter implements QwenCompleter {
  String response =
      '{"reply":"Tamam","tasks":[{"title":"Koşu","durationMinutes":30}]}';

  @override
  Future<String> complete({
    required String systemPrompt,
    required List<PlannerChatTurn> conversation,
  }) async {
    return response;
  }
}

class _ReadyStore implements QwenModelStore {
  @override
  Stream<QwenModelUpdate> acquire(String outputDir) async* {
    yield QwenModelUpdate(progress: 1, modelPath: '$outputDir/qwen.gguf');
  }

  @override
  void dispose() {}
}

void main() {
  test('Qwen on-device chat does not call Gemini', () async {
    final ai = QwenOnDeviceAi(
      completer: _FakeCompleter(),
      models: _ReadyStore(),
      documentsDirectory: () async => Directory.systemTemp,
      nGpuLayers: 0,
    );
    addTearDown(ai.dispose);

    final reply = await ai.send([
      const PlannerChatTurn(role: 'user', content: 'kahvaltı sonra koşu'),
    ]);

    expect(ai.status.phase, QwenAiPhase.ready);
    expect(reply.message, 'Tamam');
    expect(reply.tasks.single.title, 'Koşu');
  });

  test('Qwen on-device breakdown returns step titles', () async {
    final completer = _FakeCompleter()
      ..response = '{"steps":[{"title":"Hazırlan"},{"title":"Başla"}]}';
    final ai = QwenOnDeviceAi(
      completer: completer,
      models: _ReadyStore(),
      documentsDirectory: () async => Directory.systemTemp,
      nGpuLayers: 0,
    );
    addTearDown(ai.dispose);

    expect(await ai.generateSubtasks('Toplantı'), ['Hazırlan', 'Başla']);
  });
}
