import 'cloud_sync_settings.dart';

enum SyncQueueOperationType {
  push,
  pull;

  static SyncQueueOperationType fromJson(dynamic raw) {
    switch (raw?.toString()) {
      case 'pull':
        return SyncQueueOperationType.pull;
      case 'push':
      default:
        return SyncQueueOperationType.push;
    }
  }
}

class SyncQueueItem {
  final String id;
  final SyncQueueOperationType type;
  final CloudSyncMode syncMode;
  final String endpoint;
  final String enqueuedAtIso;
  final String nextAttemptAtIso;
  final int attemptCount;
  final String lastError;
  final String lastMessage;
  final String sinceIso;

  const SyncQueueItem({
    required this.id,
    required this.type,
    required this.syncMode,
    required this.endpoint,
    required this.enqueuedAtIso,
    required this.nextAttemptAtIso,
    required this.attemptCount,
    required this.lastError,
    required this.lastMessage,
    required this.sinceIso,
  });

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id']?.toString() ?? '',
      type: SyncQueueOperationType.fromJson(json['type']),
      syncMode: CloudSyncMode.fromJson(json['syncMode']),
      endpoint: json['endpoint']?.toString() ?? '',
      enqueuedAtIso: json['enqueuedAtIso']?.toString() ?? '',
      nextAttemptAtIso: json['nextAttemptAtIso']?.toString() ?? '',
      attemptCount: json['attemptCount'] is int
          ? json['attemptCount'] as int
          : int.tryParse(json['attemptCount']?.toString() ?? '') ?? 0,
      lastError: json['lastError']?.toString() ?? '',
      lastMessage: json['lastMessage']?.toString() ?? '',
      sinceIso: json['sinceIso']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'syncMode': syncMode.name,
        'endpoint': endpoint,
        'enqueuedAtIso': enqueuedAtIso,
        'nextAttemptAtIso': nextAttemptAtIso,
        'attemptCount': attemptCount,
        'lastError': lastError,
        'lastMessage': lastMessage,
        'sinceIso': sinceIso,
      };

  SyncQueueItem copyWith({
    String? id,
    SyncQueueOperationType? type,
    CloudSyncMode? syncMode,
    String? endpoint,
    String? enqueuedAtIso,
    String? nextAttemptAtIso,
    int? attemptCount,
    String? lastError,
    String? lastMessage,
    String? sinceIso,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      type: type ?? this.type,
      syncMode: syncMode ?? this.syncMode,
      endpoint: endpoint ?? this.endpoint,
      enqueuedAtIso: enqueuedAtIso ?? this.enqueuedAtIso,
      nextAttemptAtIso: nextAttemptAtIso ?? this.nextAttemptAtIso,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      lastMessage: lastMessage ?? this.lastMessage,
      sinceIso: sinceIso ?? this.sinceIso,
    );
  }

  bool get hasScheduledRetry => nextAttemptAtIso.trim().isNotEmpty;
}
