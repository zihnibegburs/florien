import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/utils/task_icons.dart';

void main() {
  test('todo and daily tasks use the same default icon', () {
    expect(TaskIcons.defaultName, 'task');
    expect(
      TaskIcons.iconForTask(title: 'Koşu yap', icon: TaskIcons.defaultName),
      Icons.task_alt_rounded,
    );
    expect(
      TaskIcons.iconForTask(title: 'Kitap oku', icon: TaskIcons.defaultName),
      Icons.task_alt_rounded,
    );
    expect(
      TaskIcons.iconForTask(title: 'Herhangi bir görev', icon: ''),
      Icons.task_alt_rounded,
    );
    expect(
      TaskIcons.iconForTask(title: 'Eski görev', icon: 'directions_run'),
      Icons.task_alt_rounded,
    );
  });
}
