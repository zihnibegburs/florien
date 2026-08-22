import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/services/premium_purchase_service.dart';
import 'package:florien/core/widgets/florien_buttons.dart';
import 'package:florien/features/premium/premium_features.dart';
import 'package:florien/features/premium/premium_membership.dart';
import 'package:florien/features/premium/premium_paywall_copy.dart';
import 'package:intl/intl.dart';

class PremiumMembershipScreen extends ConsumerStatefulWidget {
  const PremiumMembershipScreen({
    super.key,
    this.onContinue,
    this.highlightedFeature,
  });

  final Future<void> Function()? onContinue;
  final PremiumFeature? highlightedFeature;

  @override
  ConsumerState<PremiumMembershipScreen> createState() =>
      _PremiumMembershipScreenState();
}

class _PremiumMembershipScreenState
    extends ConsumerState<PremiumMembershipScreen> {
  bool _showThanks = false;
  bool _sawNonPremium = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(premiumMembershipProvider.notifier).clearStuckPurchasing();
    });
  }

  Future<void> _handleContinue() async {
    final onContinue = widget.onContinue;
    if (onContinue != null) {
      await onContinue();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(premiumMembershipProvider, (previous, next) {
      final wasPremium = previous?.valueOrNull?.hasActivePremium == true;
      final isPremium = next.valueOrNull?.hasActivePremium == true;
      if (!isPremium) {
        _sawNonPremium = true;
      }
      // Only after this visit showed a non-premium state (purchase / restore).
      if (_sawNonPremium && !wasPremium && isPremium && mounted) {
        setState(() => _showThanks = true);
      }

      final previousMessage = previous?.valueOrNull?.message;
      final nextMessage = next.valueOrNull?.message;
      if (nextMessage != null &&
          nextMessage != previousMessage &&
          mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(nextMessage)));
      }
    });

    final membership = ref.watch(premiumMembershipProvider);
    final value = membership.valueOrNull;
    final isLoading = membership.isLoading || value?.isPurchasing == true;
    final strings = ref.watch(stringsProvider);
    final paywallCopy = PremiumPaywallCopy.fromConfig(
      value?.paywallConfig ?? const {},
      strings,
    );

    if (_showThanks) {
      return Scaffold(
        key: const ValueKey('premium-thanks-screen'),
        backgroundColor: context.palette.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(FlorienSpacing.screen),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(FlorienSpacing.xxl),
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(FlorienRadius.lg),
                    border: Border.all(
                      color: context.palette.border,
                      width: FlorienBorders.thin,
                    ),
                  ),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/premium/premium_thanks.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: FlorienSpacing.xl),
                      Text(
                        strings.premiumThanksTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                      ),
                      const SizedBox(height: FlorienSpacing.md),
                      Text(
                        strings.premiumThanksDescription,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.palette.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                FlorienPrimaryButton(
                  key: const ValueKey('premium-thanks-continue'),
                  label: strings.continueLabel,
                  onPressed: _handleContinue,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(strings.premiumAppBar)),
      bottomNavigationBar: widget.onContinue == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  FlorienSpacing.screen,
                  FlorienSpacing.xs,
                  FlorienSpacing.screen,
                  FlorienSpacing.sm,
                ),
                child: TextButton(
                  key: const ValueKey('paywall-continue'),
                  onPressed: () => _handleContinue(),
                  child: Text(
                    value?.hasActivePremium == true
                        ? strings.continueLabel
                        : strings.skipForNow,
                  ),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(FlorienSpacing.screen),
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(FlorienRadius.lg),
              border: Border.all(
                color: context.palette.border,
                width: FlorienBorders.thin,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 951 / 561,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/premium/premium_banner.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.72),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              FlorienSpacing.lg,
                              FlorienSpacing.xxl,
                              FlorienSpacing.lg,
                              FlorienSpacing.lg,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  value?.hasActivePremium == true
                                      ? strings.premiumActive
                                      : strings.premiumAppBar,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: FlorienSpacing.xs),
                                Text(
                                  value?.hasActivePremium == true
                                      ? strings.premiumActiveDescription
                                      : strings.premiumIntro,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.82),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (value?.message != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      FlorienSpacing.lg,
                      FlorienSpacing.md,
                      FlorienSpacing.lg,
                      FlorienSpacing.lg,
                    ),
                    child: Text(
                      value!.message!,
                      style: TextStyle(color: context.palette.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: FlorienSpacing.lg),
          Text(
            strings.florienFeatures,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: FlorienSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(FlorienRadius.lg),
              border: Border.all(
                color: context.palette.border,
                width: FlorienBorders.thin,
              ),
            ),
            child: Column(
              children: [
                _PremiumComparisonHeader(strings: strings),
                const Divider(height: 1),
                for (
                  var index = 0;
                  index < planComparisonFeatures.length;
                  index++
                ) ...[
                  _PremiumFeatureTile(
                    feature: planComparisonFeatures[index],
                    strings: strings,
                    highlighted:
                        planComparisonFeatures[index].premiumFeature ==
                        widget.highlightedFeature,
                  ),
                  if (index != planComparisonFeatures.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: FlorienSpacing.lg),
          if (value?.hasActivePremium != true && value != null) ...[
            if (value.products.isNotEmpty) ...[
              Text(
                paywallCopy.planSectionTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: FlorienSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (
                    var index = 0;
                    index < value.products.length;
                    index++
                  ) ...[
                    if (index > 0) const SizedBox(width: FlorienSpacing.sm),
                    Expanded(
                      child: _PremiumPlanTile(
                        productId: value.products[index].id,
                        title: paywallCopy.titleFor(value.products[index].id),
                        period: paywallCopy.periodFor(value.products[index].id),
                        badge: paywallCopy.badgeFor(value.products[index].id),
                        price: paywallCopy.price(value.products[index].price),
                        dailyPrice: paywallCopy.dailyPrice(
                          _localizedDailyPrice(
                            productId: value.products[index].id,
                            rawPrice: value.products[index].rawPrice,
                            currencyCode: value.products[index].currencyCode,
                            languageCode: strings.lang,
                          ),
                        ),
                        selected:
                            value.products[index].id ==
                            value.effectiveSelectedProductId,
                        onTap: () => ref
                            .read(premiumMembershipProvider.notifier)
                            .selectPlan(value.products[index].id),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: FlorienSpacing.md),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        await ref
                            .read(premiumMembershipProvider.notifier)
                            .buyPremium();
                      },
                child: Text(
                  isLoading
                      ? strings.processing
                      : paywallCopy.purchaseCta(value.selectedProduct!.price),
                ),
              ),
            ] else if (value.storeAvailable) ...[
              Text(
                paywallCopy.planSectionTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: FlorienSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final productId in const [
                    premiumMonthlyProductId,
                    premiumYearlyProductId,
                  ]) ...[
                    if (productId == premiumYearlyProductId)
                      const SizedBox(width: FlorienSpacing.sm),
                    Expanded(
                      child: _PremiumPlanTile(
                        productId: productId,
                        title: paywallCopy.titleFor(productId),
                        period: paywallCopy.periodFor(productId),
                        badge: paywallCopy.badgeFor(productId),
                        price: '—',
                        dailyPrice: strings.storePricePending,
                        selected: false,
                        onTap: isLoading
                            ? null
                            : () => ref
                                  .read(premiumMembershipProvider.notifier)
                                  .reloadProducts(),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: FlorienSpacing.md),
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
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: context.palette.textSecondary,
                    ),
                    const SizedBox(height: FlorienSpacing.sm),
                    Text(
                      strings.premiumProductsTemporarilyUnavailable,
                      textAlign: TextAlign.center,
                    ),
                    if (value.storeDiagnostics != null) ...[
                      const SizedBox(height: FlorienSpacing.sm),
                      Text(
                        value.storeDiagnostics!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: FlorienSpacing.sm),
                    TextButton.icon(
                      key: const ValueKey('retry-premium-products'),
                      onPressed: isLoading
                          ? null
                          : () => ref
                                .read(premiumMembershipProvider.notifier)
                                .reloadProducts(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(strings.retryStoreProducts),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: FlorienSpacing.sm),
          TextButton(
            onPressed: isLoading || value?.storeAvailable != true
                ? null
                : () => ref
                      .read(premiumMembershipProvider.notifier)
                      .restorePurchases(),
            child: Text(strings.restorePurchases),
          ),
        ],
      ),
    );
  }
}

class _PremiumComparisonHeader extends StatelessWidget {
  const _PremiumComparisonHeader({required this.strings});

  final S strings;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            strings.feature,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          width: 72,
          child: Text(
            strings.standard,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          width: 72,
          child: Text(
            strings.premium,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _PremiumFeatureTile extends StatelessWidget {
  const _PremiumFeatureTile({
    required this.feature,
    required this.highlighted,
    required this.strings,
  });

  final PlanComparisonFeature feature;
  final bool highlighted;
  final S strings;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: highlighted ? context.palette.primaryMuted : Colors.transparent,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Icon(feature.icon, color: context.palette.textPrimary, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              feature.titleFor(strings),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 72,
            child: Icon(
              feature.includedInStandard
                  ? Icons.check_circle_rounded
                  : Icons.close_rounded,
              key: ValueKey('standard-${feature.id}'),
              color: feature.includedInStandard
                  ? FlorienColors.success
                  : context.palette.textSecondary,
              size: 21,
            ),
          ),
          SizedBox(
            width: 72,
            child: Icon(
              Icons.check_circle_rounded,
              key: ValueKey('premium-${feature.id}'),
              color: FlorienColors.success,
              size: 21,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PremiumPlanTile extends StatelessWidget {
  const _PremiumPlanTile({
    required this.productId,
    required this.title,
    required this.period,
    required this.badge,
    required this.price,
    required this.dailyPrice,
    required this.selected,
    required this.onTap,
  });

  final String productId;
  final String title;
  final String period;
  final String badge;
  final String price;
  final String dailyPrice;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final yearly = productId == premiumYearlyProductId;
    final accent = yearly ? FlorienColors.primary : FlorienColors.accent;
    final background = Color.alphaBlend(
      accent.withValues(alpha: selected ? .52 : .22),
      context.palette.surface,
    );

    return InkWell(
      key: ValueKey('premium-plan-$productId'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(FlorienRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(FlorienSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(FlorienRadius.md),
          border: Border.all(
            color: selected ? context.palette.textPrimary : accent,
            width: selected ? 2 : FlorienBorders.thin,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: .3),
                    blurRadius: 0,
                    offset: const Offset(3, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 21,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FlorienSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.palette.surface.withValues(alpha: .7),
                borderRadius: BorderRadius.circular(FlorienRadius.pill),
              ),
              child: Text(
                badge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: FlorienSpacing.sm),
            Text(
              price,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              dailyPrice,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.palette.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              period,
              maxLines: 2,
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 12,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _localizedDailyPrice({
  required String productId,
  required double rawPrice,
  required String currencyCode,
  required String languageCode,
}) {
  final days = productId == premiumYearlyProductId ? 365 : 30;
  return NumberFormat.simpleCurrency(
    locale: languageCode,
    name: currencyCode,
  ).format(rawPrice / days);
}
