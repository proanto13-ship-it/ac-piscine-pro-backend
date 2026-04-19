import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/cloud_sync_settings.dart';
import '../models/sync_queue_item.dart';
import '../models/sync_queue_state.dart';
import 'app_environment.dart';
import 'cloud_sync_service.dart';
import 'local_storage_service.dart';

typedef SyncQueueReadTransport = Future<Map<String, dynamic>?> Function(
  String name,
);
typedef SyncQueueWriteTransport = Future<void> Function(
  String name,
  Object value,
);
typedef SyncQueueExecutor = Future<CloudSyncResult> Function(
    SyncQueueItem item);
typedef SyncQueueResultCallback = Future<void> Function(
  SyncQueueItem item,
  CloudSyncResult result,
);

class SyncQueueSnapshot {
  final SyncQueueState state;
  final List<SyncQueueItem> items;
  final String lastMessage;
  final String updatedAtIso;

  const SyncQueueSnapshot({
    required this.state,
    required this.items,
    required this.lastMessage,
    required this.updatedAtIso,
  });

  factory SyncQueueSnapshot.defaults() {
    return const SyncQueueSnapshot(
      state: SyncQueueState.idle,
      items: [],
      lastMessage: '',
      updatedAtIso: '',
    );
  }

  factory SyncQueueSnapshot.fromJson(Map<String, dynamic> json) {
    return SyncQueueSnapshot(
      state: SyncQueueState.fromJson(json['state']),
      items: ((json['items'] ?? const []) as List)
          .map(
            (item) => SyncQueueItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      lastMessage: json['lastMessage']?.toString() ?? '',
      updatedAtIso: json['updatedAtIso']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'state': state.name,
        'items': items.map((item) => item.toJson()).toList(),
        'lastMessage': lastMessage,
        'updatedAtIso': updatedAtIso,
      };

  SyncQueueSnapshot copyWith({
    SyncQueueState? state,
    List<SyncQueueItem>? items,
    String? lastMessage,
    String? updatedAtIso,
  }) {
    return SyncQueueSnapshot(
      state: state ?? this.state,
      items: items ?? this.items,
      lastMessage: lastMessage ?? this.lastMessage,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }

  int get pendingCount => items.length;

  String get nextRetryAtIso {
    final scheduled = items
        .map((item) => item.nextAttemptAtIso)
        .where((value) => value.trim().isNotEmpty)
        .toList()
      ..sort();
    return scheduled.isEmpty ? '' : scheduled.first;
  }
}

class SyncQueueService {
  static String get fileName => AppEnvironment.storageName('sync_queue.json');
  static final ValueNotifier<SyncQueueSnapshot> current =
      ValueNotifier(SyncQueueSnapshot.defaults());
  static bool _processing = false;

  static Future<SyncQueueSnapshot> load({
    SyncQueueReadTransport readTransport = LocalStorageService.readJsonMap,
  }) async {
    final stored = await readTransport(fileName);
    current.value = stored == null
        ? SyncQueueSnapshot.defaults()
        : SyncQueueSnapshot.fromJson(stored);
    return current.value;
  }

  static Future<void> replace(
    SyncQueueSnapshot snapshot, {
    SyncQueueWriteTransport writeTransport = LocalStorageService.writeJson,
  }) async {
    final normalized = snapshot.copyWith(
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    current.value = normalized;
    await writeTransport(fileName, normalized.toJson());
  }

  static void resetInMemory() {
    _processing = false;
    current.value = SyncQueueSnapshot.defaults();
  }

  static Future<SyncQueueItem> enqueuePush({
    required String endpoint,
    required CloudSyncMode syncMode,
    SyncQueueWriteTransport writeTransport = LocalStorageService.writeJson,
  }) {
    return _enqueue(
      type: SyncQueueOperationType.push,
      endpoint: endpoint,
      syncMode: syncMode,
      sinceIso: '',
      writeTransport: writeTransport,
    );
  }

  static Future<SyncQueueItem> enqueuePull({
    required String endpoint,
    required CloudSyncMode syncMode,
    String sinceIso = '',
    SyncQueueWriteTransport writeTransport = LocalStorageService.writeJson,
  }) {
    return _enqueue(
      type: SyncQueueOperationType.pull,
      endpoint: endpoint,
      syncMode: syncMode,
      sinceIso: sinceIso,
      writeTransport: writeTransport,
    );
  }

  static Future<SyncQueueSnapshot> processPending({
    required SyncQueueExecutor executor,
    SyncQueueResultCallback? onSuccess,
    SyncQueueResultCallback? onFailure,
    bool forceRetryNow = false,
    SyncQueueWriteTransport writeTransport = LocalStorageService.writeJson,
  }) async {
    if (_processing) {
      return current.value;
    }
    final snapshot = current.value;
    if (snapshot.items.isEmpty) {
      if (snapshot.state == SyncQueueState.pending ||
          snapshot.state == SyncQueueState.syncing) {
        await replace(
          snapshot.copyWith(
            state: SyncQueueState.idle,
            lastMessage: snapshot.lastMessage,
          ),
          writeTransport: writeTransport,
        );
      }
      return current.value;
    }

    final now = DateTime.now().toUtc();
    final dueItems = snapshot.items.where((item) {
      if (forceRetryNow) {
        return true;
      }
      final nextRetry = DateTime.tryParse(item.nextAttemptAtIso);
      return nextRetry == null || !nextRetry.isAfter(now);
    }).toList();

    if (dueItems.isEmpty) {
      await replace(
        snapshot.copyWith(
          state: snapshot.state == SyncQueueState.failed ||
                  snapshot.state == SyncQueueState.partialFailure
              ? snapshot.state
              : SyncQueueState.pending,
        ),
        writeTransport: writeTransport,
      );
      return current.value;
    }

    _processing = true;
    await replace(
      snapshot.copyWith(
        state: SyncQueueState.syncing,
        lastMessage: 'Synchronisation en cours...',
      ),
      writeTransport: writeTransport,
    );

    var updatedItems = List<SyncQueueItem>.from(snapshot.items);
    var successCount = 0;
    var failureCount = 0;
    var lastMessage = snapshot.lastMessage;

    try {
      for (final item in dueItems) {
        final result = await executor(item);
        lastMessage = result.message;
        if (result.ok) {
          successCount += 1;
          updatedItems.removeWhere((entry) => entry.id == item.id);
          if (onSuccess != null) {
            await onSuccess(item, result);
          }
          continue;
        }

        failureCount += 1;
        final nextAttemptCount = item.attemptCount + 1;
        final retryAt = now.add(_backoffForAttempt(nextAttemptCount));
        updatedItems = updatedItems
            .map(
              (entry) => entry.id != item.id
                  ? entry
                  : entry.copyWith(
                      attemptCount: nextAttemptCount,
                      nextAttemptAtIso: retryAt.toIso8601String(),
                      lastError: result.message,
                      lastMessage: result.message,
                    ),
            )
            .toList();
        if (onFailure != null) {
          await onFailure(item, result);
        }
      }
    } finally {
      _processing = false;
    }

    final nextState = _resolveState(
      items: updatedItems,
      successCount: successCount,
      failureCount: failureCount,
    );
    await replace(
      current.value.copyWith(
        state: nextState,
        items: updatedItems,
        lastMessage: lastMessage,
      ),
      writeTransport: writeTransport,
    );
    return current.value;
  }

  static Future<SyncQueueSnapshot> retryNow({
    required SyncQueueExecutor executor,
    SyncQueueResultCallback? onSuccess,
    SyncQueueResultCallback? onFailure,
    SyncQueueWriteTransport writeTransport = LocalStorageService.writeJson,
  }) async {
    final resetItems = current.value.items
        .map(
          (item) => item.copyWith(
            nextAttemptAtIso: '',
          ),
        )
        .toList();
    await replace(
      current.value.copyWith(
        state:
            resetItems.isEmpty ? SyncQueueState.idle : SyncQueueState.pending,
        items: resetItems,
      ),
      writeTransport: writeTransport,
    );
    return processPending(
      executor: executor,
      onSuccess: onSuccess,
      onFailure: onFailure,
      forceRetryNow: true,
      writeTransport: writeTransport,
    );
  }

  static Future<SyncQueueItem> _enqueue({
    required SyncQueueOperationType type,
    required String endpoint,
    required CloudSyncMode syncMode,
    required String sinceIso,
    required SyncQueueWriteTransport writeTransport,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final item = SyncQueueItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      syncMode: syncMode,
      endpoint: endpoint,
      enqueuedAtIso: nowIso,
      nextAttemptAtIso: '',
      attemptCount: 0,
      lastError: '',
      lastMessage: '',
      sinceIso: sinceIso,
    );

    await replace(
      current.value.copyWith(
        state: SyncQueueState.pending,
        items: [
          ...current.value.items,
          item,
        ],
        lastMessage: type == SyncQueueOperationType.push
            ? 'Envoi ajoute a la file.'
            : 'Recuperation ajoutee a la file.',
      ),
      writeTransport: writeTransport,
    );
    return item;
  }

  static SyncQueueState _resolveState({
    required List<SyncQueueItem> items,
    required int successCount,
    required int failureCount,
  }) {
    if (items.isEmpty) {
      if (successCount > 0) {
        return SyncQueueState.success;
      }
      return SyncQueueState.idle;
    }
    if (failureCount > 0 && successCount > 0) {
      return SyncQueueState.partialFailure;
    }
    if (failureCount > 0) {
      return SyncQueueState.failed;
    }
    return SyncQueueState.pending;
  }

  static Duration _backoffForAttempt(int attemptCount) {
    final safeAttempt = attemptCount <= 0 ? 1 : attemptCount;
    final seconds = switch (safeAttempt) {
      1 => 2,
      2 => 5,
      3 => 10,
      4 => 20,
      _ => 30,
    };
    return Duration(seconds: seconds);
  }
}
