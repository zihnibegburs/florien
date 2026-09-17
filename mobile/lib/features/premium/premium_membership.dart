import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:florien/core/firebase/firebase_providers.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/services/planner_ai_service.dart';
import 'package:florien/core/services/premium_purchase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PremiumMembership {
  const PremiumMembership({
    required this.storeAvailable,
    this.products = const [],
    this.selectedProductId,
    this.isPremium = false,
    this.premiumUntil,
    this.aiChatUsage,
    this.isPurchasing = false,
    this.message,
    this.storeDiagnostics,
    this.paywallConfig = const {},
  });

  final bool storeAvailable;
  final List<ProductDetails> products;
  final String? selectedProductId;
  final bool isPremium;
  final DateTime? premiumUntil;
  final AiChatUsage? aiChatUsage;
  final bool isPurchasing;
  final String? message;
  final String? storeDiagnostics;
  final Map<String, dynamic> paywallConfig;

  /// Prefer [premiumUntil] when present so expired local state cannot linger.
  bool get hasActivePremium {
    final until = premiumUntil;
    if (until != null) return until.isAfter(DateTime.now());
    return isPremium;
  }

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
    DateTime? premiumUntil,
    AiChatUsage? aiChatUsage,
    bool? isPurchasing,
    String? message,
    String? storeDiagnostics,
    Map<String, dynamic>? paywallConfig,
    bool clearMessage = false,
    bool clearPremiumUntil = false,
    bool clearStoreDiagnostics = false,
    bool clearAiChatUsage = false,
  }) => PremiumMembership(
    storeAvailable: storeAvailable ?? this.storeAvailable,
    products: products ?? this.products,
    selectedProductId: selectedProductId ?? this.selectedProductId,
    isPremium: isPremium ?? this.isPremium,
    premiumUntil: clearPremiumUntil
        ? null
        : (premiumUntil ?? this.premiumUntil),
    aiChatUsage: clearAiChatUsage ? null : (aiChatUsage ?? this.aiChatUsage),
    isPurchasing: isPurchasing ?? this.isPurchasing,
    message: clearMessage ? null : (message ?? this.message),
    storeDiagnostics: clearStoreDiagnostics
        ? null
        : (storeDiagnostics ?? this.storeDiagnostics),
    paywallConfig: paywallConfig ?? this.paywallConfig,
  );
}

final premiumPurchaseServiceProvider = Provider<PremiumPurchaseService>(
  (ref) => PremiumPurchaseService(
    functions: ref.watch(cloudFunctionsProvider),
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(optionalFirebaseAuthProvider),
  ),
);

/// Server is source of truth when it reports inactive; when active, keep the
/// later of server/local expiry (a concurrent verify may be slightly newer).
/// A failed fetch must not demote an already-active membership.
/// Never clears loaded StoreKit [products].
PremiumMembership applyServerEntitlement(
  PremiumMembership membership,
  PremiumEntitlement entitlement,
) {
  if (entitlement.fetchFailed) return membership;
  final withUsage = membership.copyWith(aiChatUsage: entitlement.aiChatUsage);
  if (!entitlement.isPremium) {
    return withUsage.copyWith(isPremium: false, clearPremiumUntil: true);
  }
  final serverUntil = entitlement.premiumUntil;
  final localUntil = membership.premiumUntil;
  final bestUntil = switch ((serverUntil, localUntil)) {
    (final DateTime server, final DateTime local) =>
      server.isAfter(local) ? server : local,
    (final DateTime server, null) => server,
    (null, final DateTime local) => local,
    (null, null) => null,
  };
  return withUsage.copyWith(
    isPremium: bestUntil != null && bestUntil.isAfter(DateTime.now()),
    premiumUntil: bestUntil,
    clearPremiumUntil: bestUntil == null,
  );
}

final premiumMembershipProvider =
    AsyncNotifierProvider<PremiumMembershipNotifier, PremiumMembership>(
      PremiumMembershipNotifier.new,
    );

