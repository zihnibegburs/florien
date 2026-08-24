import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/l10n/app_strings.dart';

const florienAiFabImageAsset = 'assets/ai/florien_ai_glass_star.png';

class FlorienAiMark extends StatelessWidget {
  const FlorienAiMark({
    super.key,
    this.size = 58,
    this.imageKey,
    this.semanticLabel = 'Florien AI asistanı',
    this.premium = false,
    this.showRing = true,
  });

  final double size;
  final Key? imageKey;
  final String semanticLabel;
  final bool premium;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    final dark = context.isFlorienDark;
    final sparkle = Semantics(
      image: true,
      label: ActiveLanguage.s(semanticLabel),
      child: CustomPaint(
        key: imageKey,
        size: Size.square(size),
        painter: _FlorienSparklePainter(
          color: dark ? const Color(0xFFF7F4FF) : const Color(0xFF3D2A6E),
        ),
      ),
    );

    if (!showRing) {
      return SizedBox(width: size, height: size, child: sparkle);
    }

    final fill = dark
        ? const [
            Color(0xFF4A3F6B),
            Color(0xFF6B5B95),
            Color(0xFF8B7BC8),
          ]
        : const [
            Color(0xFFF4F0FF),
            Color(0xFFE4D9FF),
            Color(0xFFD4ECFF),
          ];
    final rim = dark
        ? FlorienColors.accent.withValues(alpha: 0.45)
        : const Color(0xFFC9B8F2);
    final glow = FlorienColors.accent.withValues(alpha: dark ? 0.34 : 0.22);

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: glow,
              blurRadius: premium ? 16 : 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: fill,
            ),
            border: Border.all(color: rim, width: FlorienBorders.thin),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.45),
                    radius: 0.9,
                    colors: [
                      Colors.white.withValues(alpha: dark ? 0.16 : 0.72),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(size * 0.26),
                child: sparkle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlorienSparklePainter extends CustomPainter {
  const _FlorienSparklePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.drawPath(_sparklePath(size.shortestSide * 0.52), paint);
    canvas.restore();
  }

  Path _sparklePath(double radius) {
    const points = 4;
    final inner = radius * 0.32;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : inner;
      final angle = -math.pi / 2 + (i * math.pi / points);
      final x = math.cos(angle) * r;
      final y = math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _FlorienSparklePainter oldDelegate) =>
      oldDelegate.color != color;
}

class FlorienBottomNavigation extends StatelessWidget {
  const FlorienBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.onAiPressed,
    this.aiTooltip,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<FlorienNavDestination> destinations;
  final VoidCallback? onAiPressed;
  final String? aiTooltip;

  static const double _barHeight = 68;
  static const double _aiSize = 48;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          FlorienSpacing.screen,
          FlorienSpacing.sm,
          FlorienSpacing.screen,
          FlorienSpacing.md,
        ),
        child: Container(
          height: _barHeight,
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(FlorienRadius.pill),
            border: Border.all(
              color: context.palette.border,
              width: FlorienBorders.thin,
            ),
          ),
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    selected: selectedIndex == i,
                    onTap: () => onDestinationSelected(i),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4),
                child: _SpecialNavButton(
                  size: _aiSize,
                  onTap: onAiPressed,
                  tooltip: aiTooltip,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FlorienNavDestination {
  const FlorienNavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _SpecialNavButton extends StatelessWidget {
  const _SpecialNavButton({this.size = 58, this.onTap, this.tooltip});

  final double size;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? context.l10n('Plan asistanı'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('planner-ai-chat-button'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: FlorienAiMark(
            size: size,
            imageKey: const ValueKey('florien-nav-special-image'),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final FlorienNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FlorienRadius.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected ? context.palette.selection : Colors.transparent,
              borderRadius: BorderRadius.circular(FlorienRadius.pill),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 20,
                  color: selected
                      ? FlorienColors.onPrimary
                      : context.palette.textPrimary.withValues(alpha: 0.55),
                ),
                const SizedBox(height: 2),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: selected
                        ? FlorienColors.onPrimary
                        : context.palette.textPrimary.withValues(alpha: 0.55),
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FlorienAiFab extends StatelessWidget {
  const FlorienAiFab({super.key, required this.onPressed, this.tooltip});

  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? 'AI',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: const FlorienAiMark(
            premium: true,
            imageKey: ValueKey('florien-ai-fab-image'),
          ),
        ),
      ),
    );
  }
}
