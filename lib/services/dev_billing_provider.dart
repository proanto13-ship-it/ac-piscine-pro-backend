import '../models/billing_checkout_session.dart';
import '../models/billing_result.dart';
import '../models/subscription.dart';
import 'billing_provider.dart';

class DevBillingProvider implements BillingProvider {
  const DevBillingProvider();

  @override
  String get providerKey => 'dev_manual';

  @override
  Future<BillingCheckoutSession> createCheckoutSession({
    required String planId,
    required Subscription subscription,
  }) async {
    return BillingCheckoutSession(
      sessionId: 'dev_${planId}_${DateTime.now().microsecondsSinceEpoch}',
      providerKey: providerKey,
      planId: planId,
      mode: BillingCheckoutMode.manual,
      message:
          'Pendant la bêta, l’offre Pro est activée manuellement par notre équipe. Contactez-nous avec l’email de votre compte pour activer l’accès Pro.',
      metadata: {
        'currentPlanId': subscription.planId,
        'targetPlanId': planId,
      },
    );
  }

  @override
  Future<BillingResult> startCheckout({
    required BillingCheckoutSession session,
  }) async {
    return BillingResult(
      status: BillingResultStatus.pendingManualAction,
      message: session.message,
      session: session,
      shouldRefreshEntitlements: false,
    );
  }

  @override
  Future<BillingResult> restorePurchases({
    required String planId,
    required Subscription subscription,
  }) async {
    return BillingResult(
      status: BillingResultStatus.pendingManualAction,
      message:
          'Pendant la bêta, notre équipe peut vérifier ou réactiver votre accès Pro si nécessaire.',
      session: await createCheckoutSession(
        planId: planId,
        subscription: subscription,
      ),
      shouldRefreshEntitlements: false,
    );
  }
}
