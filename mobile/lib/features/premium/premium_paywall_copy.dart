import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/services/premium_purchase_service.dart';

/// Localized, remotely overridable copy for the plan selection area.
///
/// Firestore path: `appConfig/premiumPaywall`
/// Shape: `{ "localizations": { "tr": { ... }, "en": { ... } } }`.
class PremiumPaywallCopy {
  const PremiumPaywallCopy({
    required this.planSectionTitle,
    required this.monthlyTitle,
    required this.monthlyPeriod,
    required this.monthlyBadge,
    required this.yearlyTitle,
    required this.yearlyPeriod,
    required this.yearlyBadge,
    required this.priceTemplate,
    required this.dailyPriceTemplate,
    required this.purchaseCtaTemplate,
  });

  factory PremiumPaywallCopy.defaults(S strings) => PremiumPaywallCopy(
    planSectionTitle: strings.choosePlan,
    monthlyTitle: strings.monthly,
    monthlyPeriod: strings.monthlyPeriod,
    monthlyBadge: strings.monthlyBadge,
    yearlyTitle: strings.yearly,
    yearlyPeriod: strings.yearlyPeriod,
    yearlyBadge: strings.yearlyBadge,
    priceTemplate: '{price}',
    dailyPriceTemplate: strings.premiumDailyPrice('{price}'),
    purchaseCtaTemplate: strings.premiumPurchaseCta('{price}'),
  );

  factory PremiumPaywallCopy.fromConfig(
    Map<String, dynamic> config,
    S strings,
  ) {
    final defaults = PremiumPaywallCopy.defaults(strings);
    final localizations = _stringMap(config['localizations']);
    final localized = _stringMap(localizations[strings.lang]);

    return PremiumPaywallCopy(
      planSectionTitle: _copy(
        localized,
        'planSectionTitle',
        defaults.planSectionTitle,
      ),
      monthlyTitle: _copy(localized, 'monthlyTitle', defaults.monthlyTitle),
      monthlyPeriod: _copy(localized, 'monthlyPeriod', defaults.monthlyPeriod),
      monthlyBadge: _copy(localized, 'monthlyBadge', defaults.monthlyBadge),
      yearlyTitle: _copy(localized, 'yearlyTitle', defaults.yearlyTitle),
      yearlyPeriod: _copy(localized, 'yearlyPeriod', defaults.yearlyPeriod),
      yearlyBadge: _copy(localized, 'yearlyBadge', defaults.yearlyBadge),
      priceTemplate: _template(
        localized,
        'priceTemplate',
        defaults.priceTemplate,
      ),
      dailyPriceTemplate: _template(
        localized,
        'dailyPriceTemplate',
        defaults.dailyPriceTemplate,
      ),
      purchaseCtaTemplate: _template(
        localized,
        'purchaseCtaTemplate',
        defaults.purchaseCtaTemplate,
      ),
    );
  }

  final String planSectionTitle;
  final String monthlyTitle;
  final String monthlyPeriod;
  final String monthlyBadge;
  final String yearlyTitle;
  final String yearlyPeriod;
  final String yearlyBadge;
  final String priceTemplate;
  final String dailyPriceTemplate;
  final String purchaseCtaTemplate;

  String titleFor(String productId) =>
      productId == premiumYearlyProductId ? yearlyTitle : monthlyTitle;

  String periodFor(String productId) =>
      productId == premiumYearlyProductId ? yearlyPeriod : monthlyPeriod;

  String badgeFor(String productId) =>
      productId == premiumYearlyProductId ? yearlyBadge : monthlyBadge;

  String price(String storePrice) =>
      priceTemplate.replaceAll('{price}', storePrice);

  String dailyPrice(String localizedDailyPrice) =>
      dailyPriceTemplate.replaceAll('{price}', localizedDailyPrice);

  String purchaseCta(String storePrice) =>
      purchaseCtaTemplate.replaceAll('{price}', storePrice);

  static Map<String, dynamic> _stringMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static String _copy(
    Map<String, dynamic> localized,
    String key,
    String fallback,
  ) {
    final value = localized[key];
    if (value is! String) return fallback;
    final trimmed = value.trim();
    return trimmed.isEmpty || trimmed.length > 120 ? fallback : trimmed;
  }

  static String _template(
    Map<String, dynamic> localized,
    String key,
    String fallback,
  ) {
    final value = _copy(localized, key, fallback);
    return value.contains('{price}') ? value : fallback;
  }
}
