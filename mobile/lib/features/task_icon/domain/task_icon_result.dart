import 'package:flutter/material.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';

class TaskIconCandidate {
  const TaskIconCandidate({required this.category, required this.confidence});

  final TaskCategory category;
  final double confidence;
}

class TaskIconResult {
  const TaskIconResult({
    required this.category,
    required this.parentCategory,
    required this.icon,
    required this.confidence,
    required this.secondBestConfidence,
    this.topCandidates = const [],
  });

  final TaskCategory category;
  final TaskParentCategory parentCategory;
  final IconData icon;
  final double confidence;
  final double secondBestConfidence;
  final List<TaskIconCandidate> topCandidates;

  bool get isFallback => category == TaskCategory.other;
  double get confidenceMargin => confidence - secondBestConfidence;
}
