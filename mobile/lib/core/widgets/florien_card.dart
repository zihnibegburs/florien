import 'package:flutter/material.dart';
import 'package:florien/core/theme/florien_theme.dart';

class FlorienCard extends StatelessWidget {
  const FlorienCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(FlorienSpacing.xxl),
      decoration: BoxDecoration(
        color: color ?? context.palette.surface,
        borderRadius: BorderRadius.circular(FlorienRadius.lg),
        border: Border.all(
          color: borderColor ?? context.palette.border,
          width: FlorienBorders.thin,
        ),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FlorienRadius.lg),
        child: card,
      ),
    );
  }
}

/// Single outlined group for stacked settings or picker rows.
class FlorienGroupedPanel extends StatelessWidget {
  const FlorienGroupedPanel({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.background,
        borderRadius: BorderRadius.circular(FlorienRadius.lg),
        border: Border.all(
          color: context.palette.border,
          width: FlorienBorders.thin,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FlorienRadius.lg - 1),
        child: Padding(
          padding: padding,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: context.palette.border.withValues(alpha: 0.12),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FlorienSectionHeader extends StatelessWidget {
  const FlorienSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: FlorienSpacing.md),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class FlorienEmptyState extends StatelessWidget {
  const FlorienEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FlorienSpacing.xxxl),
        child: FlorienCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.palette.selection,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.palette.border,
                    width: FlorienBorders.thin,
                  ),
                ),
                child: Icon(icon, color: FlorienColors.onPrimary),
              ),
              const SizedBox(height: FlorienSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (message != null) ...[
                const SizedBox(height: FlorienSpacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: FlorienSpacing.xxl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft accent card used for task rows and similar list items.
class FlorienTaskCard extends StatelessWidget {
  const FlorienTaskCard({
    super.key,
    required this.child,
    this.accent,
    this.padding,
    this.margin,
    this.onTap,
    this.completed = false,
  });

  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? context.palette.selection;
    final card = Container(
      margin: margin ?? const EdgeInsets.only(bottom: FlorienSpacing.md),
      padding: padding ?? const EdgeInsets.all(FlorienSpacing.lg),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          tint.withValues(alpha: completed ? 0.04 : 0.10),
          context.palette.surface,
        ),
        borderRadius: BorderRadius.circular(FlorienRadius.lg),
        border: Border.all(
          color: context.palette.border,
          width: FlorienBorders.thin,
        ),
      ),
      child: Opacity(opacity: completed ? 0.58 : 1, child: child),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FlorienRadius.lg),
        child: card,
      ),
    );
  }
}

/// Collapsible pastel banner used on task create/edit forms.
class FlorienFormSectionHeader extends StatelessWidget {
  const FlorienFormSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.trailing,
    this.expanded,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget? trailing;
  final bool? expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fill = context.pastelFill(color);
    final radius = BorderRadius.circular(FlorienRadius.md);
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: palette.border, width: FlorienBorders.thin),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21, color: palette.textPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          if (trailing case final trailing?)
            IconButtonTheme(
              data: IconButtonThemeData(
                style: IconButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(40, 40),
                  padding: const EdgeInsets.all(8),
                  side: BorderSide.none,
                  foregroundColor: palette.textPrimary,
                  shape: const CircleBorder(),
                ),
              ),
              child: trailing,
            ),
          if (expanded case final expanded?)
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: palette.textPrimary,
            ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(onTap: onTap, borderRadius: radius, child: content),
    );
  }
}
