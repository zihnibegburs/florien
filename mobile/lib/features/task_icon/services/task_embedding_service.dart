import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:florien/features/task_icon/services/task_icon_classifier_config.dart';
import 'package:florien/features/task_icon/services/word_piece_tokenizer.dart';

abstract interface class TaskEmbeddingService {
  Future<void> initialize();
  Future<Float32List> embed(String text);
}

class LeallaTaskEmbeddingService implements TaskEmbeddingService {
  LeallaTaskEmbeddingService({
    this.config = const TaskIconClassifierConfig(),
    OnnxRuntime? runtime,
  }) : _runtime = runtime ?? OnnxRuntime();

  final TaskIconClassifierConfig config;
  final OnnxRuntime _runtime;
  Future<void>? _initialization;
  OrtSession? _session;
  WordPieceTokenizer? _tokenizer;

  @override
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      final vocabulary = await rootBundle.loadString(config.vocabularyAsset);
      final tokenizer = WordPieceTokenizer.fromVocabularyText(vocabulary);
      final session = await _runtime.createSessionFromAsset(
        config.modelAsset,
        options: OrtSessionOptions(intraOpNumThreads: 1, interOpNumThreads: 1),
      );
      if (!session.inputNames.contains('input_ids') ||
          !session.outputNames.contains('sentence_embedding')) {
        await session.close();
        throw StateError('Unexpected LEALLA ONNX input/output contract');
      }
      _tokenizer = tokenizer;
      _session = session;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  @override
  Future<Float32List> embed(String text) async {
    await initialize();
    final tokenizer = _tokenizer!;
    final session = _session!;
    final tokens = tokenizer.encode(text, maxLength: config.maxSequenceLength);
    final shape = [1, config.maxSequenceLength];
    final inputIds = await OrtValue.fromList(tokens.inputIds, shape);
    final attentionMask = await OrtValue.fromList(tokens.attentionMask, shape);
    final tokenTypeIds = await OrtValue.fromList(tokens.tokenTypeIds, shape);
    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({
        'input_ids': inputIds,
        'attention_mask': attentionMask,
        'token_type_ids': tokenTypeIds,
      });
      final raw = await outputs['sentence_embedding']!.asFlattenedList();
      if (raw.length != config.embeddingDimensions) {
        throw StateError('Unexpected LEALLA embedding shape: ${raw.length}');
      }
      final vector = Float32List(config.embeddingDimensions);
      var squaredNorm = 0.0;
      for (var index = 0; index < vector.length; index++) {
        final value = (raw[index] as num).toDouble();
        vector[index] = value;
        squaredNorm += value * value;
      }
      final norm = math.sqrt(squaredNorm);
      if (!norm.isFinite || norm <= 1e-12) {
        throw StateError('LEALLA produced an invalid embedding');
      }
      for (var index = 0; index < vector.length; index++) {
        vector[index] /= norm;
      }
      return vector;
    } finally {
      await inputIds.dispose();
      await attentionMask.dispose();
      await tokenTypeIds.dispose();
      if (outputs != null) {
        for (final output in outputs.values) {
          await output.dispose();
        }
      }
    }
  }
}
