import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:florien/core/firebase/firebase_providers.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:florien/core/services/premium_purchase_service.dart';

class PremiumMembership {
  const PremiumMembership({
    required this.storeAvailable,
    this.products = const [],
    this.selectedProductId,
    this.isPremium = false,
    this.isPurchasing = false,
    this.message,
    this.paywallConfig = const {},
  });

  final bool storeAvailable;
  final List<ProductDetails> products;
  final String? selectedProductId;
  final bool isPremium;
  final bool isPurchasing;
  final String? message;
  final Map<String, dynamic> paywallConfig;

  ProductDetails? get selectedProduct =>
      productFor(selectedProductId) ?? products.firstOrNull;

  String? get effectiveSelectedProductId => selectedProduct?.id;

  ProductDetails? productFor(String? productId) {
    for (final product in products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  PremiumMembership copyWith({
    bool? storeAvailable,
    List<ProductDetails>? products,
    String? selectedProductId,
    bool? isPremium,
    bool? isPurchasing,
    String? message,
    Map<String, dynamic>? paywallConfig,
    bool clearMessage = false,
  }) => PremiumMembership(
    storeAvailable: storeAvailable ?? this.storeAvailable,
    products: products ?? this.products,
    selectedProductId: selectedProductId ?? this.selectedProductId,
    isPremium: isPremium ?? this.isPremium,
    isPurchasing: isPurchasing ?? this.isPurchasing,
    message: clearMessage ? null : (message ?? this.message),
    paywallConfig: paywallConfig ?? this.paywallConfig,
  );
}

final premiumPurchaseServiceProvider = Provider<PremiumPurchaseService>(
  (ref) => PremiumPurchaseService(
    functions: ref.watch(cloudFunctionsProvider),
    firestore: ref.watch(firestoreProvider),
  ),
);

final premiumMembershipProvider =
    AsyncNotifierProvider<PremiumMembershipNotifier, PremiumMembership>(
      PremiumMembershipNotifier.new,
    );

class PremiumMembershipNotifier extends AsyncNotifier<PremiumMembership> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Completer<PremiumMembership>? _initialMembership;
  late final PremiumPurchaseService _service;

  @override
  Future<PremiumMembership> build() async {
    final firebaseUser = ref.watch(firebaseUserProvider).valueOrNull;
    await _purchaseSubscription?.cancel();
    final initialMembership = Completer<PremiumMembership>();
    _initialMembership = initialMembership;
    _service = ref.read(premiumPurchaseServiceProvider);
    final strings = ref.read(stringsProvider);
    final paywallConfigFuture = _loadPaywallConfig();
    _purchaseSubscription = _service.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (_, _) => _setMessage(strings.purchaseInfoUnavailable),
    );
    ref.onDispose(() => _purchaseSubscription?.cancel());

    final isAvailable = await _service.isAvailable();
    final paywallConfig = await paywallConfigFuture;
    if (!isAvailable) {
      return _completeInitialMembership(
        PremiumMembership(
          storeAvailable: false,
          message: strings.storeUnavailable,
          paywallConfig: paywallConfig,
        ),
        initialMembership,
      );
    }

    final products = await _loadProductsWithRetry();
    if (products.isEmpty) {
      final membership = PremiumMembership(
        storeAvailable: true,
        paywallConfig: paywallConfig,
        message: strings.premiumProductsTemporarilyUnavailable,
      );
      _completeInitialMembership(membership, initialMembership);
      if (firebaseUser != null) unawaited(_service.restore());
      return membership;
    }

    final membership = PremiumMembership(
      storeAvailable: true,
      products: products,
      selectedProductId: _availableSelection(products),
      paywallConfig: paywallConfig,
    );
    _completeInitialMembership(membership, initialMembership);
    if (firebaseUser != null) unawaited(_service.restore());
    return membership;
  }

  PremiumMembership _completeInitialMembership(
    PremiumMembership membership,
    Completer<PremiumMembership> initial,
  ) {
    if (!initial.isCompleted) initial.complete(membership);
    return membership;
  }

  Future<List<ProductDetails>> _loadProductsWithRetry() async {
    var firstProducts = const <ProductDetails>[];
    try {
      firstProducts = (await _service.loadProducts()).productDetails;
    } catch (_) {}
    if (firstProducts.length == premiumProductIds.length) {
      return _sortProducts(firstProducts);
    }

    await Future<void>.delayed(const Duration(milliseconds: 350));
    var secondProducts = const <ProductDetails>[];
    try {
      secondProducts = (await _service.loadProducts()).productDetails;
    } catch (_) {}
    final productsById = <String, ProductDetails>{
      for (final product in firstProducts) product.id: product,
      for (final product in secondProducts) product.id: product,
    };
    return _sortProducts(productsById.values.toList(growable: false));
  }

