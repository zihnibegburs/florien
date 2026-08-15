import 'package:flutter/material.dart';
import 'package:florien/core/theme/florien_theme.dart';

class FlorienPrimaryButton extends StatefulWidget {
  const FlorienPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool isLoading;

  @override
  State<FlorienPrimaryButton> createState() => _FlorienPrimaryButtonState();
}

class _FlorienPrimaryButtonState extends State<FlorienPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    final child = AnimatedScale(
      scale: _pressed && enabled ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      child: SizedBox(
        width: widget.expand ? double.infinity : null,
        height: 54,
        child: FilledButton(
          onPressed: enabled
              ? () {
                  widget.onPressed?.call();
                }
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: FlorienColors.primary,
            foregroundColor: FlorienColors.onPrimary,
            disabledBackgroundColor: context.palette.surfaceMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FlorienRadius.pill),
              side: BorderSide(
                color: context.palette.border,
                width: FlorienBorders.thin,
              ),
            ),
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: FlorienColors.onPrimary,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.label),
                    if (widget.icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(widget.icon, size: 18),
                    ],
                  ],
                ),
        ),
      ),
    );

    return Listener(
      onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onPointerUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onPointerCancel: enabled ? (_) => setState(() => _pressed = false) : null,
      child: child,
    );
  }
}

class FlorienSecondaryButton extends StatelessWidget {
  const FlorienSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expand ? double.infinity : null,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 22),
              const SizedBox(width: 8),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}

class FlorienIconButton extends StatelessWidget {
  const FlorienIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.filled = false,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: filled
            ? FlorienColors.primary
            : context.palette.surface,
        foregroundColor: filled
            ? FlorienColors.onPrimary
            : context.palette.textPrimary,
        minimumSize: Size(size, size),
        maximumSize: Size(size, size),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.pill),
          side: BorderSide(
            color: context.palette.border,
            width: FlorienBorders.thin,
          ),
        ),
      ),
      icon: Icon(icon, size: size * 0.42),
    );
    return button;
  }
}
