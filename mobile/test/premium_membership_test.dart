import 'package:florien/features/premium/premium_membership.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hasActivePremium prefers a future premiumUntil', () {
    final membership = PremiumMembership(
      storeAvailable: true,
      isPremium: false,
      premiumUntil: DateTime.now().add(const Duration(days: 3)),
    );
    expect(membership.hasActivePremium, isTrue);
  });

  test('hasActivePremium is false when premiumUntil expired', () {
    final membership = PremiumMembership(
      storeAvailable: true,
      isPremium: true,
      premiumUntil: DateTime.now().subtract(const Duration(hours: 1)),
    );
    expect(membership.hasActivePremium, isFalse);
  });

  test('hasActivePremium falls back to isPremium without until', () {
    const active = PremiumMembership(storeAvailable: true, isPremium: true);
    const inactive = PremiumMembership(storeAvailable: true, isPremium: false);
    expect(active.hasActivePremium, isTrue);
    expect(inactive.hasActivePremium, isFalse);
  });
}
