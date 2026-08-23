import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:florien/core/services/planner_ai_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

const premiumMonthlyProductId = 'com.florien.app.subscription.monthly';
const premiumYearlyProductId = 'com.florien.app.subscription.yearly';
const premiumProductIds = {premiumMonthlyProductId, premiumYearlyProductId};

class PremiumEntitlement {
  const PremiumEntitlement({
    required this.isPremium,
    this.premiumUntil,
    this.aiChatUsage,
  });

  const PremiumEntitlement.none() : this(isPremium: false);

  final bool isPremium;
  final DateTime? premiumUntil;
  final AiChatUsage? aiChatUsage;
}

class PremiumStoreQueryResult {
  const PremiumStoreQueryResult({
    required this.products,
    required this.notFoundIds,
    this.errorCode,
    this.errorMessage,
  });

  final List<ProductDetails> products;
  final List<String> notFoundIds;
  final String? errorCode;
  final String? errorMessage;

  String get diagnostics {
    final parts = <String>[
      'found=${products.map((p) => p.id).join(',')}',
      'notFound=${notFoundIds.join(',')}',
      if (errorCode != null) 'error=$errorCode',
      if (errorMessage != null) 'msg=$errorMessage',
    ];
    return parts.join(' · ');
  }
}

class PremiumBuyResult {
  const PremiumBuyResult({
    required this.started,
    this.cancelled = false,
    this.errorCode,
    this.errorMessage,
    this.entitledUntil,
  });

  final bool started;
  final bool cancelled;
  final String? errorCode;
  final String? errorMessage;
  final DateTime? entitledUntil;

