import 'package:ac_piscine_pro/models/auth_session.dart';
import 'package:ac_piscine_pro/services/team_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TeamService', () {
    test('fetchTeamMembers merges backend users and pending invitations',
        () async {
      final members = await TeamService.fetchTeamMembers(
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
          expect(token, 'token-abc');
          if (endpoint.endsWith('/team/members')) {
            expect(method, 'GET');
            return {
              'data': [
                {
                  'id': 'user_1',
                  'email': 'admin@example.test',
                  'full_name': 'Admin Demo',
                  'role': 'admin',
                },
              ],
            };
          }
          expect(endpoint.endsWith('/team/invitations'), isTrue);
          return {
            'data': [
              {
                'id': 'invite_1',
                'email': 'tech@example.test',
                'fullName': 'Tech Demo',
                'role': 'technician',
                'status': 'pending',
              },
            ],
          };
        },
      );

      expect(members, hasLength(2));
      expect(members.first.role, 'Admin');
      expect(members.last.isPending, isTrue);
      expect(members.last.email, 'tech@example.test');
    });

    test('inviteMember returns a pending team member invitation', () async {
      final invitation = await TeamService.inviteMember(
        email: 'manager@example.test',
        fullName: 'Manager Demo',
        role: 'manager',
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
          expect(method, 'POST');
          expect(endpoint, 'http://127.0.0.1:8788/v2/team/invitations');
          expect(payload?['role'], 'manager');
          return {
            'data': {
              'id': 'invite_1',
              'email': 'manager@example.test',
              'fullName': 'Manager Demo',
              'role': 'manager',
              'status': 'pending',
            },
          };
        },
      );

      expect(invitation.invitationId, 'invite_1');
      expect(invitation.isPending, isTrue);
      expect(invitation.role, 'Manager');
    });
  });
}