  String? _availableSelection(
    List<ProductDetails> products, [
    String? preferred,
  ]) {
    if (preferred != null &&
        products.any((product) => product.id == preferred)) {
      return preferred;
    }
    if (products.any((product) => product.id == premiumMonthlyProductId)) {
      return premiumMonthlyProductId;
    }
    return products.firstOrNull?.id;
  }

  Future<Map<String, dynamic>> _loadPaywallConfig() async {
    try {
      return await _service.loadPaywallConfig().timeout(
        const Duration(seconds: 2),
        onTimeout: () => const {},
      );
    } catch (_) {
      return const {};
    }
  }

  Future<void> selectPlan(String productId) async {
    final membership = state.valueOrNull;
    if (membership == null || membership.productFor(productId) == null) return;
    state = AsyncData(membership.copyWith(selectedProductId: productId));
  }

  Future<void> reloadProducts() async {
    final strings = ref.read(stringsProvider);
    final membership = state.valueOrNull;
    if (membership == null || !membership.storeAvailable) return;
    state = AsyncData(
      membership.copyWith(isPurchasing: true, clearMessage: true),
    );
    try {
      final products = await _loadProductsWithRetry();
      final current = state.requireValue;
      if (products.isEmpty) {
        state = AsyncData(
          current.copyWith(
            isPurchasing: false,
            message: strings.premiumProductsTemporarilyUnavailable,
          ),
        );
        return;
      }
      state = AsyncData(
        current.copyWith(
          products: products,
          selectedProductId: _availableSelection(
            products,
            current.selectedProductId,
          ),
          isPurchasing: false,
          clearMessage: true,
        ),
      );
    } catch (_) {
      _setMessage(strings.premiumProductsTemporarilyUnavailable);
    }
  }

  Future<void> buyPremium() async {
    final strings = ref.read(stringsProvider);
    final membership = state.valueOrNull;
    final product = membership?.selectedProduct;
    if (membership == null || !membership.storeAvailable || product == null) {
      _setMessage(strings.premiumProductUnavailable);
      return;
    }
    state = AsyncData(
      membership.copyWith(isPurchasing: true, clearMessage: true),
    );
    try {
      await _service.buy(product);
    } catch (_) {
      _setMessage(strings.purchaseCouldNotStart);
    }
  }

  Future<void> restorePurchases() async {
    final strings = ref.read(stringsProvider);
    final membership = state.valueOrNull;
    if (membership == null || !membership.storeAvailable) return;
    state = AsyncData(
      membership.copyWith(isPurchasing: true, clearMessage: true),
    );
    try {
      await _service.restore();
      state = AsyncData(state.requireValue.copyWith(isPurchasing: false));
    } catch (_) {
      _setMessage(strings.purchasesCouldNotRestore);
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    final strings = ref.read(stringsProvider);
    final currentMembership = state.valueOrNull;
    final initialMembership = _initialMembership;
    var membership =
        currentMembership ??
        (initialMembership == null
            ? const PremiumMembership(storeAvailable: true)
            : await initialMembership.future);

    for (final purchase in purchases) {
      if (!premiumProductIds.contains(purchase.productID)) continue;
      var verified = false;
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            await _service.verify(purchase);
            verified = true;
            membership = membership.copyWith(
              isPremium: true,
              isPurchasing: false,
              clearMessage: true,
            );
          } on FirebaseFunctionsException catch (error) {
            membership = membership.copyWith(
              isPremium: false,
              isPurchasing: false,
              message: _premiumVerificationMessage(error, strings),
            );
          } catch (_) {
            membership = membership.copyWith(
              isPremium: false,
              isPurchasing: false,
              message: strings.premiumCouldNotVerify,
            );
          }
        case PurchaseStatus.pending:
          membership = membership.copyWith(isPurchasing: true);
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          membership = membership.copyWith(
            isPurchasing: false,
            message:
                purchase.error?.message ?? strings.purchaseCouldNotComplete,
          );
      }
      if (verified && purchase.pendingCompletePurchase) {
        await _service.complete(purchase);
      }
    }

    state = AsyncData(membership);
  }

  String _premiumVerificationMessage(
    FirebaseFunctionsException error,
    S strings,
  ) {
    final details = error.details;
    final reason = details is Map ? details['reason']?.toString() : null;
    return switch (reason) {
      'PREMIUM_PURCHASE_ALREADY_CLAIMED' =>
        strings.premiumPurchaseAlreadyClaimed,
      'PREMIUM_VERIFICATION_UNAVAILABLE' =>
        strings.premiumVerificationUnavailable,
      _ => strings.activePremiumCouldNotVerify,
    };
  }

  void _setMessage(String message) {
    final membership = state.valueOrNull;
    if (membership == null) return;
    state = AsyncData(
      membership.copyWith(isPurchasing: false, message: message),
    );
  }

  List<ProductDetails> _sortProducts(List<ProductDetails> products) {
    final sorted = [...products];
    sorted.sort(
      (first, second) => premiumProductIds
          .toList()
          .indexOf(first.id)
          .compareTo(premiumProductIds.toList().indexOf(second.id)),
    );
    return sorted;
  }
}
