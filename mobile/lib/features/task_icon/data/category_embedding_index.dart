import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/domain/task_icon_result.dart';
import 'package:florien/features/task_icon/services/task_icon_classifier_config.dart';

abstract interface class CategorySimilarityIndex {
  Future<void> initialize();
  List<TaskIconCandidate> score(Float32List normalizedEmbedding);
}

class AssetCategoryEmbeddingIndex implements CategorySimilarityIndex {
  AssetCategoryEmbeddingIndex({this.config = const TaskIconClassifierConfig()});

  static const _headerLength = 12;

  final TaskIconClassifierConfig config;
  Future<void>? _initialization;
  Uint8List? _vectors;
  Float32List? _scales;
  int _examplesPerCategory = 0;

  @override
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      final loaded = await Future.wait([
        rootBundle.load(config.prototypeAsset),
        rootBundle.loadString(config.prototypeManifestAsset),
      ]);
      final data = loaded[0] as ByteData;
      final manifest = jsonDecode(loaded[1] as String) as Map<String, dynamic>;
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      if (bytes.length < _headerLength ||
          ascii.decode(bytes.sublist(0, 4)) != 'TIE1') {
        throw const FormatException('Invalid task icon embedding header');
      }
      final version = data.getUint16(4, Endian.little);
      final dimensions = data.getUint16(6, Endian.little);
      final totalExamples = data.getUint32(8, Endian.little);
      if (version != 1 || dimensions != config.embeddingDimensions) {
        throw FormatException(
          'Unsupported task icon embedding format v$version/$dimensions',
        );
      }
      final categories = manifest['categories'] as List<dynamic>;
      if (categories.length != TaskCategory.values.length ||
          totalExamples % categories.length != 0) {
        throw const FormatException('Task icon category manifest mismatch');
      }
      for (var index = 0; index < categories.length; index++) {
        final category = categories[index] as Map<String, dynamic>;
        if (category['name'] != TaskCategory.values[index].storageName) {
          throw FormatException('Task icon category order mismatch at $index');
        }
      }
      final rowLength = 4 + dimensions;
      if (bytes.length != _headerLength + totalExamples * rowLength) {
        throw const FormatException('Task icon embedding data is truncated');
      }

      final vectors = Uint8List(totalExamples * dimensions);
      final scales = Float32List(totalExamples);
      var sourceOffset = _headerLength;
      for (var row = 0; row < totalExamples; row++) {
        scales[row] = data.getFloat32(sourceOffset, Endian.little);
        sourceOffset += 4;
        vectors.setRange(
          row * dimensions,
          (row + 1) * dimensions,
          bytes,
          sourceOffset,
        );
        sourceOffset += dimensions;
      }
      _examplesPerCategory = totalExamples ~/ categories.length;
      _vectors = vectors;
      _scales = scales;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  @override
  List<TaskIconCandidate> score(Float32List normalizedEmbedding) {
    final vectors = _vectors;
    final scales = _scales;
    if (vectors == null || scales == null) {
      throw StateError('Category embeddings are not initialized');
    }
    if (normalizedEmbedding.length != config.embeddingDimensions) {
      throw ArgumentError.value(
        normalizedEmbedding.length,
        'normalizedEmbedding.length',
      );
    }

    final output = <TaskIconCandidate>[];
    final dimensions = config.embeddingDimensions;
    for (final category in TaskCategory.values) {
      var top1 = -2.0;
      var top2 = -2.0;
      var top3 = -2.0;
      final firstRow = category.index * _examplesPerCategory;
      final lastRow = firstRow + _examplesPerCategory;
      for (var row = firstRow; row < lastRow; row++) {
        var dot = 0.0;
        final vectorOffset = row * dimensions;
        final scale = scales[row];
        for (var column = 0; column < dimensions; column++) {
          final raw = vectors[vectorOffset + column];
          final signed = raw < 128 ? raw : raw - 256;
          dot += normalizedEmbedding[column] * signed * scale;
        }
        if (dot > top1) {
          top3 = top2;
          top2 = top1;
          top1 = dot;
        } else if (dot > top2) {
          top3 = top2;
          top2 = dot;
        } else if (dot > top3) {
          top3 = dot;
        }
      }
      final count = config.topExamplesPerCategory.clamp(1, 3);
      final sum = top1 + (count >= 2 ? top2 : 0) + (count >= 3 ? top3 : 0);
      output.add(
        TaskIconCandidate(category: category, confidence: sum / count),
      );
    }
    output.sort((left, right) => right.confidence.compareTo(left.confidence));
    return output;
  }
}
