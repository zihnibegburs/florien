import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

const premiumMonthlyProductId = 'com.florien.app.subscription.monthly';
const premiumYearlyProductId = 'com.florien.app.subscription.yearly';
const premiumProductIds = {premiumMonthlyProductId, premiumYearlyProductId};

class PremiumPurchaseService {
  PremiumPurchaseService({
    InAppPurchase? store,
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _store = store ?? InAppPurchase.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _firestore = firestore;

  final InAppPurchase _store;
  final FirebaseFunctions _functions;
  final FirebaseFirestore? _firestore;

  Stream<List<PurchaseDetails>> get purchaseStream => _store.purchaseStream;

  Future<bool> isAvailable() => _store.isAvailable();

  Future<ProductDetailsResponse> loadProducts() async {
    final response = await _store.queryProductDetails(premiumProductIds);
    debugPrint(
      '[PremiumStore] requested=${premiumProductIds.join(',')} '
      'returned=${response.productDetails.map((item) => item.id).join(',')} '
      'notFound=${response.notFoundIDs.join(',')} '
      'error=${response.error?.code ?? 'none'}',
    );
    return response;
  }

  Future<Map<String, dynamic>> loadPaywallConfig() async {
    final firestore = _firestore;
    if (firestore == null) return const {};
    final snapshot = await firestore
        .collection('appConfig')
        .doc('premiumPaywall')
        .get();
    return snapshot.data() ?? const {};
  }

  Future<void> buy(ProductDetails product) => _store.buyNonConsumable(
    purchaseParam: PurchaseParam(productDetails: product),
  );

  Future<void> restore() => _store.restorePurchases();

  Future<void> complete(PurchaseDetails purchase) =>
      _store.completePurchase(purchase);

  Future<DateTime> verify(PurchaseDetails purchase) async {
    final result = await _functions
        .httpsCallable('verifyPremiumPurchase')
        .call(<String, Object?>{
          'source': purchase.verificationData.source,
          'verificationData': purchase.verificationData.serverVerificationData,
        });
    final raw = result.data;
    if (raw is! Map || raw['premium'] != true) {
      throw StateError('Premium purchase could not be verified.');
    }
    final premiumUntil = DateTime.tryParse(
      raw['premiumUntil']?.toString() ?? '',
    );
    if (premiumUntil == null || !premiumUntil.isAfter(DateTime.now())) {
      throw StateError('Premium subscription is not active.');
    }
    return premiumUntil;
  }
}
