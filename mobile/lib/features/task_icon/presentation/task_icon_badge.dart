import 'package:flutter/material.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/domain/task_icon_result.dart';
import 'package:florien/features/task_icon/presentation/task_category_icon.dart';
import 'package:florien/features/task_icon/presentation/task_icon_registry.dart';

/// Compatibility wrapper around [TaskCategoryIcon].
class TaskIconBadge extends StatelessWidget {
  const TaskIconBadge({
    super.key,
    required this.category,
    this.size = 36,
    this.iconSize,
    this.circular = false,
    this.iconKey,
  });

  factory TaskIconBadge.forCategory(
    TaskCategory category, {
    Key? key,
    double size = 36,
    double? iconSize,
    bool circular = false,
    Key? iconKey,
  }) => TaskIconBadge(
    key: key,
    category: category,
    size: size,
    iconSize: iconSize,
    circular: circular,
    iconKey: iconKey,
  );

  factory TaskIconBadge.forResult(
    TaskIconResult result, {
    Key? key,
    double size = 36,
    bool circular = false,
  }) => TaskIconBadge.forCategory(
    result.category,
    key: key,
    size: size,
    circular: circular,
  );

  factory TaskIconBadge.forTask({
    Key? key,
    required String icon,
    double size = 36,
    double? iconSize,
    bool circular = false,
    Key? iconKey,
  }) => TaskIconBadge(
    key: key,
    category: TaskIconRegistry.categoryForStorageName(icon),
    size: size,
    iconSize: iconSize,
    circular: circular,
    iconKey: iconKey,
  );

  final TaskCategory category;
  final double size;
  final double? iconSize;
  final bool circular;
  final Key? iconKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: TaskCategoryIcon(
        key: ValueKey(category),
        category: category,
        size: size,
        iconSize: iconSize,
        circular: circular,
        iconKey: iconKey,
      ),
    );
  }
}
