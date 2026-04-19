import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/auth_session.dart';
import '../models/cloud_sync_settings.dart';
import 'secure_storage_service.dart';

typedef AuthLoginTransport = Future<Map<String, dynamic>> Function({
  required String endpoint,
  required String organizationId,
  required String email,
  required String password,
});

typedef AuthMeTransport = Future<Map<String, dynamic>> Function({
  required String endpoint,
  required String token,
});

typedef AuthResourceTransport = Future<Map<String, dynamic>> Function({
  required String method,
  required String endpoint,
  required String token,
  Map<String, dynamic>? payload,
});

class AuthService {
  static final ValueNotifier<AuthSession?> sessionNotifier =
      ValueNotifier<AuthSession?>(null);

  static AuthSession? get currentSession => sessionNotifier.value;

  static bool get isAuthenticated => currentSession?.isValid == true;

  static bool requiresSession(CloudSyncSettings settings) {
    return settings.syncMode == CloudSyncMode.v2;
  }

  static Future<AuthSession> login({
    required String endpoint,
    required String organizationId,
    required String email,
    required String password,
    AuthLoginTransport transport = _defaultLoginTransport,
    Future<void> Function(AuthSession session)? persistSession,
  }) async {
    final payload = await transport(
      endpoint: endpoint,
      organizationId: organizationId,
      email: email,
      password: password,
    );
    final dataPayload = _extractDataPayload(payload);

    final session = _sessionFromAuthPayload(
      endpoint: endpoint,
      token: dataPayload['token']?.toString() ?? '',
      userPayload: _extractUserPayload(payload),
    );

    if (!session.isValid) {
      throw const AuthException('Session V2 invalide reçue du backend.');
    }

    await (persistSession ?? SecureStorageService.writeAuthSession)(session);
    sessionNotifier.value = session;
    return session;
  }

  static Future<AuthSession?> restoreSessionIfNeeded({
    required CloudSyncSettings settings,
    AuthMeTransport transport = _defaultMeTransport,
    Future<AuthSession?> Function()? readStoredSession,
    Future<void> Function(AuthSession session)? persistSession,
    Future<void> Function()? clearStoredSession,
  }) async {
    if (!requiresSession(settings)) {
      sessionNotifier.value = null;
      return null;
    }

    final storedSession =
        await (readStoredSession ?? SecureStorageService.readAuthSession)();
    if (storedSession == null || !storedSession.isValid) {
      sessionNotifier.value = null;
      return null;
    }

    final resolvedEndpoint = settings.endpoint.trim().isNotEmpty
        ? settings.endpoint.trim()
        : storedSession.endpoint;
    if (resolvedEndpoint.isEmpty) {
      await (clearStoredSession ?? SecureStorageService.deleteAuthSession)();
      sessionNotifier.value = null;
      return null;
    }

    try {
      final payload = await transport(
        endpoint: resolvedEndpoint,
        token: storedSession.token,
      );
      final refreshedSession = _sessionFromAuthPayload(
        endpoint: resolvedEndpoint,
        token: storedSession.token,
        userPayload: _extractUserPayload(payload),
      );
      sessionNotifier.value = refreshedSession;
      try {
        await (persistSession ?? SecureStorageService.writeAuthSession)(
          refreshedSession,
        );
      } catch (_) {
        // Keep the refreshed in-memory session even if secure persistence fails.
      }
      return refreshedSession;
    } on AuthException {
      await logout(clearStoredSession: clearStoredSession);
      return null;
    } catch (_) {
      sessionNotifier.value =
          storedSession.copyWith(endpoint: resolvedEndpoint);
      return sessionNotifier.value;
    }
  }

  static Future<void> logout({
    Future<void> Function()? clearStoredSession,
  }) async {
    await (clearStoredSession ?? SecureStorageService.deleteAuthSession)();
    sessionNotifier.value = null;
  }

