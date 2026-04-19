enum SyncQueueState {
  idle,
  pending,
  syncing,
  success,
  partialFailure,
  failed;

  static SyncQueueState fromJson(dynamic raw) {
    switch (raw?.toString()) {
      case 'pending':
        return SyncQueueState.pending;
      case 'syncing':
        return SyncQueueState.syncing;
      case 'success':
        return SyncQueueState.success;
      case 'partialFailure':
      case 'partial_failure':
        return SyncQueueState.partialFailure;
      case 'failed':
        return SyncQueueState.failed;
      case 'idle':
      default:
        return SyncQueueState.idle;
    }
  }
}
