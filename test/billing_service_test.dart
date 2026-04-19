import 'package:ac_piscine_pro/models/auth_session.dart';
import 'package:ac_piscine_pro/models/billing_checkout_session.dart';
import 'package:ac_piscine_pro/models/billing_result.dart';
import 'package:ac_piscine_pro/models/billing_snapshot.dart';
import 'package:ac_piscine_pro/models/subscription.dart';
import 'package:ac_piscine_pro/services/billing_provider.dart';
import 'package:ac_piscine_pro/services/billing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BillingService parses backend plans, subscription and entitlements',
      () async {
    final snapshot = await BillingService.fetchSnapshot(
      session: const AuthSession(
        endpoint: 'https://sync.example.com',
        token: 'token',
        userId: 'user_1',
        organizationId: 'org_demo',
        email: 'user@example.test',
        fullName: 'User Demo',
        role: 'admin',
      ),
      transport: ({
        required String endpoint,
        required String token,
      }) async {
        expect(endpoint, contains('/v2/billing/entitlements'));
        expect(token, 'token');
        return {
          'data': {
            'plans': [
              {
                'id': 'free',
                'displayName': 'Free',
                'clientLimit': 10,
                'entitlements': const [
                  {'flag': 'cloudSync', 'enabled': false},
                ],
              },
              {
                'id': 'pro',
                'displayName': 'Pro',
                'clientLimit': null,
                'entitlements': const [
                  {'flag': 'cloudSync', 'enabled': true},
                ],
              },
            ],
            'subscription': {
              'planId': 'pro',
              'status': 'active',
              'startedAtIso': '2026-04-17T10:00:00Z',
              'endedAtIso': '2026-05-17T10:00:00Z',
              'updatedAtIso': '2026-04-17T10:00:00Z',
            },
            'entitlements': const [
              {'flag': 'cloudSync', 'enabled': true},
              {'flag': 'pdfExport', 'enabled': true},
              {'flag': 'teamMembers', 'enabled': true},
              {'flag': 'unlimitedClients', 'enabled': true},
            ],
          },
        };
      },
    );

    expect(snapshot, isA<BillingSnapshot>());
    expect(snapshot!.plans, hasLength(2));
    expect(snapshot.subscription.planId, 'pro');
    expect(snapshot.subscription.endedAtIso, '2026-05-17T10:00:00Z');
    expect(snapshot.subscription.plan.id, 'pro');
    expect(snapshot.subscription.entitlements, hasLength(4));
    expect(
      snapshot.subscription.entitlements.any(
        (item) => item.flag.name == 'pdfExport' && item.enabled,
      ),
      isTrue,
    );
  });

  test('BillingService reconciles a completed native purchase with backend',
      () async {
    final provider = _FakeBillingProvider(
      checkoutResult: BillingResult(
        status: BillingResultStatus.completed,
        message: 'Purchase completed.',
        shouldRefreshEntitlements: true,
        metadata: {
          'purchases': [
            {
              'provider': 'app_store',
              'platform': 'ios',
              'productId': 'com.hydrazur.pro.monthly',
              'purchaseId': 'ios_tx_001',
              'status': 'purchased',
              'transactionDateIso': '2026-04-17T10:00:00Z',
            },
          ],
        },
      ),
    );

    var reconcileCalled = false;
    final result = await BillingService.beginUpgradeCheckout(
      subscription: Subscription.defaults(),
      session: const AuthSession(
        endpoint: 'https://sync.example.com',
        token: 'token',
        userId: 'user_1',
        organizationId: 'org_demo',
        email: 'user@example.test',
        fullName: 'User Demo',
        role: 'admin',
      ),
      provider: provider,
      mutationTransport: ({
        required String method,
        required String endpoint,
        required String token,
        Map<String, dynamic>? payload,
      }) async {
        reconcileCalled = true;
        expect(method, 'POST');
        expect(endpoint, contains('/v2/billing/mobile/reconcile'));
        expect(token, 'token');
        expect(payload?['provider'], 'app_store');
        return {
          'data': {
            'snapshot': {
              'plans': [
                {
                  'id': 'pro',
                  'displayName': 'Pro',
                  'entitlements': const [
                    {'flag': 'cloudSync', 'enabled': true},
                  ],
                },
              ],
              'subscription': {
                'planId': 'pro',
                'status': 'active',
                'updatedAtIso': '2026-04-17T10:00:00Z',
                'entitlements': const [
                  {'flag': 'cloudSync', 'enabled': true},
                ],
              },
            },
          },
        };
      },
    );

    expect(reconcileCalled, isTrue);
    expect(result.status, BillingResultStatus.completed);
    expect(result.message, contains('synchronise'));
    expect(result.metadata['snapshot'], isA<Map<String, dynamic>>());
  });

  test('BillingService restorePurchases also reconciles with backend',
      () async {
    final provider = _FakeBillingProvider(
      restoreResult: BillingResult(
        status: BillingResultStatus.completed,
        message: 'Restored.',
        shouldRefreshEntitlements: true,
        metadata: {
          'purchases': [
            {
              'provider': 'play_store',
              'platform': 'android',
              'productId': 'com.hydrazur.pro.monthly',
              'purchaseId': 'gp_tx_001',
              'status': 'restored',
              'transactionDateIso': '2026-04-17T10:00:00Z',
            },
          ],
        },
      ),
    );

    var restoreCalled = false;
    final result = await BillingService.restorePurchases(
      subscription: Subscription.defaults(),
      session: const AuthSession(
        endpoint: 'https://sync.example.com',
        token: 'token',
        userId: 'user_1',
        organizationId: 'org_demo',
        email: 'user@example.test',
        fullName: 'User Demo',
        role: 'admin',
      ),
      provider: provider,
      mutationTransport: ({
        required String method,
        required String endpoint,
        required String token,
        Map<String, dynamic>? payload,
      }) async {
        restoreCalled = true;
        expect(payload?['provider'], 'play_store');
        return {
          'data': {
            'snapshot': {
              'plans': const [],
              'subscription': {
                'planId': 'pro',
                'status': 'active',
                'updatedAtIso': '2026-04-17T10:00:00Z',
              },
            },
          },
        };
      },
    );

    expect(restoreCalled, isTrue);
    expect(result.status, BillingResultStatus.completed);
  });

  test('BillingService starts a trial and parses the returned snapshot',
      () async {
    final snapshot = await BillingService.startTrial(
      session: const AuthSession(
        endpoint: 'https://sync.example.com',
        token: 'token',
        userId: 'user_1',
        organizationId: 'org_demo',
        email: 'user@example.test',
        fullName: 'User Demo',
        role: 'admin',
      ),
      mutationTransport: ({
        required String method,
        required String endpoint,
        required String token,
        Map<String, dynamic>? payload,
      }) async {
        expect(method, 'POST');
        expect(endpoint, contains('/v2/billing/trial/start'));
        expect(token, 'token');
        expect(payload?['plan_id'], 'pro');
        return {
          'data': {
            'snapshot': {
              'plans': [
                {
                  'id': 'pro',
                  'displayName': 'Pro',
                  'trialDays': 7,
                  'entitlements': const [
                    {'flag': 'cloudSync', 'enabled': true},
                  ],
                },
              ],
              'subscription': {
                'planId': 'pro',
                'status': 'trial',
                'startedAtIso': '2026-04-17T10:00:00Z',
                'endedAtIso': '2026-04-24T10:00:00Z',
                'updatedAtIso': '2026-04-17T10:00:00Z',
                'trialUsed': true,
                'entitlements': const [
                  {'flag': 'cloudSync', 'enabled': true},
                ],
              },
            },
          },
        };
      },
    );

    expect(snapshot.subscription.status, SubscriptionStatus.trial);
    expect(snapshot.subscription.trialUsed, isTrue);
    expect(snapshot.subscription.endedAtIso, '2026-04-24T10:00:00Z');
    expect(snapshot.plans.single.trialDays, 7);
  });
}

