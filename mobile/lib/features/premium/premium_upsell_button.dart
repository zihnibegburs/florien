import 'package:florien/core/theme/florien_theme.dart';
import 'package:flutter/material.dart';

class PremiumUpsellButton extends StatelessWidget {
  const PremiumUpsellButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Material(
      color: FlorienColors.primary,
      borderRadius: BorderRadius.circular(FlorienRadius.sm),
      child: InkWell(
        key: const ValueKey('premium-upsell-button'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(FlorienRadius.sm),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FlorienRadius.sm),
            border: Border.all(
              color: context.palette.border,
              width: FlorienBorders.thin,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                size: 17,
                color: FlorienColors.onPrimary,
              ),
              SizedBox(width: 5),
              Text(
                'Premium ol',
                style: TextStyle(
                  color: FlorienColors.onPrimary,
                  fontSize: 12,
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
