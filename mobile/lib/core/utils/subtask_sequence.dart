import 'dart:async';

const subtaskCreationStagger = Duration(milliseconds: 70);

Future<void> revealSubtasksSequentially({
  required Iterable<String> subtasks,
  required bool Function() canContinue,
  required FutureOr<void> Function(String subtask) onReveal,
  Duration delay = subtaskCreationStagger,
}) async {
  final pending = subtasks.toList(growable: false);
  for (var index = 0; index < pending.length; index++) {
    if (!canContinue()) return;
    await onReveal(pending[index]);
    if (index < pending.length - 1 && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }
}
