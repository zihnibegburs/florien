import 'package:flutter/foundation.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/domain/task_icon_result.dart';
import 'package:florien/features/task_icon/presentation/task_icon_mapper.dart';
import 'package:florien/features/task_icon/services/task_icon_classifier.dart';

class RealtimeTaskIconController extends ValueNotifier<TaskIconResult> {
  RealtimeTaskIconController({
    TaskIconClassifier? classifier,
    String initialCategory = 'other',
  }) : _classifier = classifier ?? TaskIconClassifier.instance,
       super(_initialResult(initialCategory));

  final TaskIconClassifier _classifier;
  var _generation = 0;

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

  Future<void> onTaskChanged(String text) async {
    final generation = ++_generation;
    final candidate = await _classifier.classify(
      text,
      includeDebugCandidates: true,
    );
    if (generation != _generation) return;
    value = _stableResult(candidate);
  }

  TaskIconResult _stableResult(TaskIconResult candidate) {
    final current = value;
    if (candidate.category == current.category ||
        current.category == TaskCategory.other) {
      return candidate;
    }
    var currentScore = double.negativeInfinity;
    for (final item in candidate.topCandidates) {
      if (item.category == current.category) {
        currentScore = item.confidence;
        break;
      }
    }
    if (candidate.category == TaskCategory.other) {
      if (currentScore >=
          _classifier.config.minimumConfidence -
              _classifier.config.switchMargin) {
        return TaskIconResult(
          category: current.category,
          parentCategory: current.parentCategory,
          icon: current.icon,
          confidence: currentScore,
          secondBestConfidence: candidate.confidence,
          topCandidates: candidate.topCandidates,
        );
      }
      return candidate;
    }
    if (candidate.confidence < currentScore + _classifier.config.switchMargin) {
      return TaskIconResult(
        category: current.category,
        parentCategory: current.parentCategory,
        icon: current.icon,
        confidence: currentScore,
        secondBestConfidence: candidate.confidence,
        topCandidates: candidate.topCandidates,
      );
    }
    return candidate;
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
