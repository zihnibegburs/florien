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
  });

  final double size;
  final Key? imageKey;
  final String semanticLabel;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final ringWidth = premium ? 1.8 : FlorienBorders.thin;
    final inset = premium ? 2.0 : 2.5;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: premium ? FlorienColors.aiGradient : null,
        color: premium ? null : Colors.white,
        border: premium
            ? null
            : Border.all(
                color: context.palette.border,
                width: FlorienBorders.thin,
              ),
        boxShadow: premium
            ? [
                BoxShadow(
                  color: FlorienColors.aiAccent.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                ),
                BoxShadow(
                  color: FlorienColors.paleBlue.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.all(premium ? ringWidth : 0),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: premium
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    FlorienColors.aiLavender.withValues(alpha: 0.92),
                    Colors.white,
                  ],
                )
              : null,
          color: premium ? null : Colors.white,
          border: premium
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.7),
                  width: 0.8,
                )
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(inset),
          child: ClipOval(
            child: Semantics(
              image: true,
              label: semanticLabel,
              child: Transform.scale(
                scale: premium ? 2.05 : 1.9,
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
          height: 72,
          padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
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
                  flex: 10,
                  child: _NavItem(
                    destination: destinations[i],
                    selected: selectedIndex == i,
                    onTap: () => onDestinationSelected(i),
                  ),
                ),
              if (onAiPressed != null)
                Expanded(
                  flex: 13,
                  child: _AiNavItem(
                    key: const ValueKey('planner-ai-chat-button'),
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
    this.tooltip,
  });

  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? 'Plan asistanı',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FlorienRadius.pill),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FlorienRadius.pill),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FlorienColors.paleBlue.withValues(alpha: 0.55),
                  FlorienColors.aiLavender.withValues(alpha: 0.9),
                  FlorienColors.aiAccent.withValues(alpha: 0.28),
                ],
              ),
              border: Border.all(
                color: FlorienColors.aiAccent.withValues(alpha: 0.55),
                width: FlorienBorders.thin,
              ),
              boxShadow: [
                BoxShadow(
                  color: FlorienColors.aiAccent.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FlorienAiMark(
                  size: 38,
                  premium: true,
                  imageKey: ValueKey('florien-ai-fab-image'),
                ),
                const SizedBox(height: 1),
                Text(
                  'AI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: FlorienColors.aiAccent.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w800,
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