  static Future<Map<String, dynamic>?> fetchOrganizationProfile({
    AuthSession? session,
    AuthResourceTransport transport = _defaultResourceTransport,
  }) async {
    final resolvedSession = session ?? currentSession;
    if (resolvedSession == null || !resolvedSession.isValid) {
      return null;
    }

    final payload = await transport(
      method: 'GET',
      endpoint: _resourceEndpoint(
        resolvedSession.endpoint,
        'organizations',
        queryParameters: {
          'organization_id': resolvedSession.organizationId,
        },
      ),
      token: resolvedSession.token,
    );

    final data = payload['data'];
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> saveOrganizationProfile({
    required Map<String, dynamic> payload,
    AuthSession? session,
    AuthResourceTransport transport = _defaultResourceTransport,
  }) async {
    final resolvedSession = session ?? currentSession;
    if (resolvedSession == null || !resolvedSession.isValid) {
      return null;
    }

    final existing = await fetchOrganizationProfile(
      session: resolvedSession,
      transport: transport,
    );

    final organizationPayload = {
      ...payload,
      'id': existing?['id']?.toString().trim().isNotEmpty == true
          ? existing!['id']
          : resolvedSession.organizationId,
      'organization_id': resolvedSession.organizationId,
      'name': payload['name']?.toString().trim().isNotEmpty == true
          ? payload['name']
          : payload['companyName'],
    };

    final response = await transport(
      method: existing == null ? 'POST' : 'PUT',
      endpoint: existing == null
          ? _resourceEndpoint(resolvedSession.endpoint, 'organizations')
          : _resourceEndpoint(
              resolvedSession.endpoint,
              'organizations/${existing['id']}',
            ),
      token: resolvedSession.token,
      payload: organizationPayload,
    );

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static Future<Map<String, dynamic>?> exportAccountData({
    AuthSession? session,
    AuthResourceTransport transport = _defaultResourceTransport,
  }) async {
    final resolvedSession = session ?? currentSession;
    if (resolvedSession == null || !resolvedSession.isValid) {
      return null;
    }

    final response = await transport(
      method: 'GET',
      endpoint: _resourceEndpoint(resolvedSession.endpoint, 'account/export'),
      token: resolvedSession.token,
    );
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static Future<Map<String, dynamic>?> deleteAccount({
    AuthSession? session,
    AuthResourceTransport transport = _defaultResourceTransport,
  }) async {
    final resolvedSession = session ?? currentSession;
    if (resolvedSession == null || !resolvedSession.isValid) {
      return null;
    }

    final response = await transport(
      method: 'DELETE',
      endpoint: _resourceEndpoint(resolvedSession.endpoint, 'account/me'),
      token: resolvedSession.token,
    );
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static Future<Map<String, dynamic>> _defaultLoginTransport({
    required String endpoint,
    required String organizationId,
    required String email,
    required String password,
  }) async {
    return _sendJson(
      method: 'POST',
      endpoint: _authEndpoint(endpoint, 'login'),
      payload: {
        'organization_id': organizationId,
        'email': email.trim(),
        'password': password,
      },
    );
  }

  static Future<Map<String, dynamic>> _defaultMeTransport({
    required String endpoint,
    required String token,
  }) async {
    return _sendJson(
      method: 'GET',
      endpoint: _authEndpoint(endpoint, 'me'),
      token: token,
    );
  }

  static Future<Map<String, dynamic>> _defaultResourceTransport({
    required String method,
    required String endpoint,
    required String token,
    Map<String, dynamic>? payload,
  }) {
    return _sendJson(
      method: method,
      endpoint: endpoint,
      token: token,
      payload: payload,
    );
  }

  static Future<Map<String, dynamic>> _sendJson({
    required String method,
    required String endpoint,
    Map<String, dynamic>? payload,
    String? token,
  }) async {
    try {
      final uri = _validatedUri(endpoint);
      final client = HttpClient();
      late HttpClientRequest request;
      switch (method.toUpperCase()) {
        case 'POST':
          request = await client.postUrl(uri);
          break;
        case 'GET':
          request = await client.getUrl(uri);
          break;
        case 'PUT':
          request = await client.putUrl(uri);
          break;
        case 'DELETE':
          request = await client.deleteUrl(uri);
          break;
        default:
          throw AuthException('Méthode HTTP non supportée: $method');
      }

      final trimmedToken = token?.trim() ?? '';
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      if (trimmedToken.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $trimmedToken',
        );
      }
      if (payload != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(payload));
      }

      final response = await request.close();
      final raw = await utf8.decoder.bind(response).join();
      client.close();

      final decoded = _tryParseMap(raw);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded ?? const {};
      }

      throw AuthException(
        _parseMessage(
          decoded,
          fallback:
              'Erreur HTTP ${response.statusCode} pendant l’authentification.',
        ),
      );
    } on FormatException {
      throw const AuthException('Adresse du serveur invalide.');
    } on SocketException catch (error) {
      throw AuthException('Connexion au backend impossible : ${error.message}');
    } on AuthException {
      rethrow;
    } catch (error) {
      throw AuthException('Authentification impossible : $error');
    }
  }

  static String _authEndpoint(String endpoint, String action) {
    final uri = _validatedUri(endpoint);
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    final normalizedSegments = [...segments];
    final v2Index = normalizedSegments.indexOf('v2');

    final baseSegments = v2Index >= 0
        ? normalizedSegments.sublist(0, v2Index + 1)
        : [...normalizedSegments, 'v2'];

    return uri.replace(
      pathSegments: [...baseSegments, 'auth', action],
      queryParameters: null,
      fragment: null,
    ).toString();
  }

  static String _resourceEndpoint(
    String endpoint,
    String resourcePath, {
    Map<String, String>? queryParameters,
  }) {
    final uri = _validatedUri(endpoint);
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    final normalizedSegments = [...segments];
    final v2Index = normalizedSegments.indexOf('v2');

    final baseSegments = v2Index >= 0
        ? normalizedSegments.sublist(0, v2Index + 1)
        : [...normalizedSegments, 'v2'];

    return uri.replace(
      pathSegments: [
        ...baseSegments,
        ...resourcePath.split('/').where((segment) => segment.isNotEmpty),
      ],
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
      fragment: null,
    ).toString();
  }

  static Map<String, dynamic> _extractDataPayload(
      Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return const {};
  }

  static Map<String, dynamic> _extractUserPayload(
      Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is Map<String, dynamic> && data['user'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data['user']);
    }
    if (data is Map && data['user'] is Map) {
      return Map<String, dynamic>.from(data['user'] as Map);
    }
    throw const AuthException(
        'Utilisateur courant introuvable dans la réponse.');
  }

