import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:florien/features/task_icon/data/category_embedding_index.dart';
import 'package:florien/features/task_icon/data/task_icon_lexicon.dart';
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

    final lexicalCategory = TaskIconLexicon.match(normalizedText);
    if (lexicalCategory != null) {
      return _resultFor(
        lexicalCategory,
        confidence: 1,
        secondBestConfidence: 0,
      );
    }

    if (normalizedText.runes.length < 3) return fallback();

    // Canonicalize casing, punctuation and spacing so the same title has a
    // single cached result.
    final cacheKey = TaskIconLexicon.normalize(normalizedText);
    final cached = _cache.remove(cacheKey);
    if (cached != null) {
      _cache[cacheKey] = cached;
      return includeDebugCandidates ? cached : _withoutCandidates(cached);
    }

    try {
      await initialize();
      final embedding = await _embeddingService.embed(normalizedText);
      final candidates = _similarityIndex.score(embedding);
      final chosen = _pick(normalizedText, candidates);
      final result = chosen;
      _cache[cacheKey] = result;
      while (_cache.length > config.cacheCapacity) {
        _cache.remove(_cache.keys.first);
      }
      return includeDebugCandidates ? result : _withoutCandidates(result);
    } catch (error, stackTrace) {
      debugPrint('Task icon classify failed: $error\n$stackTrace');
      return fallback();
    }
  }

  TaskIconResult _pick(String text, List<TaskIconCandidate> candidates) {
    final best = _bestReal(candidates) ?? candidates.first;
    final second = candidates.length > 1
        ? candidates[1]
        : const TaskIconCandidate(category: TaskCategory.other, confidence: -1);
    final short = text.runes.length <= config.shortTextCodePointLimit;
    final minScore = short
        ? config.shortTextMinimumConfidence
        : config.minimumConfidence;
    final needsMargin = !short;
    final accepts =
        best.category != TaskCategory.other &&
        best.confidence >= minScore &&
        (!needsMargin ||
            best.confidence - second.confidence >=
                config.minimumConfidenceMargin);
    if (!accepts) {
      return fallback(
        confidence: best.confidence,
        secondBestConfidence: second.confidence,
        topCandidates: candidates,
      );
    }
    return _resultFor(
      best.category,
      confidence: best.confidence,
      secondBestConfidence: second.confidence,
      topCandidates: candidates,
    );
  }

  TaskIconCandidate? _bestReal(List<TaskIconCandidate> candidates) {
    for (final candidate in candidates) {
      if (candidate.category != TaskCategory.other) return candidate;
    }
    return null;
  }

  TaskIconResult _resultFor(
    TaskCategory category, {
    required double confidence,
    required double secondBestConfidence,
    List<TaskIconCandidate> topCandidates = const [],
  }) => TaskIconResult(
    category: category,
    parentCategory: category.parent,
    icon: TaskIconMapper.iconFor(category),
    confidence: confidence,
    secondBestConfidence: secondBestConfidence,
    topCandidates: List.unmodifiable(
      topCandidates.take(config.debugCandidateCount),
    ),
  );

  TaskIconResult fallback({
    double confidence = 0,
    double secondBestConfidence = 0,
    List<TaskIconCandidate> topCandidates = const [],
  }) => _resultFor(
    TaskCategory.other,
    confidence: confidence,
    secondBestConfidence: secondBestConfidence,
    topCandidates: topCandidates,
  );

  TaskIconResult _withoutCandidates(TaskIconResult value) => TaskIconResult(
    category: value.category,
    parentCategory: value.parentCategory,
    icon: value.icon,
    confidence: value.confidence,
    secondBestConfidence: value.secondBestConfidence,
  );
}
