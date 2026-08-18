import 'dart:async';

import 'package:flutter/widgets.dart';

class DelayedScrollChrome extends StatefulWidget {
  const DelayedScrollChrome({
    super.key,
    required this.child,
    required this.onVisibilityChanged,
    this.enabled = true,
    this.delay = const Duration(milliseconds: 500),
  });

  final Widget child;
  final ValueChanged<bool> onVisibilityChanged;
  final bool enabled;
  final Duration delay;

  @override
  State<DelayedScrollChrome> createState() => _DelayedScrollChromeState();
}

class _DelayedScrollChromeState extends State<DelayedScrollChrome> {
  Timer? _hideTimer;
  Timer? _showTimer;
  bool _dragging = false;
  bool _scrollable = false;
  bool _visible = true;

  @override
  void didUpdateWidget(covariant DelayedScrollChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) _reset(notify: false);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _showTimer?.cancel();
    super.dispose();
  }

  bool _handleScroll(ScrollNotification notification) {
    if (!widget.enabled ||
        notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }

    _scrollable =
        notification.metrics.maxScrollExtent -
            notification.metrics.minScrollExtent >
        0.5;
    if (!_scrollable) {
      _reset();
      return false;
    }

    final isUserDrag = switch (notification) {
      ScrollStartNotification(:final dragDetails) => dragDetails != null,
      ScrollUpdateNotification(:final dragDetails) => dragDetails != null,
      OverscrollNotification(:final dragDetails) => dragDetails != null,
      _ => false,
    };
    if (isUserDrag) {
      _dragging = true;
      _scheduleHide();
    }
    return false;
  }

  void _scheduleHide() {
    _showTimer?.cancel();
    if (!_visible || _hideTimer?.isActive == true) return;
    _hideTimer = Timer(widget.delay, () {
      _hideTimer = null;
      if (_dragging && _scrollable && widget.enabled) _setVisible(false);
    });
  }

  void _handlePointerReleased(PointerEvent event) {
    if (!_dragging) return;
    _dragging = false;
    _hideTimer?.cancel();
    _hideTimer = null;
    if (_visible) return;
    _showTimer?.cancel();
    _showTimer = Timer(widget.delay, () {
      _showTimer = null;
      if (widget.enabled) _setVisible(true);
    });
  }

  void _reset({bool notify = true}) {
    _dragging = false;
    _scrollable = false;
    _hideTimer?.cancel();
    _showTimer?.cancel();
    _hideTimer = null;
    _showTimer = null;
    _setVisible(true, notify: notify);
  }

  void _setVisible(bool visible, {bool notify = true}) {
    if (_visible == visible) return;
    _visible = visible;
    if (notify) widget.onVisibilityChanged(visible);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerUp: _handlePointerReleased,
    onPointerCancel: _handlePointerReleased,
    child: NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: widget.child,
    ),
  );
}

class ScrollChromeVisibility extends StatelessWidget {
  const ScrollChromeVisibility({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: child,
    ),
  );
}
