import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mimio/core/theme/mimio_theme.dart';

/// Quiet surface tokens. Kept behind the existing API so feature screens can
/// share one consistent, low-noise visual language.
abstract final class LiquidGlassTokens {
  static const double blurSigma = 12;
  static const double blurSigmaChrome = 18;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color tint(BuildContext context, {double? opacity}) {
    final dark = isDark(context);
    final o = opacity ?? (dark ? 0.96 : 0.98);
    return dark
        ? const Color(0xFF222228).withValues(alpha: o)
        : const Color(0xFFFFFDF9).withValues(alpha: o);
  }

  static Color highlight(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.white.withValues(alpha: 0.75);

  static Color edgeShadow(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.04)
      : const Color(0xFFE5E1D9);

  static List<BoxShadow> elevation(BuildContext context) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark(context) ? 0.18 : 0.045),
      blurRadius: 18,
      offset: const Offset(0, 8),
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
    this.blur = true,
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
    final highlight = LiquidGlassTokens.highlight(context);
    final edge = LiquidGlassTokens.edgeShadow(context);
    final tint =
        tintColor ?? LiquidGlassTokens.tint(context, opacity: tintOpacity);
    final shadows = boxShadow ?? LiquidGlassTokens.elevation(context);
    final innerRadius = _innerBorderRadius(borderWidth);

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadows,
        // Gradient padding trick — per-side Border() ignores borderRadius and leaves square corners.
        gradient: borderWidth > 0
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [highlight, highlight.withValues(alpha: 0.42), edge],
                stops: const [0.0, 0.4, 1.0],
              )
            : null,
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
              if (borderWidth > 0)
                Positioned(
                  top: 0,
                  left: 12,
                  right: 12,
                  height: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          highlight.withValues(alpha: 0.55),
                          Colors.transparent,
                        ],
                      ),
                    ),
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

/// Warm, paper-like canvas with restrained brand accents.
class MimioAmbientBackground extends StatelessWidget {
  const MimioAmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = LiquidGlassTokens.isDark(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? const [Color(0xFF17171C), Color(0xFF1B1A20)]
                  : const [Color(0xFFF9F7F2), Color(0xFFF4F1EB)],
            ),
          ),
        ),
        Positioned(
          top: -170,
          right: -130,
          child: _Orb(
            color: MimioColors.primary.withValues(alpha: dark ? 0.10 : 0.07),
            size: 340,
          ),
        ),
        Positioned(
          bottom: -190,
          left: -140,
          child: _Orb(
            color: MimioColors.warning.withValues(alpha: dark ? 0.06 : 0.05),
            size: 360,
          ),
        ),
        child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: LiquidGlassTokens.blurSigmaChrome,
          sigmaY: LiquidGlassTokens.blurSigmaChrome,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: LiquidGlassTokens.tint(
              context,
              opacity: LiquidGlassTokens.isDark(context) ? 0.94 : 0.96,
            ),
            border: Border(
              bottom: BorderSide(
                color: LiquidGlassTokens.highlight(
                  context,
                ).withValues(alpha: 0.35),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [child, ?bottom],
          ),
        ),
      ),
    );
  }
}
