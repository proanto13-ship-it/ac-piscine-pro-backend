import 'package:flutter_test/flutter_test.dart';

import 'package:ac_piscine_pro/models/cloud_sync_settings.dart';
import 'package:ac_piscine_pro/models/subscription.dart';
import 'package:ac_piscine_pro/services/demo_data_service.dart';

void main() {
  test('buildDemoPayload returns realistic local demo snapshot', () async {
    final savedFiles = <String>[];
    final payload = await DemoDataService.buildDemoPayload(
      now: DateTime.utc(2026, 4, 17, 10),
      binarySaveTransport: (folderName, fileName, bytes) async {
        savedFiles.add('$folderName/$fileName:${bytes.length}');
        return '/tmp/$folderName/$fileName';
      },
    );

    final clients = List<Map<String, dynamic>>.from(payload['clients'] as List);
    final companyProfile =
        Map<String, dynamic>.from(payload['companyProfile'] as Map);
    final cloudSyncSettings = CloudSyncSettings.fromJson(
      Map<String, dynamic>.from(payload['cloudSyncSettings'] as Map),
    );
    final subscription = Subscription.fromJson(
      Map<String, dynamic>.from(payload['subscription'] as Map),
    );

    expect(companyProfile['companyName'], 'HydrAzur Pilotage');
    expect(clients.length, inInclusiveRange(3, 5));
    expect(
      clients
          .map((client) => List<dynamic>.from(client['interventions'] as List))
          .expand((items) => items)
          .length,
      inInclusiveRange(5, 10),
    );
    expect(
      clients
          .map(
            (client) => List<dynamic>.from(
              client['financialDocuments'] as List,
            ),
          )
          .expand((items) => items)
          .length,
      greaterThanOrEqualTo(3),
    );
    expect(savedFiles.length, 3);
    expect(cloudSyncSettings.enabled, isFalse);
    expect(cloudSyncSettings.syncMode, CloudSyncMode.legacy);
    expect(subscription.planId, 'pro');
    expect(subscription.status, SubscriptionStatus.active);
  });
}
