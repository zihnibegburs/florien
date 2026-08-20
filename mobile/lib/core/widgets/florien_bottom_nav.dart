import 'package:flutter/material.dart';
import 'package:florien/core/theme/florien_theme.dart';

const florienAiFabImageAsset = 'assets/ai/florien_ai_glass_star.png';

class FlorienAiMark extends StatelessWidget {
  const FlorienAiMark({
    super.key,
    this.size = 58,
    this.imageKey,
    this.semanticLabel = 'Florien AI asistanı',
  });

  final double size;
  final Key? imageKey;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Ink(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: context.palette.border,
          width: FlorienBorders.thin,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: ClipOval(
          child: Semantics(
            image: true,
            label: semanticLabel,
            child: Transform.scale(
              scale: 1.9,
              child: Image.asset(
                florienAiFabImageAsset,
                key: imageKey,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
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
    this.trailing,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<FlorienNavDestination> destinations;
  final Widget? trailing;

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
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 68,
                padding: const EdgeInsets.symmetric(horizontal: 6),
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
                  ],
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: FlorienSpacing.md),
              trailing!,
            ],
          ],
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
            imageKey: ValueKey('florien-ai-fab-image'),
          ),
        ),
      ),
    );
  }
}