  static AuthSession _sessionFromAuthPayload({
    required String endpoint,
    required String token,
    required Map<String, dynamic> userPayload,
  }) {
    return AuthSession(
      endpoint: endpoint.trim(),
      token: token.trim(),
      userId: userPayload['id']?.toString() ?? '',
      organizationId: userPayload['organization_id']?.toString() ?? '',
      email: userPayload['email']?.toString() ?? '',
      fullName: userPayload['full_name']?.toString() ?? '',
      role: userPayload['role']?.toString() ?? '',
    );
  }

  static Map<String, dynamic>? _tryParseMap(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _parseMessage(
    Map<String, dynamic>? payload, {
    required String fallback,
  }) {
    if (payload == null) return fallback;
    return payload['message']?.toString() ??
        payload['detail']?.toString() ??
        payload['error']?.toString() ??
        fallback;
  }

  static Uri _validatedUri(String endpoint) {
    final raw = endpoint.trim();
    if (raw.isEmpty) {
      throw const FormatException('Endpoint vide');
    }
    final uri = Uri.parse(raw);
    final scheme = uri.scheme.trim().toLowerCase();
    if ((scheme != 'http' && scheme != 'https') || uri.host.trim().isEmpty) {
      throw const FormatException('Endpoint invalide');
    }
    return uri;
  }
}

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}
