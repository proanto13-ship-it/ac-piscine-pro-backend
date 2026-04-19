import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/billing_checkout_session.dart';
import '../models/billing_result.dart';
import '../models/subscription.dart';
import 'app_environment.dart';
import 'billing_provider.dart';

class NativeBillingProvider implements BillingProvider {
  final InAppPurchase _inAppPurchase;
  final Duration _operationTimeout;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Completer<BillingResult>? _pendingCompleter;
  BillingCheckoutSession? _pendingSession;
  bool _restoring = false;

  NativeBillingProvider({
    InAppPurchase? inAppPurchase,
    Duration operationTimeout = const Duration(seconds: 45),
  })  : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance,
        _operationTimeout = operationTimeout;

  static bool get isSupportedPlatform => Platform.isIOS || Platform.isAndroid;

  @override
  String get providerKey => Platform.isIOS ? 'app_store' : 'play_store';

  @override
  Future<BillingCheckoutSession> createCheckoutSession({
    required String planId,
    required Subscription subscription,
  }) async {
    if (!isSupportedPlatform) {
      throw const NativeBillingException(
        'Le billing natif n est supporte que sur iOS et Android.',
      );
    }

    final productId = _productIdForPlan(planId);
    if (productId.isEmpty) {
      throw const NativeBillingException(
        'Aucun identifiant produit natif n est configure pour le plan Pro.',
      );
    }

    final isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      throw const NativeBillingException(
        'La boutique native n est pas disponible sur cet appareil.',
      );
    }

    final response = await _inAppPurchase.queryProductDetails({productId});
    if (response.error != null) {
      throw NativeBillingException(
        response.error!.message.isNotEmpty
            ? response.error!.message
            : 'Impossible de charger le produit d abonnement.',
      );
    }

    ProductDetails? detail;
    for (final item in response.productDetails) {
      if (item.id == productId) {
        detail = item;
        break;
      }
    }
    if (detail == null) {
      throw NativeBillingException(
        'Produit introuvable dans la boutique native: $productId',
      );
    }

