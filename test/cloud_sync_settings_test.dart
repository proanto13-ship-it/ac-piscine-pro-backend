import 'package:flutter_test/flutter_test.dart';

import 'package:ac_piscine_pro/models/cloud_sync_settings.dart';

void main() {
  group('CloudSyncSettings', () {
    test('ignore apiKey in fromJson but can extract legacy key', () {
      final json = {
        'enabled': true,
        'endpoint': 'https://sync.example.com',
        'apiKey': 'secret-token',
        'syncMode': 'v2',
        'lastSyncStatus': 'ok',
      };

      final settings = CloudSyncSettings.fromJson(json);

      expect(CloudSyncSettings.extractLegacyApiKey(json), 'secret-token');
      expect(settings.enabled, isTrue);
      expect(settings.endpoint, 'https://sync.example.com');
      expect(settings.syncMode, CloudSyncMode.v2);
      expect(settings.lastSyncStatus, 'ok');
    });

    test('toJson never serializes apiKey', () {
      final settings = CloudSyncSettings(
        enabled: true,
        autoPrepare: false,
        syncMode: CloudSyncMode.legacy,
        endpoint: 'https://sync.example.com',
        lastPreparedAtIso: '2026-01-01T00:00:00',
        lastPushedAtIso: '',
        lastPulledAtIso: '',
        lastSyncStatus: 'ok',
      );

      final json = settings.toJson();

      expect(json.containsKey('apiKey'), isFalse);
      expect(json['endpoint'], 'https://sync.example.com');
    });

    test('defaults to legacy sync mode for older JSON', () {
      final settings = CloudSyncSettings.fromJson({
        'enabled': true,
        'endpoint': 'https://sync.example.com',
      });

      expect(settings.syncMode, CloudSyncMode.legacy);
    });
  });
}
