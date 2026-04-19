import 'dart:convert';
import 'dart:io';

class CloudSyncResult {
  final bool ok;
  final String message;
  final Map<String, dynamic>? payload;
  final int? statusCode;

  const CloudSyncResult({
    required this.ok,
    required this.message,
    this.payload,
    this.statusCode,
  });
}

class CloudSyncService {
  static Future<CloudSyncResult> push({
    required String endpoint,
    String? apiKey,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final uri = Uri.parse(endpoint);
      final client = HttpClient();
      final request = await client.postUrl(uri);
      _applyHeaders(request, apiKey);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final response = await request.close();
      final raw = await utf8.decoder.bind(response).join();
      client.close();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return CloudSyncResult(
          ok: true,
          message: _parseMessage(raw, fallback: 'Synchronisation envoyée.'),
          payload: _tryParseMap(raw),
          statusCode: response.statusCode,
        );
      }

      return CloudSyncResult(
        ok: false,
        message: _parseMessage(
          raw,
          fallback: 'Erreur HTTP ${response.statusCode} pendant l’envoi.',
        ),
        payload: _tryParseMap(raw),
        statusCode: response.statusCode,
      );
    } on FormatException {
      return const CloudSyncResult(
        ok: false,
        message: 'Endpoint cloud invalide.',
      );
    } on SocketException catch (error) {
      return CloudSyncResult(
        ok: false,
        message: 'Connexion au cloud impossible : ${error.message}',
      );
    } catch (error) {
      return CloudSyncResult(
        ok: false,
        message: 'Synchronisation impossible : $error',
      );
    }
  }

  static Future<CloudSyncResult> pull({
    required String endpoint,
    String? apiKey,
  }) async {
    try {
      final uri = Uri.parse(endpoint);
      final client = HttpClient();
      final request = await client.getUrl(uri);
      _applyHeaders(request, apiKey);
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);

      final response = await request.close();
      final raw = await utf8.decoder.bind(response).join();
      client.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return CloudSyncResult(
          ok: false,
          message: _parseMessage(
            raw,
            fallback:
                'Erreur HTTP ${response.statusCode} pendant la récupération.',
          ),
          payload: _tryParseMap(raw),
          statusCode: response.statusCode,
        );
      }

      final payload = _tryParseMap(raw);
      if (payload == null) {
        return const CloudSyncResult(
          ok: false,
          message: 'Le cloud n’a pas retourné de payload JSON exploitable.',
        );
      }

      final nestedPayload = payload['payload'];
      final decodedPayload = nestedPayload is Map<String, dynamic>
          ? nestedPayload
          : nestedPayload is Map
              ? Map<String, dynamic>.from(nestedPayload)
              : payload;

      if (decodedPayload['clients'] is! List) {
        return const CloudSyncResult(
          ok: false,
          message: 'Le payload récupéré ne contient pas de clients.',
        );
      }

      return CloudSyncResult(
        ok: true,
        message: payload['message']?.toString() ?? 'Synchronisation récupérée.',
        payload: decodedPayload,
        statusCode: response.statusCode,
      );
    } on FormatException {
      return const CloudSyncResult(
        ok: false,
        message: 'Endpoint cloud invalide.',
      );
    } on SocketException catch (error) {
      return CloudSyncResult(
        ok: false,
        message: 'Connexion au cloud impossible : ${error.message}',
      );
    } catch (error) {
      return CloudSyncResult(
        ok: false,
        message: 'Récupération impossible : $error',
      );
    }
  }

  static void _applyHeaders(HttpClientRequest request, String? apiKey) {
    final trimmed = apiKey?.trim() ?? '';
    if (trimmed.isEmpty) return;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $trimmed');
    request.headers.set('x-api-key', trimmed);
  }

  static String _parseMessage(String raw, {required String fallback}) {
    final payload = _tryParseMap(raw);
    if (payload == null) return fallback;
    return payload['message']?.toString() ??
        payload['detail']?.toString() ??
        payload['error']?.toString() ??
        fallback;
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
}
