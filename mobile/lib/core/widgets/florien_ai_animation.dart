import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lottie/lottie.dart';

const florienAiAnimationAsset = 'assets/ai/florien_ai_flow.json';

double florienAiVoiceAnimationSpeed({
  required bool isListening,
  required double soundLevel,
}) {
  if (!isListening) return 0.65;
  final energy = soundLevel.clamp(0.0, 1.0);
  return (0.9 + (energy * 2.1)).clamp(0.9, 3.0).toDouble();
}

class FlorienAiAnimation extends StatefulWidget {
  const FlorienAiAnimation({
    super.key,
    this.size = 48,
    this.speed = 1,
    this.animate = false,
    this.fit = BoxFit.contain,
    this.semanticLabel = 'Florien AI',
  });

  final double size;
  final double speed;
  final bool animate;
  final BoxFit fit;
  final String semanticLabel;

  @override
  State<FlorienAiAnimation> createState() => _FlorienAiAnimationState();
}

class _FlorienAiAnimationState extends State<FlorienAiAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Ticker _ticker;
  Duration? _compositionDuration;
  Duration? _lastElapsed;
  bool _reduceMotion = false;

  bool get _shouldAnimate => widget.animate && !_reduceMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _updateTicker();
  }

  @override
  void didUpdateWidget(covariant FlorienAiAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _updateTicker();
  }

  void _onLoaded(LottieComposition composition) {
    _compositionDuration = composition.duration;
    _controller.duration = composition.duration;
    _updateTicker();
  }

  void _updateTicker() {
    if (_compositionDuration == null || !_shouldAnimate) {
      if (_ticker.isActive) _ticker.stop();
      _lastElapsed = null;
      if (_reduceMotion || _controller.value == 0) _controller.value = 0.35;
      return;
    }
    if (!_ticker.isActive) {
      _lastElapsed = null;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final duration = _compositionDuration;
    final previous = _lastElapsed;
    _lastElapsed = elapsed;
    if (duration == null || previous == null || !_shouldAnimate) return;

    final delta = elapsed - previous;
    final speed = widget.speed.clamp(0.1, 4.0).toDouble();
    final advance = delta.inMicroseconds / duration.inMicroseconds * speed;
    _controller.value = (_controller.value + advance) % 1;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: SizedBox.square(
        dimension: widget.size,
        child: Lottie.asset(
          florienAiAnimationAsset,
          key: const ValueKey('florien-ai-lottie'),
          controller: _controller,
          onLoaded: _onLoaded,
          repeat: false,
          fit: widget.fit,
          frameRate: FrameRate.composition,
        ),
      ),
    );
  }
}
