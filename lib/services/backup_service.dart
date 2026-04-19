import 'dart:convert';
import 'dart:io';

import 'app_environment.dart';
import 'local_storage_service.dart';

class BackupEntry {
  final String path;
  final String fileName;

  const BackupEntry({
    required this.path,
    required this.fileName,
  });
}

class BackupService {
  static String get folderName => AppEnvironment.folderName('backups');
  static String get syncFolderName =>
      AppEnvironment.folderName('sync_payloads');

  static Future<String> createBackup(Map<String, dynamic> payload) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    return LocalStorageService.saveTextFile(
      folderName,
      '${AppEnvironment.storageName('backup')}_$timestamp.json',
      jsonEncode(payload),
    );
  }

  static Future<List<BackupEntry>> listBackups() async {
    final files = await LocalStorageService.listFiles(folderName);
    return files
        .whereType<File>()
        .map(
          (file) => BackupEntry(
            path: file.path,
            fileName: file.uri.pathSegments.last,
          ),
        )
        .toList();
  }

  static Future<Map<String, dynamic>> readBackup(String path) async {
    final raw = await File(path).readAsString();
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<String> createSyncPayload(Map<String, dynamic> payload) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    return LocalStorageService.saveTextFile(
      syncFolderName,
      '${AppEnvironment.storageName('sync_payload')}_$timestamp.json',
      jsonEncode(payload),
    );
  }
}
