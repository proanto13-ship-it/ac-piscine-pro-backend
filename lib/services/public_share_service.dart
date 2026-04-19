import 'dart:convert';
import 'dart:io';

import '../models/auth_session.dart';
import '../models/public_share_link.dart';
import 'auth_service.dart';

enum PublicShareResourceType {
  intervention('intervention'),
  financialDocument('financial_document');

  final String apiValue;

  const PublicShareResourceType(this.apiValue);
}

typedef PublicShareTransport = Future<Map<String, dynamic>> Function({
  required String endpoint,
  required String token,
  required Map<String, dynamic> payload,
});

class PublicShareService {
  static Future<PublicShareLink> createLink({
    required PublicShareResourceType resourceType,
    required String resourceId,
    String? expiresAtIso,
    AuthSession? session,
    PublicShareTransport transport = _defaultTransport,
  }) async {
    final resolvedSession = session ?? AuthService.currentSession;
    if (resolvedSession == null || !resolvedSession.isValid) {
      throw const PublicShareException(
        'Connexion V2 requise pour creer un lien de partage.',
      );
    }

    final response = await transport(
      endpoint: _endpoint(resolvedSession.endpoint),
      token: resolvedSession.token,
      payload: {
        'resource_type': resourceType.apiValue,
        'resource_id': resourceId,
        if ((expiresAtIso ?? '').trim().isNotEmpty)
          'expires_at_iso': expiresAtIso!.trim(),
      },
    );

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return PublicShareLink.fromJson(data);
    }
    if (data is Map) {
      return PublicShareLink.fromJson(Map<String, dynamic>.from(data));
    }
    throw const PublicShareException('Payload lien de partage invalide.');
  }

  static String _endpoint(String endpoint) {
    final uri = Uri.parse(endpoint.trim());
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    final normalized = segments.contains('v2')
        ? segments.takeWhile((segment) => segment != 'v2').toList()
        : segments.toList();
    return uri.replace(
      pathSegments: [
        ...normalized.where((segment) => segment.isNotEmpty),
        'v2',
        'public-links',
      ],
      queryParameters: null,
      fragment: null,
    ).toString();
  }

  static Future<Map<String, dynamic>> _defaultTransport({
    required String endpoint,
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final uri = Uri.parse(endpoint);
    final client = HttpClient();
    final request = await client.postUrl(uri);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
    request.headers
        .set(HttpHeaders.contentTypeHeader, ContentType.json.mimeType);
    request.write(jsonEncode(payload));
    final response = await request.close();
    final raw = await utf8.decoder.bind(response).join();
    client.close();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PublicShareException(
        'Creation du lien impossible (HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw const PublicShareException('Payload share link invalide.');
  }
}

class PublicShareException implements Exception {
  final String message;

  const PublicShareException(this.message);

  @override
  String toString() => message;
}
