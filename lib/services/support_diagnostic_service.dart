import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/auth_session.dart';
import '../models/cloud_sync_settings.dart';
import 'app_environment.dart';
import 'app_logger.dart';
import 'local_storage_service.dart';

enum SupportRequestKind {
  bugReport,
  feedback,
  diagnostic,
}

enum SupportExportFormat {
  json,
  zip,
}

typedef SupportTextSaveTransport = Future<String> Function(
  String folderName,
  String fileName,
  String content,
);

typedef SupportBinarySaveTransport = Future<String> Function(
  String folderName,
  String fileName,
  List<int> bytes,
);

class SupportAppInfo {
  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;
  final String platform;
  final String environment;

  const SupportAppInfo({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.environment,
  });

  Map<String, dynamic> toJson() => {
        'appName': appName,
        'packageName': packageName,
        'version': version,
        'buildNumber': buildNumber,
        'platform': platform,
        'environment': environment,
      };
}

class SupportDiagnosticService {
  static String get _folderName => AppEnvironment.folderName('support_exports');

  static Future<SupportAppInfo> loadAppInfo({
    Future<PackageInfo> Function()? packageInfoLoader,
    String? endpoint,
  }) async {
    final packageInfo =
        await (packageInfoLoader ?? PackageInfo.fromPlatform).call();
    return SupportAppInfo(
      appName: AppEnvironment.appDisplayName(packageInfo.appName),
      packageName: packageInfo.packageName,
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      platform: _platformLabel(),
      environment: resolveEnvironment(endpoint: endpoint),
    );
  }

  static String resolveEnvironment({String? endpoint}) {
    if (AppEnvironment.isExplicitlyConfigured) {
      return AppEnvironment.name;
    }

    final value = (endpoint ?? '').trim().toLowerCase();
    if (value.contains('staging') || value.contains('preprod')) {
      return 'staging';
    }
    if (value.contains('localhost') ||
        value.contains('127.0.0.1') ||
        value.contains('10.0.2.2') ||
        value.contains('dev') ||
        value.contains('demo')) {
      return 'dev';
    }
    return AppEnvironment.name;
  }

  static Future<List<Map<String, dynamic>>> loadRecentLogs({
    int maxRecords = 80,
    Future<List<AppLogRecord>> Function({int maxRecords})? logsLoader,
  }) async {
    final records = await (logsLoader ?? AppLogger.readRecentRecords)(
      maxRecords: maxRecords,
    );
    return records.map((record) => _sanitizeRecord(record).toJson()).toList();
  }

  static Map<String, dynamic> buildPayload({
    required SupportRequestKind kind,
    required SupportAppInfo appInfo,
    required CloudSyncSettings cloudSyncSettings,
    required List<Map<String, dynamic>> recentLogs,
    required Map<String, dynamic> dataSummary,
    AuthSession? session,
    String? userMessage,
  }) {
    return {
      'kind': kind.name,
      'createdAtIso': DateTime.now().toUtc().toIso8601String(),
      'app': appInfo.toJson(),
      'sync': _sanitizeMap({
        'enabled': cloudSyncSettings.enabled,
        'autoPrepare': cloudSyncSettings.autoPrepare,
        'syncMode': cloudSyncSettings.syncMode.name,
        'endpoint': cloudSyncSettings.endpoint,
        'lastPreparedAtIso': cloudSyncSettings.lastPreparedAtIso,
        'lastPushedAtIso': cloudSyncSettings.lastPushedAtIso,
        'lastPulledAtIso': cloudSyncSettings.lastPulledAtIso,
        'lastSyncStatus': cloudSyncSettings.lastSyncStatus,
      }),
      'session': session == null
          ? null
          : {
              'organizationId': session.organizationId,
              'userId': session.userId,
              'role': session.role,
              'endpoint': session.endpoint,
            },
      'dataSummary': _sanitizeMap(dataSummary),
      'recentLogs': recentLogs.map(_sanitizeMap).toList(),
      if (userMessage != null && userMessage.trim().isNotEmpty)
        'userMessage': userMessage.trim(),
    };
  }

  static Future<String> exportPayload({
    required Map<String, dynamic> payload,
    required SupportRequestKind kind,
    required SupportExportFormat format,
    SupportTextSaveTransport textSaveTransport =
        LocalStorageService.saveTextFile,
    SupportBinarySaveTransport binarySaveTransport =
        LocalStorageService.saveBinary,
  }) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileBaseName = 'support_${kind.name}_$timestamp';
    final jsonPayload = const JsonEncoder.withIndent('  ').convert(payload);

    switch (format) {
      case SupportExportFormat.json:
        return textSaveTransport(
          _folderName,
          '$fileBaseName.json',
          jsonPayload,
        );
      case SupportExportFormat.zip:
        final archive = Archive()
          ..addFile(
            ArchiveFile.string('diagnostic.json', jsonPayload),
          )
          ..addFile(
            ArchiveFile.string(
              'README.txt',
              'Support package exporte depuis HydrAzur Pro. Aucun secret ne doit etre inclus.',
            ),
          );
        final bytes = ZipEncoder().encode(archive) ?? <int>[];
        return binarySaveTransport(
          _folderName,
          '$fileBaseName.zip',
          bytes,
        );
    }
  }

  static String _platformLabel() {
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return defaultTargetPlatform.name;
    }
  }

  static AppLogRecord _sanitizeRecord(AppLogRecord record) {
    return AppLogRecord(
      timestampIso: record.timestampIso,
      level: record.level,
      category: record.category,
      message: record.message,
      data: _sanitizeMap(record.data),
    );
  }

  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    data.forEach((key, value) {
      if (_isSensitiveKey(key)) {
        sanitized[key] = '[REDACTED]';
        return;
      }
      sanitized[key] = _sanitizeValue(value);
    });
    return sanitized;
  }

  static dynamic _sanitizeValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return _sanitizeMap(value);
    }
    if (value is Map) {
      return _sanitizeMap(Map<String, dynamic>.from(value));
    }
    if (value is List) {
      return value.map(_sanitizeValue).toList();
    }
    if (value is String && _looksSensitive(value)) {
      return '[REDACTED]';
    }
    return value;
  }

  static bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase();
    return normalized.contains('token') ||
        normalized.contains('apikey') ||
        normalized.contains('api_key') ||
        normalized.contains('password') ||
        normalized.contains('secret') ||
        normalized.contains('authorization') ||
        normalized.contains('cookie');
  }

  static bool _looksSensitive(String value) {
    final normalized = value.toLowerCase();
    return normalized.startsWith('bearer ') ||
        normalized.contains('api_key') ||
        normalized.contains('token=') ||
        normalized.contains('password=');
  }
}
