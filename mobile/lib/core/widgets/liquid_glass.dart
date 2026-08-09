import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mimio/core/theme/mimio_theme.dart';

/// Quiet surface tokens. Kept behind the existing API so feature screens can
/// share one consistent, low-noise visual language.
abstract final class LiquidGlassTokens {
  static const double blurSigma = 10;
  static const double blurSigmaChrome = 12;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color tint(BuildContext context, {double? opacity}) {
    final o = opacity ?? 1;
    return context.palette.surface.withValues(alpha: o);
  }

  static Color highlight(BuildContext context) => context.palette.border;

  static Color edgeShadow(BuildContext context) => context.palette.border;

  static List<BoxShadow> elevation(BuildContext context) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark(context) ? 0.14 : 0.04),
      blurRadius: 14,
      offset: const Offset(0, 5),
    ),
  ];
}

/// Solid-first surface with optional, restrained translucency.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding,
    this.margin,
    this.blur = false,
    this.blurSigma = LiquidGlassTokens.blurSigma,
    this.tintColor,
    this.tintOpacity,
    this.borderWidth = 1,
    this.gradient,
    this.boxShadow,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool blur;
  final double blurSigma;
  final Color? tintColor;
  final double? tintOpacity;
  final double borderWidth;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;

  BorderRadius _innerBorderRadius(double inset) {
    if (inset <= 0) return borderRadius;
    return BorderRadius.only(
      topLeft: Radius.circular(
        (borderRadius.topLeft.x - inset).clamp(0.0, double.infinity),
      ),
      topRight: Radius.circular(
        (borderRadius.topRight.x - inset).clamp(0.0, double.infinity),
      ),
      bottomLeft: Radius.circular(
        (borderRadius.bottomLeft.x - inset).clamp(0.0, double.infinity),
      ),
      bottomRight: Radius.circular(
        (borderRadius.bottomRight.x - inset).clamp(0.0, double.infinity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final edge = LiquidGlassTokens.edgeShadow(context);
    final tint =
        tintColor ?? LiquidGlassTokens.tint(context, opacity: tintOpacity);
    final shadows = boxShadow ?? LiquidGlassTokens.elevation(context);
    final innerRadius = _innerBorderRadius(borderWidth);

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadows,
        color: borderWidth > 0 ? edge : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(borderWidth),
        child: ClipRRect(
          borderRadius: innerRadius,
          clipBehavior: clipBehavior,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              if (blur)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              if (gradient != null)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: gradient),
                  ),
                ),
              Positioned.fill(
                child: ColoredBox(
                  color: gradient == null
                      ? tint
                      : tint.withValues(alpha: tintOpacity ?? 0.35),
                ),
              ),
              if (padding != null)
                Padding(padding: padding!, child: child)
              else
                child,
            ],
          ),
        ),
      ),
    );

    if (margin != null) {
      surface = Padding(padding: margin!, child: surface);
    }
    return surface;
  }
}

/// A quiet, neutral canvas that lets content carry the hierarchy.
class MimioAmbientBackground extends StatelessWidget {
  const MimioAmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: context.palette.background, child: child);
  }
}

/// Calm app bar chrome that remains legible over scrolling content.
class LiquidGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LiquidGlassAppBar({super.key, required this.child, this.bottom});

  final Widget child;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.background,
        border: Border(bottom: BorderSide(color: context.palette.border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [child, ?bottom]),
    );
  }
}
