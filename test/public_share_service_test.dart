import 'package:ac_piscine_pro/models/auth_session.dart';
import 'package:ac_piscine_pro/services/public_share_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PublicShareService creates a public link from backend payload',
      () async {
    final link = await PublicShareService.createLink(
      resourceType: PublicShareResourceType.intervention,
      resourceId: 'inter_1',
      expiresAtIso: '2026-05-01T10:00:00Z',
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
        required endpoint,
        required token,
        required payload,
      }) async {
        expect(endpoint, 'http://127.0.0.1:8788/v2/public-links');
        expect(token, 'token-abc');
        expect(payload['resource_type'], 'intervention');
        expect(payload['resource_id'], 'inter_1');
        expect(payload['expires_at_iso'], '2026-05-01T10:00:00Z');
        return {
          'data': {
            'id': 'share_1',
            'token': 'tok_123',
            'resourceType': 'intervention',
            'resourceId': 'inter_1',
            'expiresAtIso': '2026-05-01T10:00:00Z',
            'publicUrl': 'https://demo.test/v2/public/share/tok_123',
            'createdAtIso': '2026-04-17T10:00:00Z',
          },
        };
      },
    );

    expect(link.id, 'share_1');
    expect(link.publicUrl, 'https://demo.test/v2/public/share/tok_123');
    expect(link.hasExpiration, isTrue);
  });
}
