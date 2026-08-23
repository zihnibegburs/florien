import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/theme/florien_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('light theme uses a readable primary text accent', () {
    final primary = FlorienTheme.light.colorScheme.primary;

    expect(primary, FlorienColors.accentText);
    expect(_contrastRatio(primary, Colors.white), greaterThanOrEqualTo(4.5));
  });

  test('pastel tokens stay quieter than lemon and ink', () {
    expect(FlorienColors.primary, isNot(const Color(0xFFFFF76A)));
    expect(
      FlorienPalette.light.border.computeLuminance(),
      greaterThan(FlorienPalette.light.textPrimary.computeLuminance()),
    );
    expect(FlorienPalette.light.selection, FlorienPalette.light.primaryMuted);
  });
}

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance();
  final darker = background.computeLuminance();
  final high = lighter > darker ? lighter : darker;
  final low = lighter > darker ? darker : lighter;
  return (high + .05) / (low + .05);
}
