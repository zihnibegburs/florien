import 'package:flutter/material.dart';

/// Theme-aware Florien brand mark used throughout the app.
class FlorienLogo extends StatelessWidget {
  const FlorienLogo({
    super.key,
    this.size = 80,
    this.backgroundBrightness,
    this.imageKey,
  });

  static const darkBackgroundAsset =
      'assets/brand/florien-logo-dark-background.png';
  static const lightBackgroundAsset =
      'assets/brand/florien-logo-light-background.png';

  final double size;
  final Brightness? backgroundBrightness;
  final Key? imageKey;

  @override
  Widget build(BuildContext context) {
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final brightness = backgroundBrightness ?? Theme.of(context).brightness;
    return SizedBox(
      width: size,
      height: size * 874 / 1024,
      child: Image.asset(
        brightness == Brightness.dark
            ? darkBackgroundAsset
            : lightBackgroundAsset,
        key: imageKey,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        cacheWidth: px,
        gaplessPlayback: true,
        semanticLabel: 'Florien',
      ),
    );
  }
}
