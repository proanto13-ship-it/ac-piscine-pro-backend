import 'package:ac_piscine_pro/models/cloud_sync_settings.dart';
import 'package:ac_piscine_pro/models/sync_queue_state.dart';
import 'package:ac_piscine_pro/services/cloud_sync_service.dart';
import 'package:ac_piscine_pro/services/sync_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic>? storedSnapshot;

  Future<Map<String, dynamic>?> readTransport(String _) async => storedSnapshot;

  Future<void> writeTransport(String _, Object value) async {
    storedSnapshot = Map<String, dynamic>.from(value as Map);
  }

  setUp(() {
    storedSnapshot = null;
    SyncQueueService.resetInMemory();
  });

  test('successful processing clears the queue and persists success state',
      () async {
    await SyncQueueService.load(readTransport: readTransport);
    await SyncQueueService.enqueuePush(
      endpoint: 'https://example.test/sync',
      syncMode: CloudSyncMode.legacy,
      writeTransport: writeTransport,
    );

    var executionCount = 0;
    final snapshot = await SyncQueueService.processPending(
      executor: (item) async {
        executionCount += 1;
        expect(item.type.name, 'push');
        return const CloudSyncResult(
          ok: true,
          message: 'Synchronisation terminee.',
        );
      },
      writeTransport: writeTransport,
    );

    expect(executionCount, 1);
    expect(snapshot.state, SyncQueueState.success);
    expect(snapshot.items, isEmpty);
    expect(storedSnapshot?['state'], 'success');
    expect(storedSnapshot?['items'], isEmpty);
  });

  test('failed operations survive reload and can be retried later', () async {
    await SyncQueueService.load(readTransport: readTransport);
    await SyncQueueService.enqueuePull(
      endpoint: 'https://example.test/v2',
      syncMode: CloudSyncMode.v2,
      sinceIso: '2026-04-17T08:00:00Z',
      writeTransport: writeTransport,
    );

    final failedSnapshot = await SyncQueueService.processPending(
      executor: (_) async => const CloudSyncResult(
        ok: false,
        message: 'Connexion instable.',
      ),
      writeTransport: writeTransport,
    );

    expect(failedSnapshot.state, SyncQueueState.failed);
    expect(failedSnapshot.items, hasLength(1));
    expect(failedSnapshot.items.single.attemptCount, 1);
    expect(failedSnapshot.items.single.nextAttemptAtIso, isNotEmpty);
    expect(storedSnapshot?['items'], hasLength(1));

    SyncQueueService.resetInMemory();
    final reloadedSnapshot =
        await SyncQueueService.load(readTransport: readTransport);
    expect(reloadedSnapshot.state, SyncQueueState.failed);
    expect(reloadedSnapshot.items, hasLength(1));
    expect(reloadedSnapshot.items.single.sinceIso, '2026-04-17T08:00:00Z');

    var retried = 0;
    final retriedSnapshot = await SyncQueueService.retryNow(
      executor: (_) async {
        retried += 1;
        return const CloudSyncResult(
          ok: true,
          message: 'Synchronisation reprise.',
        );
      },
      writeTransport: writeTransport,
    );

    expect(retried, 1);
    expect(retriedSnapshot.state, SyncQueueState.success);
    expect(retriedSnapshot.items, isEmpty);
    expect(storedSnapshot?['state'], 'success');
  });
}
