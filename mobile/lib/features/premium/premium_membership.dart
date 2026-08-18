import 'dart:async';

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
  });

  final bool storeAvailable;
  final List<ProductDetails> products;
  final String? selectedProductId;
  final bool isPremium;
  final bool isPurchasing;
  final String? message;

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
    bool clearMessage = false,
  }) => PremiumMembership(
    storeAvailable: storeAvailable ?? this.storeAvailable,
    products: products ?? this.products,
    selectedProductId: selectedProductId ?? this.selectedProductId,
    isPremium: isPremium ?? this.isPremium,
    isPurchasing: isPurchasing ?? this.isPurchasing,
    message: clearMessage ? null : (message ?? this.message),
  );
}

final premiumPurchaseServiceProvider = Provider<PremiumPurchaseService>(
  (ref) => PremiumPurchaseService(),
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
    _purchaseSubscription = _service.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (_, _) => _setMessage('Satın alma bilgisi alınamadı.'),
    );
    ref.onDispose(() => _purchaseSubscription?.cancel());

    final isAvailable = await _service.isAvailable();
    if (!isAvailable) {
      return const PremiumMembership(
        storeAvailable: false,
        message: 'Mağaza şu anda kullanılamıyor.',
      );
    }

    final response = await _service.loadProducts();
    if (response.productDetails.isEmpty) {
      return PremiumMembership(
        storeAvailable: true,
        message: response.notFoundIDs.isNotEmpty
            ? 'Premium abonelikleri mağazada henüz yapılandırılmadı.'
            : 'Premium bilgisi alınamadı.',
      );
    }

    unawaited(_service.restore());
    return PremiumMembership(
      storeAvailable: true,
      products: _sortProducts(response.productDetails),
      selectedProductId: premiumMonthlyProductId,
    );
  }

  Future<void> selectPlan(String productId) async {
    final membership = state.valueOrNull;
    if (membership == null || membership.productFor(productId) == null) return;
    state = AsyncData(membership.copyWith(selectedProductId: productId));
  }

  Future<void> buyPremium() async {
    final membership = state.valueOrNull;
    final product = membership?.selectedProduct;
    if (membership == null || !membership.storeAvailable || product == null) {
      _setMessage('Premium ürünü şu anda satın alınamıyor.');
      return;
    }
    state = AsyncData(
      membership.copyWith(isPurchasing: true, clearMessage: true),
    );
    try {
      await _service.buy(product);
    } catch (_) {
      _setMessage('Satın alma başlatılamadı. Lütfen tekrar dene.');
    }
  }

  Future<void> restorePurchases() async {
    final membership = state.valueOrNull;
    if (membership == null || !membership.storeAvailable) return;
    state = AsyncData(
      membership.copyWith(isPurchasing: true, clearMessage: true),
    );
    try {
      await _service.restore();
      state = AsyncData(state.requireValue.copyWith(isPurchasing: false));
    } catch (_) {
      _setMessage('Satın alımlar geri yüklenemedi.');
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    var membership =
        state.valueOrNull ?? const PremiumMembership(storeAvailable: true);

    for (final purchase in purchases) {
      if (!premiumProductIds.contains(purchase.productID)) continue;
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          membership = membership.copyWith(
            isPremium: true,
            isPurchasing: false,
            clearMessage: true,
          );
        case PurchaseStatus.pending:
          membership = membership.copyWith(isPurchasing: true);
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          membership = membership.copyWith(
            isPurchasing: false,
            message: purchase.error?.message ?? 'Satın alma tamamlanamadı.',
          );
      }
      if (purchase.pendingCompletePurchase) {
        await _service.complete(purchase);
      }
    }

    state = AsyncData(membership);
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