class PremiumMembershipNotifier extends AsyncNotifier<PremiumMembership> {
  static const _restoreSettleTimeout = Duration(seconds: 12);

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Completer<PremiumMembership>? _initialMembership;
  Timer? _restoreSettleTimer;
  late final PremiumPurchaseService _service;
  var _pendingServerVerify = 0;

  @override
  Future<PremiumMembership> build() async {
    // Read once — watching authState/firebaseUser rebuilds this notifier and
    // cancels in-flight StoreKit queries (products then look "missing").
    // `authStateChanges` may not have emitted its first value yet at app
    // startup. Reading the cached Firebase user avoids treating an already
    // signed-in Premium member as free for that first frame.
    final firebaseUser =
        ref.read(optionalFirebaseAuthProvider)?.currentUser ??
        ref.read(firebaseUserProvider).valueOrNull;
    await _purchaseSubscription?.cancel();
    _restoreSettleTimer?.cancel();
    final initialMembership = Completer<PremiumMembership>();
    _initialMembership = initialMembership;
    _service = ref.read(premiumPurchaseServiceProvider);
    final strings = ref.read(stringsProvider);
    final paywallConfigFuture = _loadPaywallConfig();
    final entitlementFuture = firebaseUser == null
        ? Future.value(const PremiumEntitlement.none())
        : _service.fetchEntitlement();
    _purchaseSubscription = _service.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (_, _) => _setMessage(strings.purchaseInfoUnavailable),
    );
    ref.onDispose(() {
      _purchaseSubscription?.cancel();
      _restoreSettleTimer?.cancel();
    });

    final isAvailable = await _service.isAvailable();
    final paywallConfig = await paywallConfigFuture;
    if (!isAvailable) {
      final entitlement = await entitlementFuture;
      return _completeInitialMembership(
        PremiumMembership(
          storeAvailable: false,
          isPremium: entitlement.isPremium,
          premiumUntil: entitlement.premiumUntil,
          message: strings.storeUnavailable,
          paywallConfig: paywallConfig,
        ),
        initialMembership,
      );
    }

    // StoreKit loading and entitlement lookup run in parallel.
    final products = await _loadProductsWithRetry();
    // Do not publish an optimistic free membership before the server has
    // answered. Home uses this state to decide whether to render its Premium
    // CTA, so doing so would briefly show the CTA to Premium members.
    final entitlement = await entitlementFuture;
    final membership = PremiumMembership(
      storeAvailable: true,
      products: products.products,
      selectedProductId: products.products.isEmpty
          ? null
          : _availableSelection(products.products),
      isPremium: entitlement.isPremium,
      premiumUntil: entitlement.premiumUntil,
      paywallConfig: paywallConfig,
      message: products.products.isEmpty
          ? strings.premiumProductsTemporarilyUnavailable
          : null,
      storeDiagnostics: products.diagnostics,
    );
    _completeInitialMembership(membership, initialMembership);

