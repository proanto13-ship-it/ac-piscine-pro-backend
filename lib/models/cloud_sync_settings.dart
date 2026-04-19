import '../services/app_environment.dart';

enum CloudSyncMode {
  legacy,
  v2;

  static CloudSyncMode fromJson(dynamic raw) {
    switch (raw?.toString()) {
      case 'v2':
        return CloudSyncMode.v2;
      case 'legacy':
      default:
        return CloudSyncMode.legacy;
    }
  }
}

class CloudSyncSettings {
  final bool enabled;
  final bool autoPrepare;
  final CloudSyncMode syncMode;
  final String endpoint;
  final String lastPreparedAtIso;
  final String lastPushedAtIso;
  final String lastPulledAtIso;
  final String lastSyncStatus;

  const CloudSyncSettings({
    required this.enabled,
    required this.autoPrepare,
    required this.syncMode,
    required this.endpoint,
    required this.lastPreparedAtIso,
    required this.lastPushedAtIso,
    required this.lastPulledAtIso,
    required this.lastSyncStatus,
  });

  factory CloudSyncSettings.defaults() {
    return CloudSyncSettings(
      enabled: false,
      autoPrepare: false,
      syncMode: CloudSyncMode.legacy,
      endpoint: AppEnvironment.defaultApiBaseUrl,
      lastPreparedAtIso: '',
      lastPushedAtIso: '',
      lastPulledAtIso: '',
      lastSyncStatus: '',
    );
  }

  factory CloudSyncSettings.fromJson(Map<String, dynamic> json) {
    final defaults = CloudSyncSettings.defaults();
    final rawEndpoint = json['endpoint']?.toString() ?? '';
    return CloudSyncSettings(
      enabled: json['enabled'] ?? defaults.enabled,
      autoPrepare: json['autoPrepare'] ?? defaults.autoPrepare,
      syncMode: CloudSyncMode.fromJson(json['syncMode']),
      endpoint: rawEndpoint.trim().isEmpty ? defaults.endpoint : rawEndpoint,
      lastPreparedAtIso:
          json['lastPreparedAtIso'] ?? defaults.lastPreparedAtIso,
      lastPushedAtIso: json['lastPushedAtIso'] ?? defaults.lastPushedAtIso,
      lastPulledAtIso: json['lastPulledAtIso'] ?? defaults.lastPulledAtIso,
      lastSyncStatus: json['lastSyncStatus'] ?? defaults.lastSyncStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'autoPrepare': autoPrepare,
        'syncMode': syncMode.name,
        'endpoint': endpoint,
        'lastPreparedAtIso': lastPreparedAtIso,
        'lastPushedAtIso': lastPushedAtIso,
        'lastPulledAtIso': lastPulledAtIso,
        'lastSyncStatus': lastSyncStatus,
      };

  CloudSyncSettings copyWith({
    bool? enabled,
    bool? autoPrepare,
    CloudSyncMode? syncMode,
    String? endpoint,
    String? lastPreparedAtIso,
    String? lastPushedAtIso,
    String? lastPulledAtIso,
    String? lastSyncStatus,
  }) {
    return CloudSyncSettings(
      enabled: enabled ?? this.enabled,
      autoPrepare: autoPrepare ?? this.autoPrepare,
      syncMode: syncMode ?? this.syncMode,
      endpoint: endpoint ?? this.endpoint,
      lastPreparedAtIso: lastPreparedAtIso ?? this.lastPreparedAtIso,
      lastPushedAtIso: lastPushedAtIso ?? this.lastPushedAtIso,
      lastPulledAtIso: lastPulledAtIso ?? this.lastPulledAtIso,
      lastSyncStatus: lastSyncStatus ?? this.lastSyncStatus,
    );
  }

  static String extractLegacyApiKey(Map<String, dynamic> json) {
    return json['apiKey']?.toString() ?? '';
  }
}