class _FakeBillingProvider implements BillingProvider {
  final BillingResult checkoutResult;
  final BillingResult restoreResult;

  const _FakeBillingProvider({
    this.checkoutResult = const BillingResult(
      status: BillingResultStatus.pendingManualAction,
      message: 'noop',
    ),
    this.restoreResult = const BillingResult(
      status: BillingResultStatus.pendingManualAction,
      message: 'noop',
    ),
  });

  @override
  String get providerKey {
    for (final candidate in [
      checkoutResult.metadata['purchases'],
      restoreResult.metadata['purchases'],
    ]) {
      if (candidate is List && candidate.isNotEmpty) {
        return (candidate.first as Map)['provider'].toString();
      }
    }
    return 'fake';
  }

  @override
  Future<BillingCheckoutSession> createCheckoutSession({
    required String planId,
    required Subscription subscription,
  }) async {
    return BillingCheckoutSession(
      sessionId: 'session_$planId',
      providerKey: providerKey,
      planId: planId,
      mode: BillingCheckoutMode.native,
      metadata: {
        'productId': 'com.hydrazur.pro.monthly',
      },
    );
  }

  @override
  Future<BillingResult> startCheckout({
    required BillingCheckoutSession session,
  }) async {
    return checkoutResult.copyWith(session: session);
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
    return restoreResult.copyWith(session: session);
  }
}
