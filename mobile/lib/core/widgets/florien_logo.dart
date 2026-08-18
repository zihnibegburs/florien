import 'package:flutter/material.dart';

/// Brand mark used on auth and onboarding screens.
class FlorienLogo extends StatelessWidget {
  const FlorienLogo({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        'assets/brand/florien-symbol-color.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        cacheWidth: px,
        gaplessPlayback: true,
      ),
    );
  }
}
