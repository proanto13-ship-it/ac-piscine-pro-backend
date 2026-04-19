import 'plan.dart';
import 'entitlement.dart';
import 'subscription.dart';

class BillingSnapshot {
  final List<Plan> plans;
  final Subscription subscription;

  const BillingSnapshot({
    required this.plans,
    required this.subscription,
  });

  factory BillingSnapshot.fromJson(Map<String, dynamic> json) {
    final plans = Plan.catalogFromJsonList((json['plans'] ?? const []) as List);
    final subscriptionPayload = Map<String, dynamic>.from(
      (json['subscription'] as Map?) ?? const <String, dynamic>{},
    );
    var subscription = Subscription.fromJson(subscriptionPayload);
    final topLevelEntitlements = ((json['entitlements'] ?? const []) as List)
        .map((item) => Entitlement.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final resolvedPlan = plans.where((plan) => plan.id == subscription.planId);
    if (subscription.entitlements.isEmpty && topLevelEntitlements.isNotEmpty) {
      subscription = subscription.copyWith(entitlements: topLevelEntitlements);
    }
    if (subscription.resolvedPlan == null && resolvedPlan.isNotEmpty) {
      subscription = subscription.copyWith(resolvedPlan: resolvedPlan.first);
    }
    return BillingSnapshot(
      plans: plans,
      subscription: subscription,
    );
  }
}
