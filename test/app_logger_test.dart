import 'dart:convert';

import 'package:ac_piscine_pro/services/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppLogger formats structured log records', () {
    final line = AppLogger.formatRecord(
      const AppLogRecord(
        timestampIso: '2026-04-17T10:00:00Z',
        level: AppLogLevel.event,
        category: 'auth',
        message: 'login_success',
        data: {
          'organizationId': 'org_demo',
        },
      ),
    );

    final decoded = jsonDecode(line) as Map<String, dynamic>;
    expect(decoded['level'], 'event');
    expect(decoded['category'], 'auth');
    expect(decoded['message'], 'login_success');
    expect(decoded['data']['organizationId'], 'org_demo');
  });
}
