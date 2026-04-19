import 'package:ac_piscine_pro/services/cloud_sync_service.dart';
import 'package:ac_piscine_pro/services/sync_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'LegacyCloudSyncRepository delegates push and scoped sync to legacy push transport',
      () async {
    final calls = <Map<String, dynamic>>[];
    final repository = LegacyCloudSyncRepository(
      pushTransport: ({
        required String endpoint,
        String? apiKey,
        required Map<String, dynamic> payload,
      }) async {
        calls.add({
          'endpoint': endpoint,
          'apiKey': apiKey,
          'payload': payload,
        });
        return const CloudSyncResult(
          ok: true,
          message: 'ok',
        );
      },
    );

    await repository.push(
      endpoint: 'https://example.test/sync',
      apiKey: 'secret',
      payload: const {'clients': []},
    );
    await repository.syncClients(
      endpoint: 'https://example.test/sync',
      apiKey: 'secret',
      payload: const {'clients': []},
    );
    await repository.syncInterventions(
      endpoint: 'https://example.test/sync',
      apiKey: 'secret',
      payload: const {'clients': []},
    );
    await repository.syncDocuments(
      endpoint: 'https://example.test/sync',
      apiKey: 'secret',
      payload: const {'clients': []},
    );
    await repository.syncAttachments(
      endpoint: 'https://example.test/sync',
      apiKey: 'secret',
      payload: const {'clients': []},
    );

    expect(calls, hasLength(5));
    expect(
      calls.every((call) => call['endpoint'] == 'https://example.test/sync'),
      isTrue,
    );
    expect(calls.every((call) => call['apiKey'] == 'secret'), isTrue);
  });

  test('LegacyCloudSyncRepository delegates pull to legacy pull transport',
      () async {
    final calls = <Map<String, dynamic>>[];
    final repository = LegacyCloudSyncRepository(
      pullTransport: ({
        required String endpoint,
        String? apiKey,
      }) async {
        calls.add({
          'endpoint': endpoint,
          'apiKey': apiKey,
        });
        return const CloudSyncResult(
          ok: true,
          message: 'pulled',
          payload: {'clients': []},
        );
      },
    );

    final result = await repository.pull(
      endpoint: 'https://example.test/sync',
      apiKey: 'secret',
    );

    expect(result.ok, isTrue);
    expect(calls, [
      {
        'endpoint': 'https://example.test/sync',
        'apiKey': 'secret',
      },
    ]);
  });
}
