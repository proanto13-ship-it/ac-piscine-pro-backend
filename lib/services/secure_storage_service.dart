import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_session.dart';

class SecureStorageService {
  static const String _cloudSyncApiKeyKey = 'cloud_sync_api_key';
  static const String _authSessionKey = 'cloud_sync_auth_session';
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<String> readCloudSyncApiKey() async {
    return (await _storage.read(key: _cloudSyncApiKeyKey)) ?? '';
  }

  static Future<void> writeCloudSyncApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await deleteCloudSyncApiKey();
      return;
    }

    await _storage.write(
      key: _cloudSyncApiKeyKey,
      value: trimmed,
    );
  }

  static Future<void> deleteCloudSyncApiKey() async {
    await _storage.delete(key: _cloudSyncApiKeyKey);
  }

  static Future<AuthSession?> readAuthSession() async {
    final raw = await _storage.read(key: _authSessionKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AuthSession.fromJson(decoded);
      }
      if (decoded is Map) {
        return AuthSession.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<void> writeAuthSession(AuthSession session) async {
    await _storage.write(
      key: _authSessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  static Future<void> deleteAuthSession() async {
    await _storage.delete(key: _authSessionKey);
  }

  static Future<void> clearAllAppSecrets() async {
    await deleteCloudSyncApiKey();
    await deleteAuthSession();
  }

  static Future<bool> importLegacyCloudSyncApiKeyIfNeeded(
    String legacyApiKey,
  ) async {
    final trimmed = legacyApiKey.trim();
    if (trimmed.isEmpty) return false;

    final current = await readCloudSyncApiKey();
    if (current.trim().isNotEmpty) {
      return false;
    }

    await writeCloudSyncApiKey(trimmed);
    return true;
  }
}
