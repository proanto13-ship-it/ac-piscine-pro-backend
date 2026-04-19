import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  static Future<Directory> _baseDirectory() async {
    return getApplicationDocumentsDirectory();
  }

  static Future<File> _fileFor(String name) async {
    final directory = await _baseDirectory();
    return File('${directory.path}/$name');
  }

  static Future<String?> readString(String name) async {
    final file = await _fileFor(name);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  static Future<void> writeString(String name, String value) async {
    final file = await _fileFor(name);
    await file.writeAsString(value, flush: true);
  }

  static Future<Map<String, dynamic>?> readJsonMap(String name) async {
    final raw = await readString(name);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<List<dynamic>?> readJsonList(String name) async {
    final raw = await readString(name);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return List<dynamic>.from(jsonDecode(raw));
  }

  static Future<void> writeJson(String name, Object value) async {
    await writeString(name, jsonEncode(value));
  }

  static Future<String> saveBinary(
    String folderName,
    String fileName,
    List<int> bytes,
  ) async {
    final directory = await _baseDirectory();
    final folder = Directory('${directory.path}/$folderName');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final file = File('${folder.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<List<int>?> readBinary(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  static Future<String> saveTextFile(
    String folderName,
    String fileName,
    String content,
  ) async {
    final directory = await _baseDirectory();
    final folder = Directory('${directory.path}/$folderName');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final file = File('${folder.path}/$fileName');
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  static Future<List<FileSystemEntity>> listFiles(String folderName) async {
    final directory = await _baseDirectory();
    final folder = Directory('${directory.path}/$folderName');
    if (!await folder.exists()) {
      return [];
    }
    final files = await folder.list().toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  static Future<void> clearAllApplicationData() async {
    final directory = await _baseDirectory();
    if (!await directory.exists()) {
      return;
    }

    final entries = await directory.list().toList();
    for (final entry in entries) {
      await entry.delete(recursive: true);
    }
  }
}
