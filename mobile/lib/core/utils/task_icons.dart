import 'package:flutter/material.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/presentation/task_icon_mapper.dart';

class TaskIcons {
  const TaskIcons._();

  static const defaultName = 'other';
  static const defaultIcon = TaskIconMapper.fallback;

  // Older tasks may still contain the former presentation-oriented names.
  // They remain readable, while all newly classified tasks store a semantic
  // TaskCategory.storageName.
  static const _legacyIcons = <String, IconData>{
    'task': defaultIcon,
    'school': Icons.school_rounded,
    'menu_book': Icons.menu_book_rounded,
    'work': Icons.work_rounded,
    'groups': Icons.groups_rounded,
    'fitness': Icons.fitness_center_rounded,
    'directions_run': Icons.directions_run_rounded,
    'directions_walk': Icons.directions_walk_rounded,
    'restaurant': Icons.restaurant_rounded,
    'free_breakfast': Icons.free_breakfast_rounded,
    'cleaning': Icons.cleaning_services_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'health': Icons.health_and_safety_rounded,
    'medication': Icons.medication_rounded,
    'music': Icons.music_note_rounded,
    'code': Icons.code_rounded,
    'bedtime': Icons.bedtime_rounded,
    'self_improvement': Icons.self_improvement_rounded,
    'timer': Icons.timer_rounded,
    'lightbulb': Icons.lightbulb_rounded,
    'slideshow': Icons.slideshow_rounded,
    'search': Icons.search_rounded,
    'videocam': Icons.videocam_rounded,
    'movie': Icons.movie_rounded,
    'brush': Icons.brush_rounded,
    'directions_car': Icons.directions_car_rounded,
    'child_care': Icons.child_care_rounded,
    'pets': Icons.pets_rounded,
    'yard': Icons.yard_rounded,
    'water_drop': Icons.water_drop_rounded,
  };

  static IconData iconForTask({required String title, required String icon}) =>
      fromName(icon);

  static IconData fromName(String name) {
    final category = taskCategoryByStorageName[name];
    if (category != null) return TaskIconMapper.iconFor(category);
    return _legacyIcons[name] ?? defaultIcon;
  }
}
