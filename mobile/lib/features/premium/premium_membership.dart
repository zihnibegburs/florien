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

  ProductDetails? get selectedProduct => productFor(selectedProductId);

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
  late final PremiumPurchaseService _service;

  @override
  Future<PremiumMembership> build() async {
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
      return PremiumMembership(
        storeAvailable: false,
        message: strings.storeUnavailable,
        paywallConfig: paywallConfig,
      );
    }

    final response = await _service.loadProducts();
    if (response.productDetails.isEmpty) {
      return PremiumMembership(
        storeAvailable: true,
        paywallConfig: paywallConfig,
        message: response.notFoundIDs.isNotEmpty
            ? strings.premiumProductsNotConfigured
            : strings.premiumInfoUnavailable,
      );
    }

    unawaited(_service.restore());
    return PremiumMembership(
      storeAvailable: true,
      products: _sortProducts(response.productDetails),
      selectedProductId: premiumMonthlyProductId,
      paywallConfig: paywallConfig,
    );
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
    var membership =
        state.valueOrNull ?? const PremiumMembership(storeAvailable: true);

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
