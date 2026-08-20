import 'package:flutter/widgets.dart';

class DelayedScrollChrome extends StatefulWidget {
  const DelayedScrollChrome({
    super.key,
    required this.child,
    required this.onVisibilityChanged,
    this.enabled = true,
    this.hideOffset = 96,
    this.revealTravel = 24,
  });

  final Widget child;
  final ValueChanged<bool> onVisibilityChanged;
  final bool enabled;
  final double hideOffset;
  final double revealTravel;

  @override
  State<DelayedScrollChrome> createState() => _DelayedScrollChromeState();
}

class _DelayedScrollChromeState extends State<DelayedScrollChrome> {
  bool _dragging = false;
  bool _scrollable = false;
  bool _visible = true;
  double _upwardTravel = 0;
  double _downwardTravel = 0;

  @override
  void didUpdateWidget(covariant DelayedScrollChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) _reset(notify: false);
  }

  bool _handleScroll(ScrollNotification notification) {
    if (!widget.enabled || notification.metrics.axis != Axis.vertical) {
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

    if (notification case ScrollStartNotification(:final dragDetails)) {
      _dragging = dragDetails != null;
      _upwardTravel = 0;
      _downwardTravel = 0;
    } else if (notification case ScrollUpdateNotification(
      :final dragDetails,
      :final scrollDelta,
    )) {
      if (dragDetails != null) _dragging = true;
      if (_dragging) _handleDelta(scrollDelta ?? 0, notification.metrics);
    } else if (notification case OverscrollNotification(
      :final dragDetails,
      :final overscroll,
    )) {
      if (dragDetails != null) _dragging = true;
      if (_dragging) _handleDelta(overscroll, notification.metrics);
    } else if (notification is ScrollEndNotification) {
      _dragging = false;
      _upwardTravel = 0;
      _downwardTravel = 0;
    }
    return false;
  }

  void _handleDelta(double delta, ScrollMetrics metrics) {
    if (delta > 0) {
      _downwardTravel = 0;
      _upwardTravel += delta;
      if (_visible && _upwardTravel >= widget.hideOffset) {
        _setVisible(false);
      }
      return;
    }
    if (delta >= 0 || _visible) return;
    _upwardTravel = 0;
    _downwardTravel += -delta;
    if (_downwardTravel >= widget.revealTravel || metrics.pixels <= 0) {
      _setVisible(true);
      _downwardTravel = 0;
    }
  }

  void _reset({bool notify = true}) {
    _dragging = false;
    _scrollable = false;
    _upwardTravel = 0;
    _downwardTravel = 0;
    _setVisible(true, notify: notify);
  }

  void _setVisible(bool visible, {bool notify = true}) {
    if (_visible == visible) return;
    _visible = visible;
    if (notify) widget.onVisibilityChanged(visible);
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: widget.child,
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
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 150),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: visible
          ? KeyedSubtree(key: const ValueKey(true), child: child)
          : const SizedBox.shrink(key: ValueKey(false)),
    ),
  );
}
