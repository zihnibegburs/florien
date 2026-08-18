import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/services/premium_purchase_service.dart';
import 'package:florien/features/premium/premium_membership.dart';

class PremiumMembershipScreen extends ConsumerWidget {
  const PremiumMembershipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(premiumMembershipProvider);
    final value = membership.valueOrNull;
    final isLoading = membership.isLoading || value?.isPurchasing == true;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: const Text('Florien Premium')),
      body: ListView(
        padding: const EdgeInsets.all(FlorienSpacing.screen),
        children: [
          Container(
            padding: const EdgeInsets.all(FlorienSpacing.lg),
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(FlorienRadius.lg),
              border: Border.all(
                color: context.palette.border,
                width: FlorienBorders.thin,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  value?.isPremium == true
                      ? Icons.workspace_premium_rounded
                      : Icons.auto_awesome_rounded,
                  color: context.palette.textPrimary,
                  size: 34,
                ),
                const SizedBox(height: FlorienSpacing.md),
                Text(
                  value?.isPremium == true
                      ? 'Premium aktif'
                      : 'Florien Premium',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: FlorienSpacing.xs),
                Text(
                  value?.isPremium == true
                      ? 'Hesabın Premium olarak etkinleştirildi.'
                      : 'Premium üyeliğin hazır olduğunda buradan etkinleştirilebilir.',
                  style: TextStyle(color: context.palette.textSecondary),
                ),
                if (value?.message != null) ...[
                  const SizedBox(height: FlorienSpacing.md),
                  Text(
                    value!.message!,
                    style: TextStyle(color: context.palette.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: FlorienSpacing.lg),
          if (value?.isPremium != true && value != null) ...[
            for (final product in value.products)
              _PremiumPlanTile(
                productId: product.id,
                price: product.price,
                selected: product.id == value.selectedProductId,
                onTap: () => ref
                    .read(premiumMembershipProvider.notifier)
                    .selectPlan(product.id),
              ),
            const SizedBox(height: FlorienSpacing.md),
            FilledButton(
              onPressed: isLoading || value.selectedProduct == null
                  ? null
                  : () => ref
                        .read(premiumMembershipProvider.notifier)
                        .buyPremium(),
              child: Text(
                isLoading
                    ? 'İşleniyor...'
                    : value.selectedProduct == null
                    ? 'Premium yakında'
                    : '${value.selectedProduct!.price} karşılığında Premium ol',
              ),
            ),
          ],
          const SizedBox(height: FlorienSpacing.sm),
          TextButton(
            onPressed: isLoading || value?.storeAvailable != true
                ? null
                : () => ref
                      .read(premiumMembershipProvider.notifier)
                      .restorePurchases(),
            child: const Text('Satın alımları geri yükle'),
          ),
        ],
      ),
    );
  }
}

class _PremiumPlanTile extends StatelessWidget {
  const _PremiumPlanTile({
    required this.productId,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final String productId;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(FlorienRadius.md),
    child: Container(
      margin: const EdgeInsets.only(bottom: FlorienSpacing.sm),
      padding: const EdgeInsets.all(FlorienSpacing.md),
      decoration: BoxDecoration(
        color: selected ? FlorienColors.primary : context.palette.surface,
        borderRadius: BorderRadius.circular(FlorienRadius.md),
        border: Border.all(
          color: context.palette.border,
          width: FlorienBorders.thin,
        ),
      ),
      child: Row(
        children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
          const SizedBox(width: FlorienSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  premiumPlanTitle(productId),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  premiumPlanPeriod(productId),
                  style: TextStyle(color: context.palette.textSecondary),
                ),
              ],
            ),
          ),
          Text(price, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );
}
