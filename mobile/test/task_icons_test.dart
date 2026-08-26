import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/utils/task_icons.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/presentation/task_icon_mapper.dart';
import 'package:florien/features/task_icon/presentation/task_icon_registry.dart';

void main() {
  test('todo and daily tasks use the same default icon', () {
    expect(TaskIcons.defaultName, 'other');
    expect(
      TaskIcons.iconForTask(title: 'Koşu yap', icon: TaskIcons.defaultName),
      TaskIconMapper.fallback,
    );
    expect(
      TaskIcons.iconForTask(title: 'Kitap oku', icon: TaskIcons.defaultName),
      TaskIconMapper.fallback,
    );
    expect(
      TaskIcons.iconForTask(title: 'Herhangi bir görev', icon: ''),
      TaskIconMapper.fallback,
    );
    expect(
      TaskIcons.iconForTask(title: 'Eski görev', icon: 'directions_run'),
      Icons.directions_run_rounded,
    );
    expect(TaskIcons.nameForTitle('Su iç ve bedenini uyandır'), 'drinks');
    expect(TaskIcons.nameForTitle('Bilinmeyen adım', fallback: 'work'), 'work');
  });

  test('every category maps to an IconPark icon', () {
    final names = {
      for (final category in TaskCategory.values)
        category: TaskIconRegistry.iconName(category),
    };
    expect(names.length, TaskCategory.values.length);
    expect(names[TaskCategory.groceries], 'shoppingCart');
    expect(names[TaskCategory.running], 'sport');
    expect(names[TaskCategory.coding], 'codeLaptop');
    expect(names[TaskCategory.flight], 'airplane');
    expect(names[TaskCategory.other], 'listCheckbox');
    expect(
      TaskIconRegistry.categoryForStorageName('directions_run'),
      TaskCategory.running,
    );
  });
}