    return BillingCheckoutSession(
      sessionId:
          '${providerKey}_${planId}_${DateTime.now().microsecondsSinceEpoch}',
      providerKey: providerKey,
      planId: planId,
      mode: BillingCheckoutMode.native,
      message: 'Achat natif de l abonnement $planId.',
      metadata: {
        'productId': detail.id,
        'price': detail.price,
        'title': detail.title,
        'description': detail.description,
        'currentPlanId': subscription.planId,
      },
    );
  }

  @override
  Future<BillingResult> startCheckout({
    required BillingCheckoutSession session,
  }) async {
    final productId = session.metadata['productId']?.toString() ?? '';
    if (productId.isEmpty) {
      throw const NativeBillingException(
        'Session billing native invalide: productId manquant.',
      );
    }

    final detail = await _loadProductDetail(productId);
    await _ensurePurchaseListener();
    _pendingSession = session;
    _restoring = false;
    _pendingCompleter = Completer<BillingResult>();

    final launched = await _inAppPurchase.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: detail),
    );
    if (!launched) {
      return _finishPending(
        BillingResult(
          status: BillingResultStatus.failed,
          message: 'Impossible de demarrer l achat natif.',
          session: session,
        ),
      );
    }

    return _awaitPendingResult(
      timeoutMessage:
          'Achat lance. Finalisez l operation dans la boutique puis revenez dans l app.',
    );
  }

  @override
  Future<BillingResult> restorePurchases({
    required String planId,
    required Subscription subscription,
  }) async {
    final session = await createCheckoutSession(
      planId: planId,
      subscription: subscription,
    );
    await _ensurePurchaseListener();
    _pendingSession = session;
    _restoring = true;
    _pendingCompleter = Completer<BillingResult>();

    await _inAppPurchase.restorePurchases();
    return _awaitPendingResult(
      timeoutMessage:
          'Aucun abonnement restorable n a ete trouve pour ce compte.',
    );
  }

  Future<ProductDetails> _loadProductDetail(String productId) async {
    final response = await _inAppPurchase.queryProductDetails({productId});
    if (response.error != null) {
      throw NativeBillingException(
        response.error!.message.isNotEmpty
            ? response.error!.message
            : 'Impossible de charger le produit natif.',
      );
    }
    for (final detail in response.productDetails) {
      if (detail.id == productId) {
        return detail;
      }
    }
    throw NativeBillingException(
      'Produit introuvable dans la boutique native: $productId',
    );
  }

  Future<void> _ensurePurchaseListener() async {
    if (_purchaseSubscription != null) {
      return;
    }
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      (purchases) {
        unawaited(_handlePurchaseUpdates(purchases));
      },
      onError: (Object error, StackTrace stackTrace) {
        _finishPending(
          BillingResult(
            status: BillingResultStatus.failed,
            message: 'Flux d achat natif en erreur: $error',
            session: _pendingSession,
          ),
        );
      },
    );
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    final pendingCompleter = _pendingCompleter;
    final pendingSession = _pendingSession;
    if (pendingCompleter == null || pendingSession == null) {
      return;
    }

    final expectedProductId =
        pendingSession.metadata['productId']?.toString().trim() ?? '';
    if (expectedProductId.isEmpty) {
      return;
    }

    for (final purchase in purchases) {
      if (purchase.productID != expectedProductId) {
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          continue;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
          _finishPending(
            BillingResult(
              status: BillingResultStatus.completed,
              message: _restoring
                  ? 'Abonnement restaure.'
                  : 'Abonnement achete avec succes.',
              session: pendingSession,
              shouldRefreshEntitlements: true,
              metadata: {
                'purchases': [_purchaseToJson(purchase)],
              },
            ),
          );
          return;
        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
          _finishPending(
            BillingResult(
              status: BillingResultStatus.failed,
              message: purchase.error?.message.isNotEmpty == true
                  ? purchase.error!.message
                  : 'Achat natif refuse ou en erreur.',
              session: pendingSession,
            ),
          );
          return;
        case PurchaseStatus.canceled:
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
          _finishPending(
            BillingResult(
              status: BillingResultStatus.cancelled,
              message: 'Achat annule.',
              session: pendingSession,
            ),
          );
          return;
      }
    }
  }

  Future<BillingResult> _awaitPendingResult({
    required String timeoutMessage,
  }) async {
    final pendingCompleter = _pendingCompleter;
    final pendingSession = _pendingSession;
    if (pendingCompleter == null || pendingSession == null) {
      throw const NativeBillingException(
        'Aucune operation billing native en attente.',
      );
    }
    return pendingCompleter.future.timeout(
      _operationTimeout,
      onTimeout: () => _finishPending(
        BillingResult(
          status: _restoring
              ? BillingResultStatus.failed
              : BillingResultStatus.opened,
          message: timeoutMessage,
          session: pendingSession,
        ),
      ),
    );
  }

  BillingResult _finishPending(BillingResult result) {
    final pendingCompleter = _pendingCompleter;
    if (pendingCompleter != null && !pendingCompleter.isCompleted) {
      pendingCompleter.complete(result);
    }
    _pendingCompleter = null;
    _pendingSession = null;
    _restoring = false;
    return result;
  }

  String _productIdForPlan(String planId) {
    if (planId != 'pro') {
      return '';
    }
    if (Platform.isIOS) {
      return AppEnvironment.iosProProductId;
    }
    if (Platform.isAndroid) {
      return AppEnvironment.androidProProductId;
    }
    return '';
  }

  Map<String, dynamic> _purchaseToJson(PurchaseDetails purchase) {
    return {
      'provider': providerKey,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'productId': purchase.productID,
      'purchaseId': purchase.purchaseID ?? '',
      'status': purchase.status.name,
      'transactionDateIso': _transactionDateIso(purchase.transactionDate),
      'source': purchase.verificationData.source,
      'serverVerificationData':
          purchase.verificationData.serverVerificationData,
      'localVerificationData': purchase.verificationData.localVerificationData,
    };
  }

  String _transactionDateIso(String? rawMillisecondsSinceEpoch) {
    final raw = rawMillisecondsSinceEpoch?.trim() ?? '';
    if (raw.isEmpty) {
      return DateTime.now().toUtc().toIso8601String();
    }
    final milliseconds = int.tryParse(raw);
    if (milliseconds == null) {
      return DateTime.now().toUtc().toIso8601String();
    }
    return DateTime.fromMillisecondsSinceEpoch(
      milliseconds,
      isUtc: true,
    ).toIso8601String();
  }
}

class NativeBillingException implements Exception {
  final String message;

  const NativeBillingException(this.message);

  @override
  String toString() => message;
}
