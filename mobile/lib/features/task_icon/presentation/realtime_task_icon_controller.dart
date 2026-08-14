import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/domain/task_icon_result.dart';
import 'package:florien/features/task_icon/presentation/task_icon_mapper.dart';
import 'package:florien/features/task_icon/services/task_icon_classifier.dart';

class RealtimeTaskIconController extends ValueNotifier<TaskIconResult> {
  RealtimeTaskIconController({
    TaskIconClassifier? classifier,
    String initialCategory = 'other',
    this.debounce = const Duration(milliseconds: 200),
  }) : _classifier = classifier ?? TaskIconClassifier.instance,
       super(_initialResult(initialCategory));

  final TaskIconClassifier _classifier;
  final Duration debounce;
  var _generation = 0;
  Timer? _debounce;

  static TaskIconResult _initialResult(String categoryName) {
    final category =
        taskCategoryByStorageName[categoryName] ?? TaskCategory.other;
    return TaskIconResult(
      category: category,
      parentCategory: category.parent,
      icon: TaskIconMapper.iconFor(category),
      confidence: 0,
      secondBestConfidence: 0,
    );
  }

  Future<void> onTaskChanged(String text) {
    _debounce?.cancel();
    final generation = ++_generation;
    if (debounce <= Duration.zero) {
      return _classify(text, generation);
    }
    final done = Completer<void>();
    _debounce = Timer(debounce, () {
      done.complete(_classify(text, generation));
    });
    return done.future;
  }

  Future<void> _classify(String text, int generation) async {
    try {
      if (text.trim().isEmpty) {
        if (generation != _generation) return;
        _setIfChanged(_classifier.fallback());
        return;
      }
      final candidate = await _classifier.classify(
        text,
        includeDebugCandidates: true,
      );
      if (generation != _generation) return;
      _setIfChanged(_stableResult(candidate));
    } catch (error, stackTrace) {
      debugPrint('Realtime task icon update failed: $error\n$stackTrace');
    }
  }

  void _setIfChanged(TaskIconResult next) {
    if (next.category == value.category) return;
    value = next;
  }

  TaskIconResult _stableResult(TaskIconResult candidate) {
    final current = value;
    if (candidate.category == current.category ||
        current.category == TaskCategory.other) {
      return candidate;
    }
    if (candidate.isFallback) return current;

    var currentScore = double.negativeInfinity;
    for (final item in candidate.topCandidates) {
      if (item.category == current.category) {
        currentScore = item.confidence;
        break;
      }
    }
    if (candidate.confidence < _classifier.config.minimumConfidence) {
      return current;
    }
    if (candidate.confidence < currentScore + _classifier.config.switchMargin) {
      return current;
    }
    return candidate;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _generation++;
    super.dispose();
  }
}
