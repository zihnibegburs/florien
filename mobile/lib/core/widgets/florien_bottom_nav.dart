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

  @override
  Widget build(BuildContext context) {
    final dark = context.isFlorienDark;
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

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: premium
              ? [
                  BoxShadow(
                    color: FlorienColors.aiAccent.withValues(
                      alpha: dark ? 0.38 : 0.24,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: FlorienColors.paleBlue.withValues(
                      alpha: dark ? 0.22 : 0.34,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      FlorienColors.paleBlue.withValues(
                        alpha: dark ? 0.62 : 0.86,
                      ),
                      FlorienColors.aiLavender.withValues(
                        alpha: dark ? 0.7 : 0.92,
                      ),
                      FlorienColors.aiAccent.withValues(
                        alpha: dark ? 0.42 : 0.38,
                      ),
                    ],
                    stops: const [0, 0.48, 1],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(
                      color: Color.lerp(
                        FlorienColors.paleBlue,
                        FlorienColors.aiAccent,
                        dark ? 0.45 : 0.28,
                      )!.withValues(alpha: 0.82),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              const IgnorePointer(
                child: Align(
                  alignment: Alignment(-0.52, -0.7),
                  child: FractionallySizedBox(
                    widthFactor: 0.48,
                    heightFactor: 0.2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(99)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x99FFFFFF),
                            Color(0x00FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(size * 0.11),
                child: star,
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
  static const double _aiSize = 52;

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
              _SpecialNavButton(
                size: _aiSize,
                onTap: onAiPressed,
                tooltip: aiTooltip,
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
  const _SpecialNavButton({
    this.size = 58,
    this.onTap,
    this.tooltip,
  });

  final double size;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? 'Plan asistanı',
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
