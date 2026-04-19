import '../models/billing_checkout_session.dart';
import '../models/billing_result.dart';
import '../models/subscription.dart';

abstract class BillingProvider {
  String get providerKey;

  Future<BillingCheckoutSession> createCheckoutSession({
    required String planId,
    required Subscription subscription,
  });

  Future<BillingResult> startCheckout({
    required BillingCheckoutSession session,
  });

  Future<BillingResult> restorePurchases({
    required String planId,
    required Subscription subscription,
  });
}
