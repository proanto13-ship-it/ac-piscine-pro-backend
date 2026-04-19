import 'package:ac_piscine_pro/models/billing_result.dart';
import 'package:ac_piscine_pro/models/subscription.dart';
import 'package:ac_piscine_pro/services/dev_billing_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DevBillingProvider returns manual activation result', () async {
    const provider = DevBillingProvider();

    final session = await provider.createCheckoutSession(
      planId: 'pro',
      subscription: Subscription.defaults(),
    );
    final result = await provider.startCheckout(session: session);

    expect(session.providerKey, 'dev_manual');
    expect(session.planId, 'pro');
    expect(result.status, BillingResultStatus.pendingManualAction);
    expect(result.message, contains('Pendant la bêta'));
    expect(result.message, contains('activer l’accès Pro'));
    expect(result.shouldRefreshEntitlements, isFalse);
  });
}
