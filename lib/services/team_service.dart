import 'dart:convert';
import 'dart:io';

import '../models/auth_session.dart';
import '../models/team_member.dart';
import 'auth_service.dart';

typedef TeamTransport = Future<Map<String, dynamic>> Function({
  required String method,
  required String endpoint,
  required String token,
  Map<String, dynamic>? payload,
});

class TeamService {
  static bool canManageTeam(AuthSession? session) {
    final role = session?.role.trim().toLowerCase() ?? '';
    return role == 'admin' || role == 'manager';
  }

  static Future<List<TeamMember>> fetchTeamMembers({
    AuthSession? session,
    TeamTransport transport = _defaultTransport,
  }) async {
    final resolvedSession = session ?? AuthService.currentSession;
    if (resolvedSession == null || !resolvedSession.isValid) {
      return const [];
    }

    final membersResponse = await transport(
      method: 'GET',
      endpoint: _teamEndpoint(resolvedSession.endpoint, 'members'),
      token: resolvedSession.token,
    );
    final members = _decodeList(membersResponse['data'])
        .map(TeamMember.fromV2User)
        .toList();

    if (!canManageTeam(resolvedSession)) {
      return members;
    }

    try {
      final invitationsResponse = await transport(
        method: 'GET',
        endpoint: _teamEndpoint(resolvedSession.endpoint, 'invitations'),
        token: resolvedSession.token,
      );
      final invitations = _decodeList(invitationsResponse['data'])
          .map(TeamMember.fromV2Invitation)
          .toList();
      return [
        ...members,
        ...invitations,
      ];
    } catch (_) {
      return members;
    }
  }

  static Future<TeamMember> inviteMember({
    required String email,
    required String role,
    String fullName = '',
    AuthSession? session,
    TeamTransport transport = _defaultTransport,
  }) async {
    final resolvedSession = session ?? AuthService.currentSession;
    if (resolvedSession == null || !resolvedSession.isValid) {
      throw const TeamServiceException(
          'Session V2 requise pour inviter un membre.');
    }
    if (!canManageTeam(resolvedSession)) {
      throw const TeamServiceException(
        'Permissions insuffisantes pour inviter un membre.',
      );
    }

    final response = await transport(
      method: 'POST',
      endpoint: _teamEndpoint(resolvedSession.endpoint, 'invitations'),
      token: resolvedSession.token,
      payload: {
        'email': email.trim(),
        'fullName': fullName.trim(),
        'role': role.trim().toLowerCase(),
      },
    );

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return TeamMember.fromV2Invitation(data);
    }
    if (data is Map) {
      return TeamMember.fromV2Invitation(Map<String, dynamic>.from(data));
    }
    throw const TeamServiceException('Payload invitation equipe invalide.');
  }

  static String _teamEndpoint(String endpoint, String path) {
    final uri = Uri.parse(endpoint.trim());
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    final normalized = segments.contains('v2')
        ? segments.takeWhile((segment) => segment != 'v2').toList()
        : segments.toList();
    return uri.replace(
      pathSegments: [
        ...normalized.where((segment) => segment.isNotEmpty),
        'v2',
        'team',
        path,
      ],
      queryParameters: null,
      fragment: null,
    ).toString();
  }

  static List<Map<String, dynamic>> _decodeList(dynamic raw) {
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<Map<String, dynamic>> _defaultTransport({
    required String method,
    required String endpoint,
    required String token,
    Map<String, dynamic>? payload,
  }) async {
    final uri = Uri.parse(endpoint);
    final client = HttpClient();
    final request = switch (method) {
      'POST' => await client.postUrl(uri),
      'PUT' => await client.putUrl(uri),
      'DELETE' => await client.deleteUrl(uri),
      _ => await client.getUrl(uri),
    };
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
    if (payload != null) {
      request.headers
          .set(HttpHeaders.contentTypeHeader, ContentType.json.mimeType);
      request.write(jsonEncode(payload));
    }
    final response = await request.close();
    final raw = await utf8.decoder.bind(response).join();
    client.close();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TeamServiceException(
        'Requete equipe impossible (HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw const TeamServiceException('Payload equipe invalide.');
  }
}

class TeamServiceException implements Exception {
  final String message;

  const TeamServiceException(this.message);

  @override
  String toString() => message;
}
