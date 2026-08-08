import 'package:flutter/material.dart';
import 'package:mimio/core/theme/mimio_theme.dart';
import 'package:mimio/core/widgets/liquid_glass.dart';

class ModernNavItem {
  const ModernNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Bottom bar with a **fixed-width** add slot so tabs never shift when
/// the add button appears/disappears.
class ModernBottomBar extends StatelessWidget {
  const ModernBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    this.onAdd,
    this.addTooltip,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<ModernNavItem> items;
  final VoidCallback? onAdd;
  final String? addTooltip;

  static const double _addSlot = 54;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      borderRadius: BorderRadius.circular(24),
      blur: false,
      tintOpacity: 1,
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _NavButton(
                item: items[i],
                selected: selectedIndex == i,
                onTap: () => onSelected(i),
              ),
            ),
          // Fixed slot: always same width → no layout jump.
          SizedBox(
            width: _addSlot,
            height: 52,
            child: Center(
              child: AnimatedOpacity(
                opacity: onAdd != null ? 1 : 0,
                duration:
                    (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: IgnorePointer(
                  ignoring: onAdd == null,
                  child: _AddButton(onTap: onAdd ?? () {}, tooltip: addTooltip),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap, this.tooltip});

  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Ink(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: MimioColors.primary,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ModernNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 21,
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : context.palette.textSecondary,
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : context.palette.textSecondary,
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