    // Restore can still refine the verified entitlement in the background;
    // it must not clear [products].
    if (firebaseUser != null) unawaited(_startRestore());
    return membership;
  }

  PremiumMembership _completeInitialMembership(
    PremiumMembership membership,
    Completer<PremiumMembership> initial,
  ) {
    if (!initial.isCompleted) initial.complete(membership);
    return membership;
  }

  Future<PremiumStoreQueryResult> _loadProductsWithRetry() async {
    PremiumStoreQueryResult? last;
    final productsById = <String, ProductDetails>{};
    final notFound = <String>{};

    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
      try {
        last = await _service.queryProducts();
        for (final product in last.products) {
          productsById[product.id] = product;
        }
        notFound
          ..clear()
          ..addAll(last.notFoundIds);
      } catch (error) {
        debugPrint(
          '[PremiumStore] product query attempt $attempt failed: $error',
        );
      }
      if (productsById.length >= premiumProductIds.length) break;
    }

    return PremiumStoreQueryResult(
      products: _sortProducts(productsById.values.toList(growable: false)),
      notFoundIds: notFound.toList(growable: false),
      errorCode: last?.errorCode,
      errorMessage: last?.errorMessage,
    );
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
      final result = await _loadProductsWithRetry();
      final current = state.requireValue;
      if (result.products.isEmpty) {
        state = AsyncData(
          current.copyWith(
            isPurchasing: false,
            products: const [],
            message: strings.premiumProductsTemporarilyUnavailable,
            storeDiagnostics: result.diagnostics,
          ),
        );
        return;
      }
      state = AsyncData(
        current.copyWith(
          products: result.products,
          selectedProductId: _availableSelection(
            result.products,
            current.selectedProductId,
          ),
          isPurchasing: false,
          clearMessage: true,
          storeDiagnostics: result.diagnostics,
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
      _setMessage(
        membership?.products.isEmpty == true
            ? strings.premiumProductsTemporarilyUnavailable
            : strings.premiumProductUnavailable,
      );
      return;
    }
    state = AsyncData(
      membership.copyWith(isPurchasing: true, clearMessage: true),
    );
    try {
      final result = await _service.buy(product);
      debugPrint('[PremiumStore] buyPremium ${result.diagnostics}');
      if (result.entitledUntil != null) {
        final current = state.valueOrNull ?? membership;
        state = AsyncData(
          current.copyWith(
            isPremium: true,
            premiumUntil: result.entitledUntil,
            isPurchasing: false,
            clearMessage: true,
          ),
        );
        return;
      }
      if (result.cancelled) {
        state = AsyncData(
          (state.valueOrNull ?? membership).copyWith(isPurchasing: false),
        );
        return;
      }
      if (!result.started) {
        final detail = [
          if (result.errorCode != null) result.errorCode,
          if (result.errorMessage != null) result.errorMessage,
        ].join(': ');
        _setMessage(
          detail.isEmpty
              ? strings.purchaseCouldNotStart
              : '${strings.purchaseCouldNotStart} ($detail)',
        );
        return;
      }
      // StoreKit sheet should follow; if the stream never settles, unblock UI.
      _armPurchaseSettleTimer();
    } catch (error) {
      debugPrint('[PremiumStore] buyPremium error: $error');
      _setMessage('${strings.purchaseCouldNotStart} ($error)');
    }
  }

  void clearStuckPurchasing() {
    final membership = state.valueOrNull;
    if (membership == null || !membership.isPurchasing) return;
    state = AsyncData(membership.copyWith(isPurchasing: false));
  }

  void _armPurchaseSettleTimer() {
    _restoreSettleTimer?.cancel();
    _restoreSettleTimer = Timer(_restoreSettleTimeout, () {
      final current = state.valueOrNull;
      if (current == null || !current.isPurchasing) return;
      if (current.hasActivePremium) {
        state = AsyncData(current.copyWith(isPurchasing: false));
        return;
      }
      state = AsyncData(
        current.copyWith(
          isPurchasing: false,
          message: ref.read(stringsProvider).purchaseCouldNotComplete,
        ),
      );
    });
  }

  Future<void> restorePurchases() async {
    final membership = state.valueOrNull;
    if (membership == null || !membership.storeAvailable) return;
    state = AsyncData(
      membership.copyWith(isPurchasing: true, clearMessage: true),
    );
    await _startRestore();
  }

  Future<void> refreshEntitlement() async {
    final membership = state.valueOrNull;
    if (membership == null ||
        membership.isPurchasing ||
        _pendingServerVerify > 0) {
      return;
    }
    final entitlement = await _service.fetchEntitlement();
    final current = state.valueOrNull ?? membership;
    if (current.isPurchasing || _pendingServerVerify > 0) return;
    state = AsyncData(
      applyServerEntitlement(
        current,
        entitlement,
      ).copyWith(isPurchasing: false),
    );
  }

  Future<void> _startRestore() async {
    final strings = ref.read(stringsProvider);
    try {
      await _service.restore();
      _armRestoreSettleTimer();
    } catch (_) {
      _restoreSettleTimer?.cancel();
      _setMessage(strings.purchasesCouldNotRestore);
    }
  }

  void _armRestoreSettleTimer() {
    _restoreSettleTimer?.cancel();
    _restoreSettleTimer = Timer(_restoreSettleTimeout, () async {
      final current = state.valueOrNull;
      if (current == null || !current.isPurchasing) return;
      // Store may not emit; fall back to server entitlement.
      final entitlement = await _service.fetchEntitlement();
      final latest = state.valueOrNull ?? current;
      state = AsyncData(
        applyServerEntitlement(
          latest,
          entitlement,
        ).copyWith(isPurchasing: false),
      );
    });
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

    var anyVerified = false;
    DateTime? bestUntil = membership.premiumUntil;
    String? failureMessage;
    var sawPending = false;
    var sawTerminalFailure = false;
    var grantedOptimistically = false;

    for (final purchase in purchases) {
      if (!premiumProductIds.contains(purchase.productID)) continue;
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // StoreKit already charged. Show Premium immediately, then confirm.
          if (membership.isPurchasing && !membership.hasActivePremium) {
            grantedOptimistically = true;
            membership = membership.copyWith(
              isPremium: true,
              isPurchasing: false,
              clearMessage: true,
            );
            state = AsyncData(membership);
          }
          _pendingServerVerify++;
          try {
            final until = await _service.verify(purchase);
            anyVerified = true;
            if (bestUntil == null || until.isAfter(bestUntil)) {
              bestUntil = until;
            }
          } on FirebaseFunctionsException catch (error) {
            final reason = _premiumFailureReason(error);
            if (!anyVerified) {
              failureMessage = _premiumVerificationMessage(error, strings);
              sawTerminalFailure = true;
            }
            debugPrint(
              '[PremiumStore] verify CF error reason=$reason code=${error.code}',
            );
          } catch (error) {
            if (!anyVerified) {
              failureMessage = strings.premiumCouldNotVerify;
              sawTerminalFailure = true;
            }
            debugPrint('[PremiumStore] verify error: $error');
          } finally {
            _pendingServerVerify = (_pendingServerVerify - 1).clamp(0, 1 << 30);
            // Always finish StoreKit txs we handled — unfinished ones block
            // the next buy with storekit_duplicate_product_object.
            if (purchase.pendingCompletePurchase) {
              try {
                await _service.complete(purchase);
              } catch (error) {
                debugPrint('[PremiumStore] completePurchase failed: $error');
              }
            }
          }
        case PurchaseStatus.pending:
          sawPending = true;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          sawTerminalFailure = true;
          failureMessage =
              purchase.error?.message ?? strings.purchaseCouldNotComplete;
      }
    }

    if (anyVerified) {
      _restoreSettleTimer?.cancel();
      membership = membership.copyWith(
        isPremium: true,
        premiumUntil: bestUntil,
        isPurchasing: false,
        clearMessage: true,
      );
    } else if (sawPending) {
      // Do not flip isPurchasing here — background restore must not lock the CTA.
      // buyPremium/restorePurchases already set isPurchasing when the user acts.
    } else if (sawTerminalFailure) {
      _restoreSettleTimer?.cancel();
      // Keep an already-active entitlement unless we only showed Premium
      // because StoreKit said purchased and the server then rejected it.
      membership = membership.copyWith(
        isPurchasing: false,
        isPremium: grantedOptimistically ? false : membership.isPremium,
        clearPremiumUntil: grantedOptimistically,
        message: (membership.isPurchasing || grantedOptimistically)
            ? failureMessage
            : membership.message,
      );
    }

    state = AsyncData(membership);
  }

  String? _premiumFailureReason(FirebaseFunctionsException error) {
    final details = error.details;
    if (details is Map) return details['reason']?.toString();
    return null;
  }

  String _premiumVerificationMessage(
    FirebaseFunctionsException error,
    S strings,
  ) {
    return switch (_premiumFailureReason(error)) {
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
