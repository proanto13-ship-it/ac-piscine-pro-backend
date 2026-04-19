import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:ac_piscine_pro/models/auth_session.dart';
import 'package:ac_piscine_pro/models/cloud_sync_settings.dart';
import 'package:ac_piscine_pro/services/app_logger.dart';
import 'package:ac_piscine_pro/services/support_diagnostic_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('support diagnostic payload redacts secrets and keeps required fields',
      () async {
    final logs = await SupportDiagnosticService.loadRecentLogs(
      logsLoader: ({int maxRecords = 80}) async => [
        const AppLogRecord(
          timestampIso: '2026-04-17T10:00:00Z',
          level: AppLogLevel.error,
          category: 'sync',
          message: 'sync_failed',
          data: {
            'token': 'secret-token',
            'organizationId': 'org_demo',
            'details': {
              'apiKey': 'secret-api-key',
            },
          },
        ),
      ],
    );

    final payload = SupportDiagnosticService.buildPayload(
      kind: SupportRequestKind.bugReport,
      appInfo: const SupportAppInfo(
        appName: 'HydrAzur Pro',
        packageName: 'ac_piscine_pro',
        version: '1.2.3',
        buildNumber: '45',
        platform: 'ios',
        environment: 'staging',
      ),
      cloudSyncSettings: CloudSyncSettings.defaults().copyWith(
        enabled: true,
        syncMode: CloudSyncMode.v2,
        endpoint: 'https://staging.example.test',
        lastSyncStatus: 'Erreur reseau',
      ),
      recentLogs: logs,
      dataSummary: const {
        'clientsCount': 4,
        'sessionAvailable': true,
      },
      session: const AuthSession(
        endpoint: 'https://staging.example.test',
        token: 'top-secret-token',
        userId: 'user_1',
        organizationId: 'org_demo',
        email: 'user@example.test',
        fullName: 'User Demo',
        role: 'admin',
      ),
      userMessage: 'La sync a plante sur une intervention photo.',
    );

    expect(payload['kind'], 'bugReport');
    expect((payload['app'] as Map<String, dynamic>)['buildNumber'], '45');
    expect((payload['session'] as Map<String, dynamic>)['organizationId'],
        'org_demo');
    expect((payload['session'] as Map<String, dynamic>).containsKey('token'),
        isFalse);
    expect(
      (((payload['recentLogs'] as List).first as Map<String, dynamic>)['data']
          as Map<String, dynamic>)['token'],
      '[REDACTED]',
    );
    expect(
      ((((payload['recentLogs'] as List).first as Map<String, dynamic>)['data']
              as Map<String, dynamic>)['details']
          as Map<String, dynamic>)['apiKey'],
      '[REDACTED]',
    );
  });

  test('support export zip contains diagnostic json', () async {
    List<int>? savedBytes;

    final path = await SupportDiagnosticService.exportPayload(
      payload: const {
        'kind': 'diagnostic',
        'app': {
          'version': '1.0.0',
        },
      },
      kind: SupportRequestKind.diagnostic,
      format: SupportExportFormat.zip,
      binarySaveTransport: (folderName, fileName, bytes) async {
        savedBytes = bytes;
        return '/tmp/$folderName/$fileName';
      },
    );

    expect(path, endsWith('.zip'));
    expect(savedBytes, isNotNull);
    expect(savedBytes!.isNotEmpty, isTrue);
    final archive = ZipDecoder().decodeBytes(savedBytes!);
    final diagnosticFile = archive.findFile('diagnostic.json');
    expect(diagnosticFile, isNotNull);
    expect(
      utf8.decode(diagnosticFile!.content as List<int>),
      contains('"kind": "diagnostic"'),
    );
  });
}
