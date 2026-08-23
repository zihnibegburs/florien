import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

void florienDismissKeyboard([PointerDownEvent? event]) {
  final focus = FocusManager.instance.primaryFocus;
  if (focus == null || !focus.hasFocus) return;
  if (event != null && _pointerHitsEditable(event)) return;
  focus.unfocus();
}

bool _pointerHitsEditable(PointerDownEvent event) {
  final result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);
  for (final entry in result.path) {
    if (entry.target is RenderEditable) return true;
  }
  return false;
}

/// Dismisses the keyboard on a tap that is not on another text input.
class FlorienKeyboardDismiss extends StatelessWidget {
  const FlorienKeyboardDismiss({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: florienDismissKeyboard,
      child: child,
    );
  }
}
