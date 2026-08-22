import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:florien/core/theme/florien_theme.dart';

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

  static const _glassDeep = Color(0xFF0C0A14);
  static const _glassMid = Color(0xFF1A1430);
  static const _glassRimA = Color(0xFF8B7CFF);
  static const _glassRimB = Color(0xFF4F7CFF);
  static const _glassRimC = Color(0xFF6A4CFF);

  @override
  Widget build(BuildContext context) {
    final star = Semantics(
      image: true,
      label: semanticLabel,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0.28, 0.42, 0.30, 0, -0.04,
        ]),
        child: Image.asset(
          florienAiFabImageAsset,
          key: imageKey,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );

    if (!showRing) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(child: star),
      );
    }

    final ring = premium ? 2.6 : FlorienBorders.thin;
    final inset = size * 0.16;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: premium
              ? [
                  BoxShadow(
                    color: _glassRimA.withValues(alpha: 0.34),
                    blurRadius: 16,
                    spreadRadius: 0.5,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: _glassRimB.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: _glassDeep),
              if (premium)
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: const SizedBox.expand(),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      _glassRimA.withValues(alpha: premium ? 0.85 : 0.35),
                      _glassRimB.withValues(alpha: premium ? 0.7 : 0.25),
                      _glassRimC.withValues(alpha: premium ? 0.8 : 0.3),
                      _glassRimA.withValues(alpha: premium ? 0.85 : 0.35),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(ring),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.3, -0.4),
                            radius: 1.1,
                            colors: [
                              _glassRimA.withValues(alpha: 0.28),
                              _glassMid.withValues(alpha: 0.72),
                              _glassDeep,
                            ],
                            stops: const [0, 0.45, 1],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(inset),
                        child: star,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
  static const double _aiSize = 64;
  static const double _aiLift = 12;

  @override
  Widget build(BuildContext context) {
    final hasAi = onAiPressed != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          FlorienSpacing.screen,
          hasAi ? FlorienSpacing.sm + _aiLift : FlorienSpacing.sm,
          FlorienSpacing.screen,
          FlorienSpacing.md,
        ),
        child: SizedBox(
          height: _barHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(FlorienRadius.pill),
                    border: Border.all(
                      color: context.palette.border,
                      width: FlorienBorders.thin,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
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
                        if (hasAi) const SizedBox(width: _aiSize - 6),
                      ],
                    ),
                  ),
                ),
              ),
              if (hasAi)
                Positioned(
                  right: 4,
                  top: -_aiLift,
                  child: _AiNavItem(
                    key: const ValueKey('planner-ai-chat-button'),
                    size: _aiSize,
                    onTap: onAiPressed!,
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

class _AiNavItem extends StatelessWidget {
  const _AiNavItem({
    super.key,
    required this.onTap,
    required this.size,
    this.tooltip,
  });

  final VoidCallback onTap;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? 'Plan asistanı',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: FlorienAiMark(
            size: size,
            premium: true,
            imageKey: const ValueKey('florien-ai-fab-image'),
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
              color: selected ? FlorienColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(FlorienRadius.pill),
              border: selected
                  ? Border.all(
                      color: context.palette.border,
                      width: FlorienBorders.thin,
                    )
                  : null,
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
