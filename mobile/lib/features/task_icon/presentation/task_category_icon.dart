import 'package:flutter/material.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/presentation/task_icon_mapper.dart';
import 'package:florien/features/task_icon/presentation/task_icon_registry.dart';

class TaskCategoryIcon extends StatelessWidget {
  const TaskCategoryIcon({
    super.key,
    required this.category,
    this.size = 24,
    this.iconSize,
    this.showBackground = true,
    this.circular = false,
    this.iconKey,
  });

  factory TaskCategoryIcon.fromStorageName(
    String name, {
    Key? key,
    double size = 24,
    double? iconSize,
    bool showBackground = true,
    bool circular = false,
    Key? iconKey,
  }) => TaskCategoryIcon(
    key: key,
    category: TaskIconRegistry.categoryForStorageName(name),
    size: size,
    iconSize: iconSize,
    showBackground: showBackground,
    circular: circular,
    iconKey: iconKey,
  );

  final TaskCategory category;
  final double size;
  final double? iconSize;
  final bool showBackground;
  final bool circular;
  final Key? iconKey;

  @override
  Widget build(BuildContext context) {
    final accent = TaskIconMapper.colorFor(category);
    final glyphSize = iconSize ?? (showBackground ? size * 0.58 : size);
    final stroke = Color.lerp(const Color(0xFF2A3142), accent, 0.55)!;
    final fill = Color.lerp(accent, const Color(0xFFFFFFFF), 0.12)!;
    final innerFill = Color.lerp(const Color(0xFF7ED7F2), accent, 0.28)!;

    Widget glyph = KeyedSubtree(
      key: iconKey,
      child: TaskIconRegistry.iconFor(category).multiColor(
        size: glyphSize,
        strokeWidth: glyphSize >= 72 ? 3.6 : 3.0,
        outStrokeColor: stroke,
        outFillColor: fill,
        innerStrokeColor: const Color(0xFFF7F8FC),
        innerFillColor: innerFill,
      ),
    );

    if (!showBackground) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: glyph),
      );
    }

    final radius = circular
        ? BorderRadius.circular(size)
        : BorderRadius.circular(FlorienRadius.sm);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: radius,
      ),
      child: glyph,
    );
  }
}
