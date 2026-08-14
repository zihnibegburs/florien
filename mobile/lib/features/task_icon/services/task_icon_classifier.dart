import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:florien/features/task_icon/data/category_embedding_index.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/domain/task_icon_result.dart';
import 'package:florien/features/task_icon/presentation/task_icon_mapper.dart';
import 'package:florien/features/task_icon/services/task_embedding_service.dart';
import 'package:florien/features/task_icon/services/task_icon_classifier_config.dart';

class TaskIconClassifier {
  TaskIconClassifier({
    TaskEmbeddingService? embeddingService,
    CategorySimilarityIndex? similarityIndex,
    this.config = const TaskIconClassifierConfig(),
  }) : _embeddingService =
           embeddingService ?? LeallaTaskEmbeddingService(config: config),
       _similarityIndex =
           similarityIndex ?? AssetCategoryEmbeddingIndex(config: config);

  static final instance = TaskIconClassifier();

  final TaskEmbeddingService _embeddingService;
  final CategorySimilarityIndex _similarityIndex;
  final TaskIconClassifierConfig config;
  final LinkedHashMap<String, TaskIconResult> _cache = LinkedHashMap();
  Future<void>? _initialization;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      await Future.wait([
        _embeddingService.initialize(),
        _similarityIndex.initialize(),
      ]);
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<TaskIconResult> classify(
    String text, {
    bool includeDebugCandidates = kDebugMode,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) return fallback();
    final cacheKey = normalizedText;
    final cached = _cache.remove(cacheKey);
    if (cached != null) {
      _cache[cacheKey] = cached;
      return includeDebugCandidates ? cached : _withoutCandidates(cached);
    }

    await initialize();
    final embedding = await _embeddingService.embed(normalizedText);
    final candidates = _similarityIndex.score(embedding);
    final best = candidates.first;
    final second = candidates.length > 1
        ? candidates[1]
        : const TaskIconCandidate(category: TaskCategory.other, confidence: -1);
    final shortTextBoost =
        normalizedText.runes.length <= config.shortTextCodePointLimit
        ? config.shortTextConfidenceBoost
        : 0.0;
    final isConfident =
        best.category != TaskCategory.other &&
        best.confidence >= config.minimumConfidence + shortTextBoost &&
        best.confidence - second.confidence >= config.minimumConfidenceMargin;
    final result = isConfident
        ? TaskIconResult(
            category: best.category,
            parentCategory: best.category.parent,
            icon: TaskIconMapper.iconFor(best.category),
            confidence: best.confidence,
            secondBestConfidence: second.confidence,
            topCandidates: List.unmodifiable(
              candidates.take(config.debugCandidateCount),
            ),
          )
        : fallback(
            confidence: best.confidence,
            secondBestConfidence: second.confidence,
            topCandidates: candidates,
          );
    _cache[cacheKey] = result;
    while (_cache.length > config.cacheCapacity) {
      _cache.remove(_cache.keys.first);
    }
    return includeDebugCandidates ? result : _withoutCandidates(result);
  }

  TaskIconResult fallback({
    double confidence = 0,
    double secondBestConfidence = 0,
    List<TaskIconCandidate> topCandidates = const [],
  }) => TaskIconResult(
    category: TaskCategory.other,
    parentCategory: TaskParentCategory.other,
    icon: TaskIconMapper.fallback,
    confidence: confidence,
    secondBestConfidence: secondBestConfidence,
    topCandidates: List.unmodifiable(
      topCandidates.take(config.debugCandidateCount),
    ),
  );

  TaskIconResult _withoutCandidates(TaskIconResult value) => TaskIconResult(
    category: value.category,
    parentCategory: value.parentCategory,
    icon: value.icon,
    confidence: value.confidence,
    secondBestConfidence: value.secondBestConfidence,
  );
}
