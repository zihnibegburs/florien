import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/features/premium/premium_paywall_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses localized Firestore copy and preserves the store price', () {
    final copy = PremiumPaywallCopy.fromConfig({
      'localizations': {
        'tr': {
          'planSectionTitle': 'Sana uygun plan',
          'monthlyTitle': 'Her ay',
          'monthlyPeriod': 'İstediğin zaman değiştirebilirsin',
          'monthlyBadge': 'Esnek seçim',
          'priceTemplate': 'Şimdi {price}',
          'dailyPriceTemplate': 'Her gün sadece {price}',
          'purchaseCtaTemplate': '{price} ile hemen başla',
        },
      },
    }, const S('tr'));

    expect(copy.planSectionTitle, 'Sana uygun plan');
    expect(copy.monthlyTitle, 'Her ay');
    expect(copy.price('₺99,99'), 'Şimdi ₺99,99');
    expect(copy.dailyPrice('₺3,33'), 'Her gün sadece ₺3,33');
    expect(copy.purchaseCta('₺99,99'), '₺99,99 ile hemen başla');
  });

  test('falls back in the active language when localization is missing', () {
    final copy = PremiumPaywallCopy.fromConfig({
      'localizations': {
        'tr': {'monthlyTitle': 'Her ay'},
      },
    }, const S('en'));

    expect(copy.planSectionTitle, 'Choose your plan');
    expect(copy.monthlyTitle, 'Monthly');
    expect(copy.yearlyBadge, 'Best value');
  });

  test('rejects a remote price template without the store price token', () {
    final copy = PremiumPaywallCopy.fromConfig({
      'localizations': {
        'tr': {
          'priceTemplate': 'Sadece 1 TL',
          'dailyPriceTemplate': 'Günlük çok uygun',
          'purchaseCtaTemplate': 'Hemen satın al',
        },
      },
    }, const S('tr'));

    expect(copy.price('₺99,99'), '₺99,99');
    expect(copy.dailyPrice('₺3,33'), 'Günde yaklaşık ₺3,33');
    expect(copy.purchaseCta('₺99,99'), '₺99,99 karşılığında Premium ol');
  });
}
