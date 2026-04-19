import 'package:ac_piscine_pro/models/feature_gate.dart';
import 'package:ac_piscine_pro/models/plan.dart';
import 'package:ac_piscine_pro/models/subscription.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Free plan blocks premium features and limits client count', () {
    final subscription = Subscription.defaults();

    expect(
      FeatureGate.isEnabled(subscription, EntitlementFlag.pdfExport),
      isFalse,
    );
    expect(
      FeatureGate.isEnabled(subscription, EntitlementFlag.teamMembers),
      isFalse,
    );
    expect(
      FeatureGate.isEnabled(subscription, EntitlementFlag.cloudSync),
      isFalse,
    );
    expect(FeatureGate.canAddClient(subscription, 9), isTrue);
    expect(FeatureGate.canAddClient(subscription, 10), isFalse);
  });

  test('Pro plan unlocks all current entitlements', () {
    final subscription = Subscription.defaults().copyWith(planId: 'pro');

    expect(
      FeatureGate.isEnabled(subscription, EntitlementFlag.unlimitedClients),
      isTrue,
    );
    expect(
      FeatureGate.isEnabled(subscription, EntitlementFlag.pdfExport),
      isTrue,
    );
    expect(
      FeatureGate.isEnabled(subscription, EntitlementFlag.teamMembers),
      isTrue,
    );
    expect(
      FeatureGate.isEnabled(subscription, EntitlementFlag.cloudSync),
      isTrue,
    );
    expect(FeatureGate.canAddClient(subscription, 1000), isTrue);
  });

  test('Backend entitlements override local hardcoded plan fallback', () {
    final subscription = Subscription.defaults().copyWith(
      planId: 'free',
      resolvedPlan: const Plan(
        id: 'free',
        displayName: 'Free',
        clientLimit: 10,
        entitlements: [
          Entitlement(
            flag: EntitlementFlag.unlimitedClients,
            enabled: false,
          ),
          Entitlement(
            flag: EntitlementFlag.pdfExport,
            enabled: false,
          ),
          Entitlement(
            flag: EntitlementFlag.teamMembers,
            enabled: false,
          ),
          Entitlement(
            flag: EntitlementFlag.cloudSync,
            enabled: false,
          ),
        ],
      ),
      entitlements: const [
        Entitlement(flag: EntitlementFlag.cloudSync, enabled: true),
        Entitlement(flag: EntitlementFlag.pdfExport, enabled: true),
      ],
    );

    expect(
      FeatureGate.isEnabled(subscription, EntitlementFlag.cloudSync),
      isTrue,
    );
    expect(
      FeatureGate.isEnabled(subscription, EntitlementFlag.pdfExport),
      isTrue,
    );
    expect(
      FeatureGate.isEnabled(subscription, EntitlementFlag.teamMembers),
      isFalse,
    );
    expect(FeatureGate.canAddClient(subscription, 10), isFalse);
  });

  test('Trial status unlocks premium features during the trial period', () {
    final subscription = Subscription.defaults().copyWith(
      planId: 'pro',
      status: SubscriptionStatus.trial,
      endedAtIso:
          DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
      resolvedPlan: const Plan(
        id: 'pro',
        displayName: 'Pro',
        trialDays: 7,
        entitlements: [
          Entitlement(flag: EntitlementFlag.unlimitedClients, enabled: true),
          Entitlement(flag: EntitlementFlag.pdfExport, enabled: true),
          Entitlement(flag: EntitlementFlag.teamMembers, enabled: true),
          Entitlement(flag: EntitlementFlag.cloudSync, enabled: true),
        ],
      ),
    );

    expect(
        FeatureGate.isEnabled(subscription, EntitlementFlag.pdfExport), isTrue);
    expect(
        FeatureGate.isEnabled(subscription, EntitlementFlag.cloudSync), isTrue);
    expect(FeatureGate.canAddClient(subscription, 999), isTrue);
  });

  test('Past due status blocks premium features and client growth', () {
    final subscription = Subscription.defaults().copyWith(
      planId: 'pro',
      status: SubscriptionStatus.pastDue,
      resolvedPlan: Plan.pro,
    );

    expect(FeatureGate.isEnabled(subscription, EntitlementFlag.pdfExport),
        isFalse);
    expect(FeatureGate.isEnabled(subscription, EntitlementFlag.teamMembers),
        isFalse);
    expect(FeatureGate.canAddClient(subscription, 10), isFalse);
    expect(
      FeatureGate.blockedMessage(subscription, EntitlementFlag.cloudSync),
      contains('paiement'),
    );
  });

  test('Canceled status keeps access until the end date', () {
    final subscription = Subscription.defaults().copyWith(
      planId: 'pro',
      status: SubscriptionStatus.canceled,
      endedAtIso:
          DateTime.now().toUtc().add(const Duration(days: 3)).toIso8601String(),
      resolvedPlan: Plan.pro,
    );

    expect(
        FeatureGate.isEnabled(subscription, EntitlementFlag.pdfExport), isTrue);
    expect(FeatureGate.isEnabled(subscription, EntitlementFlag.teamMembers),
        isTrue);
    expect(FeatureGate.canAddClient(subscription, 999), isTrue);
  });

  test('Expired status blocks premium features and falls back to free limit',
      () {
    final subscription = Subscription.defaults().copyWith(
      planId: 'pro',
      status: SubscriptionStatus.expired,
      trialUsed: true,
      resolvedPlan: const Plan(
        id: 'pro',
        displayName: 'Pro',
        trialDays: 7,
        entitlements: [
          Entitlement(flag: EntitlementFlag.unlimitedClients, enabled: true),
          Entitlement(flag: EntitlementFlag.pdfExport, enabled: true),
          Entitlement(flag: EntitlementFlag.teamMembers, enabled: true),
          Entitlement(flag: EntitlementFlag.cloudSync, enabled: true),
        ],
      ),
    );

    expect(FeatureGate.isEnabled(subscription, EntitlementFlag.pdfExport),
        isFalse);
    expect(FeatureGate.isEnabled(subscription, EntitlementFlag.cloudSync),
        isFalse);
    expect(FeatureGate.canAddClient(subscription, 9), isTrue);
    expect(FeatureGate.canAddClient(subscription, 10), isFalse);
    expect(
      FeatureGate.blockedMessage(subscription, EntitlementFlag.pdfExport),
      contains('expir'),
    );
  });
}
