import 'package:ac_piscine_pro/models/auth_session.dart';
import 'package:ac_piscine_pro/models/cloud_sync_settings.dart';
import 'package:ac_piscine_pro/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AuthService.sessionNotifier.value = null;
  });

  group('AuthService', () {
    test('login persists and publishes the V2 session', () async {
      AuthSession? persistedSession;

      final session = await AuthService.login(
        endpoint: 'http://127.0.0.1:8788/v2',
        organizationId: 'org_demo',
        email: 'admin@example.test',
        password: 'secret',
        transport: ({
          required endpoint,
          required organizationId,
          required email,
          required password,
        }) async {
          return {
            'data': {
              'token': 'token-123',
              'user': {
                'id': 'user_1',
                'organization_id': organizationId,
                'email': email,
                'full_name': 'Admin Demo',
                'role': 'admin',
              },
            },
          };
        },
        persistSession: (session) async {
          persistedSession = session;
        },
      );

      expect(session.token, 'token-123');
      expect(session.organizationId, 'org_demo');
      expect(AuthService.currentSession?.email, 'admin@example.test');
      expect(persistedSession?.fullName, 'Admin Demo');
    });

    test('restoreSessionIfNeeded refreshes the current user with /me',
        () async {
      final restored = await AuthService.restoreSessionIfNeeded(
        settings: CloudSyncSettings.defaults().copyWith(
          syncMode: CloudSyncMode.v2,
          endpoint: 'http://127.0.0.1:8788/v2',
        ),
        readStoredSession: () async => const AuthSession(
          endpoint: 'http://127.0.0.1:8788/v2',
          token: 'token-abc',
          userId: 'user_1',
          organizationId: 'org_demo',
          email: 'old@example.test',
          fullName: '',
          role: '',
        ),
        transport: ({
          required endpoint,
          required token,
        }) async {
          expect(endpoint, 'http://127.0.0.1:8788/v2');
          expect(token, 'token-abc');
          return {
            'data': {
              'user': {
                'id': 'user_1',
                'organization_id': 'org_demo',
                'email': 'admin@example.test',
                'full_name': 'Admin Demo',
                'role': 'admin',
              },
            },
          };
        },
      );

      expect(restored, isNotNull);
      expect(restored?.email, 'admin@example.test');
      expect(AuthService.isAuthenticated, isTrue);
    });

    test('restoreSessionIfNeeded clears the session when /me is unauthorized',
        () async {
      var cleared = false;

      final restored = await AuthService.restoreSessionIfNeeded(
        settings: CloudSyncSettings.defaults().copyWith(
          syncMode: CloudSyncMode.v2,
          endpoint: 'http://127.0.0.1:8788/v2',
        ),
        readStoredSession: () async => const AuthSession(
          endpoint: 'http://127.0.0.1:8788/v2',
          token: 'token-invalid',
          userId: 'user_1',
          organizationId: 'org_demo',
          email: 'admin@example.test',
          fullName: 'Admin Demo',
          role: 'admin',
        ),
        transport: ({
          required endpoint,
          required token,
        }) async {
          throw const AuthException('Authentification requise.');
        },
        clearStoredSession: () async {
          cleared = true;
        },
      );

      expect(restored, isNull);
      expect(cleared, isTrue);
      expect(AuthService.currentSession, isNull);
    });

    test('exportAccountData reads scoped payload from backend endpoint',
        () async {
      final payload = await AuthService.exportAccountData(
        session: const AuthSession(
          endpoint: 'http://127.0.0.1:8788/v2',
          token: 'token-abc',
          userId: 'user_1',
          organizationId: 'org_demo',
          email: 'admin@example.test',
          fullName: 'Admin Demo',
          role: 'admin',
        ),
        transport: ({
          required method,
          required endpoint,
          required token,
          payload,
        }) async {
          expect(method, 'GET');
          expect(endpoint, 'http://127.0.0.1:8788/v2/account/export');
          expect(token, 'token-abc');
          return {
            'data': {
              'organization': {'organization_id': 'org_demo'},
              'user': {'id': 'user_1'},
            },
          };
        },
      );

      expect(payload?['organization']['organization_id'], 'org_demo');
      expect(payload?['user']['id'], 'user_1');
    });

    test('deleteAccount uses DELETE on account endpoint', () async {
      final payload = await AuthService.deleteAccount(
        session: const AuthSession(
          endpoint: 'http://127.0.0.1:8788/v2',
          token: 'token-abc',
          userId: 'user_1',
          organizationId: 'org_demo',
          email: 'admin@example.test',
          fullName: 'Admin Demo',
          role: 'admin',
        ),
        transport: ({
          required method,
          required endpoint,
          required token,
          payload,
        }) async {
          expect(method, 'DELETE');
          expect(endpoint, 'http://127.0.0.1:8788/v2/account/me');
          expect(token, 'token-abc');
          return {
            'data': {
              'deletedUserId': 'user_1',
              'organizationDeleted': true,
            },
          };
        },
      );

      expect(payload?['deletedUserId'], 'user_1');
      expect(payload?['organizationDeleted'], isTrue);
    });
  });
}