  String get diagnostics {
    final parts = <String>[
      'started=$started',
      if (cancelled) 'cancelled=true',
      if (entitledUntil != null) 'until=$entitledUntil',
      if (errorCode != null) 'code=$errorCode',
      if (errorMessage != null) 'msg=$errorMessage',
    ];
    return parts.join(' · ');
  }
}

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
  bool _iosPrepared = false;

  Stream<List<PurchaseDetails>> get purchaseStream => _store.purchaseStream;

  Future<void> prepareStore() async {
    if (_iosPrepared || kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      _iosPrepared = true;
      return;
    }
    try {
      final ios = _store
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await ios.setDelegate(_FlorienPaymentQueueDelegate());
      _iosPrepared = true;
      debugPrint('[PremiumStore] iOS payment queue delegate ready');
    } catch (error) {
      debugPrint('[PremiumStore] iOS prepare failed: $error');
    }
  }

  Future<bool> isAvailable() async {
    await prepareStore();
    return _store.isAvailable();
  }

  Future<PremiumStoreQueryResult> queryProducts() async {
    await prepareStore();
    final response = await _store.queryProductDetails(premiumProductIds);
    final result = PremiumStoreQueryResult(
      products: response.productDetails,
      notFoundIds: response.notFoundIDs,
      errorCode: response.error?.code,
      errorMessage: response.error?.message,
    );
    debugPrint('[PremiumStore] ${result.diagnostics}');
    return result;
  }

  /// Kept for callers that only need the product list.
  Future<ProductDetailsResponse> loadProducts() async {
    await prepareStore();
    return _store.queryProductDetails(premiumProductIds);
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

  Future<PremiumEntitlement> fetchEntitlement() async {
    try {
      final result = await _functions
          .httpsCallable('getPremiumStatus')
          .call()
          .timeout(const Duration(seconds: 8));
      final raw = result.data;
      if (raw is! Map) return const PremiumEntitlement.none();
      final premiumUntil = DateTime.tryParse(
        raw['premiumUntil']?.toString() ?? '',
      );
      final isPremium =
          raw['premium'] == true &&
          premiumUntil != null &&
          premiumUntil.isAfter(DateTime.now());
      return PremiumEntitlement(
        isPremium: isPremium,
        premiumUntil: isPremium ? premiumUntil : null,
        aiChatUsage: AiChatUsage.fromJson(raw['aiChat']),
      );
    } catch (error) {
      debugPrint('Premium entitlement fetch failed: $error');
      return const PremiumEntitlement.none();
    }
  }

  /// Clears unfinished StoreKit transactions that block a new buy sheet.
  /// Optionally verifies premium unfinished txs before finishing them.
  Future<DateTime?> resolveUnfinishedPurchases({String? productId}) async {
    await prepareStore();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;

    DateTime? bestUntil;
    if (InAppPurchaseStoreKitPlatform.isStoreKit2Enabled) {
      final unfinished = await SK2Transaction.unfinishedTransactions();
      debugPrint(
        '[PremiumStore] unfinished=${unfinished.map((t) => '${t.productId}:${t.id}').join(',')}',
      );
      for (final tx in unfinished) {
        if (!premiumProductIds.contains(tx.productId)) continue;
        if (productId != null && tx.productId != productId) continue;
        final receipt = tx.receiptData;
        if (receipt != null && receipt.isNotEmpty) {
          try {
            final until = await verifyRaw(
              source: 'app_store',
              verificationData: receipt,
            );
            if (bestUntil == null || until.isAfter(bestUntil)) {
              bestUntil = until;
            }
          } catch (error) {
            debugPrint(
              '[PremiumStore] unfinished verify failed id=${tx.id}: $error',
            );
          }
        }
        final id = int.tryParse(tx.id);
        if (id != null) {
          await SK2Transaction.finish(id);
          debugPrint('[PremiumStore] finished unfinished tx id=${tx.id}');
        }
      }
      return bestUntil;
    }

    final queue = SKPaymentQueueWrapper();
    final pending = await queue.transactions();
    for (final tx in pending) {
      final id = tx.payment.productIdentifier;
      if (!premiumProductIds.contains(id)) continue;
      if (productId != null && id != productId) continue;
      if (tx.transactionState == SKPaymentTransactionStateWrapper.purchasing) {
        continue;
      }
      await queue.finishTransaction(tx);
      debugPrint(
        '[PremiumStore] finished SK1 tx product=$id state=${tx.transactionState}',
      );
    }
    return bestUntil;
  }

  Future<PremiumBuyResult> buy(ProductDetails product) async {
    await prepareStore();
    debugPrint(
      '[PremiumStore] buy start id=${product.id} price=${product.price}',
    );

    // Pending unfinished txs make StoreKit refuse a new purchase.
    final grantedUntil = await resolveUnfinishedPurchases(
      productId: product.id,
    );
    if (grantedUntil != null) {
      debugPrint(
        '[PremiumStore] unfinished purchase already entitled until=$grantedUntil',
      );
      return PremiumBuyResult(started: false, entitledUntil: grantedUntil);
    }

    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      debugPrint('[PremiumStore] buy started=$started');
      return PremiumBuyResult(started: started);
    } on PlatformException catch (error) {
      debugPrint(
        '[PremiumStore] buy PlatformException code=${error.code} msg=${error.message}',
      );
      if (error.code == 'storekit2_purchase_cancelled' ||
          error.code == 'purchase_cancelled') {
        return const PremiumBuyResult(started: false, cancelled: true);
      }
      if (error.code == 'storekit_duplicate_product_object') {
        final retryUntil = await resolveUnfinishedPurchases(
          productId: product.id,
        );
        if (retryUntil != null) {
          return PremiumBuyResult(started: false, entitledUntil: retryUntil);
        }
        try {
          final started = await _store.buyNonConsumable(
            purchaseParam: PurchaseParam(productDetails: product),
          );
          debugPrint('[PremiumStore] buy retry started=$started');
          return PremiumBuyResult(started: started);
        } on PlatformException catch (retryError) {
          debugPrint('[PremiumStore] buy retry failed code=${retryError.code}');
          return PremiumBuyResult(
            started: false,
            errorCode: retryError.code,
            errorMessage: retryError.message,
          );
        }
      }
      return PremiumBuyResult(
        started: false,
        errorCode: error.code,
        errorMessage: error.message,
      );
    }
  }

  Future<void> restore() async {
    await prepareStore();
    debugPrint('[PremiumStore] restorePurchases');
    await _store.restorePurchases();
  }

  Future<void> complete(PurchaseDetails purchase) =>
      _store.completePurchase(purchase);

  Future<DateTime> verify(PurchaseDetails purchase) => verifyRaw(
    source: purchase.verificationData.source,
    verificationData: purchase.verificationData.serverVerificationData,
  );

  Future<DateTime> verifyRaw({
    required String source,
    required String verificationData,
  }) async {
    final result = await _functions.httpsCallable('verifyPremiumPurchase').call(
      <String, Object?>{'source': source, 'verificationData': verificationData},
    );
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

class _FlorienPaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
    SKPaymentTransactionWrapper transaction,
    SKStorefrontWrapper storefront,
  ) => true;

  @override
  bool shouldShowPriceConsent() => false;
}
