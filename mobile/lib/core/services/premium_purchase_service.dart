import 'package:in_app_purchase/in_app_purchase.dart';

const premiumMonthlyProductId = 'com.florien.app.subscription.monthly';
const premiumYearlyProductId = 'com.florien.app.subscription.yearly';
const premiumProductIds = {premiumMonthlyProductId, premiumYearlyProductId};

String premiumPlanTitle(String productId) =>
    productId == premiumYearlyProductId ? 'Yıllık' : 'Aylık';

String premiumPlanPeriod(String productId) =>
    productId == premiumYearlyProductId
    ? 'Yılda bir yenilenir'
    : 'Her ay yenilenir';

class PremiumPurchaseService {
  PremiumPurchaseService({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;

  final InAppPurchase _store;

  Stream<List<PurchaseDetails>> get purchaseStream => _store.purchaseStream;

  Future<bool> isAvailable() => _store.isAvailable();

  Future<ProductDetailsResponse> loadProducts() =>
      _store.queryProductDetails(premiumProductIds);

  Future<void> buy(ProductDetails product) => _store.buyNonConsumable(
    purchaseParam: PurchaseParam(productDetails: product),
  );

  Future<void> restore() => _store.restorePurchases();

  Future<void> complete(PurchaseDetails purchase) =>
      _store.completePurchase(purchase);
}
