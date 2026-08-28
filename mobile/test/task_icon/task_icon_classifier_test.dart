import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:florien/features/task_icon/data/category_embedding_index.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/domain/task_icon_result.dart';
import 'package:florien/features/task_icon/presentation/realtime_task_icon_controller.dart';
import 'package:florien/features/task_icon/services/task_embedding_service.dart';
import 'package:florien/features/task_icon/services/task_icon_classifier.dart';
import 'package:florien/features/task_icon/services/task_icon_classifier_config.dart';

class _FakeEmbeddingService implements TaskEmbeddingService {
  _FakeEmbeddingService({this.delayForText});

  final Duration Function(String text)? delayForText;
  int calls = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<Float32List> embed(String text) async {
    calls++;
    final delay = delayForText?.call(text);
    if (delay != null) await Future<void>.delayed(delay);
    return Float32List.fromList([text.contains('second') ? 2 : 1]);
  }
}

class _FakeIndex implements CategorySimilarityIndex {
  @override
  Future<void> initialize() async {}

  @override
  List<TaskIconCandidate> score(Float32List embedding) {
    final gift = embedding.first == 1;
    return [
      TaskIconCandidate(
        category: gift ? TaskCategory.gift : TaskCategory.groceries,
        confidence: .91,
      ),
      TaskIconCandidate(
        category: gift ? TaskCategory.birthday : TaskCategory.shopping,
        confidence: .72,
      ),
      const TaskIconCandidate(category: TaskCategory.other, confidence: .2),
    ];
  }
}

class _HysteresisEmbeddingService implements TaskEmbeddingService {
  @override
  Future<void> initialize() async {}

  @override
  Future<Float32List> embed(String text) async =>
      Float32List.fromList([text == 'alpha' ? 1 : (text == 'beta' ? 2 : 3)]);
}

class _HysteresisIndex implements CategorySimilarityIndex {
  @override
  Future<void> initialize() async {}

  @override
  List<TaskIconCandidate> score(Float32List embedding) =>
      switch (embedding.first.toInt()) {
        1 => const [
          TaskIconCandidate(category: TaskCategory.gift, confidence: .82),
          TaskIconCandidate(category: TaskCategory.shopping, confidence: .70),
        ],
        2 => const [
          TaskIconCandidate(category: TaskCategory.groceries, confidence: .84),
          TaskIconCandidate(category: TaskCategory.gift, confidence: .80),
        ],
        _ => const [
          TaskIconCandidate(category: TaskCategory.groceries, confidence: .92),
          TaskIconCandidate(category: TaskCategory.gift, confidence: .70),
        ],
      };
}

class _LowConfidenceIndex implements CategorySimilarityIndex {
  @override
  Future<void> initialize() async {}

  @override
  List<TaskIconCandidate> score(Float32List embedding) => const [
    TaskIconCandidate(category: TaskCategory.other, confidence: .11),
    TaskIconCandidate(category: TaskCategory.gift, confidence: .09),
  ];
}

TaskIconClassifier _classifier(
  _FakeEmbeddingService embeddings, {
  TaskIconClassifierConfig config = const TaskIconClassifierConfig(),
}) => TaskIconClassifier(
  embeddingService: embeddings,
  similarityIndex: _FakeIndex(),
  config: config,
);

RealtimeTaskIconController _controller(TaskIconClassifier classifier) =>
    RealtimeTaskIconController(classifier: classifier, debounce: Duration.zero);

void main() {
  test('returns semantic category, parent and confidence', () async {
    final classifier = _classifier(_FakeEmbeddingService());

    final result = await classifier.classify('alpha unique prototype title');

    expect(result.category, TaskCategory.gift);
    expect(result.parentCategory, TaskParentCategory.shopping);
    expect(result.confidence, .91);
    expect(result.secondBestConfidence, .72);
  });

  test('uses the LRU cache for repeated task titles', () async {
    final embeddings = _FakeEmbeddingService();
    final classifier = _classifier(embeddings);

    await classifier.classify('alpha unique prototype title');
    await classifier.classify('second unique prototype title');
    await classifier.classify('alpha unique prototype title');

    expect(embeddings.calls, 2);
  });

  test('uses one cached result for equivalent normalized titles', () async {
    final embeddings = _FakeEmbeddingService();
    final classifier = _classifier(embeddings);

    await classifier.classify('Alpha unique prototype title');
    await classifier.classify('  alpha, unique prototype title  ');

    expect(embeddings.calls, 1);
  });

  test('short titles take the best guess without a margin', () async {
    final classifier = _classifier(
      _FakeEmbeddingService(),
      config: const TaskIconClassifierConfig(
        minimumConfidence: .95,
        minimumConfidenceMargin: .5,
        shortTextMinimumConfidence: .08,
      ),
    );

    final result = await classifier.classify('alpha');

    expect(result.category, TaskCategory.gift);
  });

  test('falls back when confidence margin is ambiguous', () async {
    final classifier = _classifier(
      _FakeEmbeddingService(),
      config: const TaskIconClassifierConfig(minimumConfidenceMargin: .25),
    );

    final result = await classifier.classify(
      'alpha unique prototype title after quarterly briefing session',
    );

    expect(result.category, TaskCategory.other);
  });

  test('rejects low-confidence guesses for short titles', () async {
    final classifier = TaskIconClassifier(
      embeddingService: _FakeEmbeddingService(),
      similarityIndex: _LowConfidenceIndex(),
    );

    final result = await classifier.classify('unclear');

    expect(result.category, TaskCategory.other);
  });

  test(
    'latest input wins when async classifications finish out of order',
    () async {
      final embeddings = _FakeEmbeddingService(
        delayForText: (text) => text.contains('second')
            ? const Duration(milliseconds: 1)
            : const Duration(milliseconds: 30),
      );
      final controller = _controller(_classifier(embeddings));
      addTearDown(controller.dispose);

      final older = controller.onTaskChanged('alpha unique prototype title');
      final newer = controller.onTaskChanged('second unique prototype title');
      await Future.wait([older, newer]);

      expect(controller.value.category, TaskCategory.groceries);
    },
  );

  test(
    'hysteresis keeps a stable icon until the new intent is stronger',
    () async {
      final classifier = TaskIconClassifier(
        embeddingService: _HysteresisEmbeddingService(),
        similarityIndex: _HysteresisIndex(),
      );
      final controller = _controller(classifier);
      addTearDown(controller.dispose);

      await controller.onTaskChanged('alpha');
      expect(controller.value.category, TaskCategory.gift);

      await controller.onTaskChanged('beta');
      expect(controller.value.category, TaskCategory.gift);

      await controller.onTaskChanged('gamma');
      expect(controller.value.category, TaskCategory.groceries);
    },
  );

  test('keeps the previous icon when the next title is unconfident', () async {
    final classifier = TaskIconClassifier(
      embeddingService: _FakeEmbeddingService(),
      similarityIndex: _LowConfidenceIndex(),
    );
    final controller = _controller(classifier);
    addTearDown(controller.dispose);

    await controller.onTaskChanged('Morning run');
    expect(controller.value.category, TaskCategory.running);

    await controller.onTaskChanged(
      'zzz unknown fragment without any strong semantic signal in the wording',
    );
    expect(controller.value.category, TaskCategory.running);
  });
}
