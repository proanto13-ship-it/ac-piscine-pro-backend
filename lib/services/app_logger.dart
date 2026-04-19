import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'app_environment.dart';

enum AppLogLevel {
  debug,
  info,
  warning,
  error,
  event,
}

class AppLogRecord {
  final String timestampIso;
  final AppLogLevel level;
  final String category;
  final String message;
  final Map<String, dynamic> data;

  const AppLogRecord({
    required this.timestampIso,
    required this.level,
    required this.category,
    required this.message,
    this.data = const {},
  });

  Map<String, dynamic> toJson() => {
        'timestampIso': timestampIso,
        'level': level.name,
        'category': category,
        'message': message,
        'data': data,
      };

  factory AppLogRecord.fromJson(Map<String, dynamic> json) {
    return AppLogRecord(
      timestampIso: json['timestampIso']?.toString() ?? '',
      level: _levelFromName(json['level']?.toString()),
      category: json['category']?.toString() ?? 'app',
      message: json['message']?.toString() ?? '',
      data: json['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['data'])
          : json['data'] is Map
              ? Map<String, dynamic>.from(json['data'] as Map)
              : const {},
    );
  }

  static AppLogLevel _levelFromName(String? value) {
    switch (value) {
      case 'debug':
        return AppLogLevel.debug;
      case 'info':
        return AppLogLevel.info;
      case 'warning':
        return AppLogLevel.warning;
      case 'error':
        return AppLogLevel.error;
      case 'event':
      default:
        return AppLogLevel.event;
    }
  }
}

class AppLogger {
  static const int _maxLogBytes = 512 * 1024;
  static File? _logFile;
  static FutureOr<void> Function(AppLogRecord record)? _listener;

  static Future<void> init({
    Future<Directory> Function()? directoryProvider,
  }) async {
    try {
      final directory =
          await (directoryProvider ?? getApplicationDocumentsDirectory)();
      final logsDirectory = Directory('${directory.path}/logs');
      if (!await logsDirectory.exists()) {
        await logsDirectory.create(recursive: true);
      }
      _logFile = File(
        '${logsDirectory.path}/${AppEnvironment.storageName('app.log')}',
      );
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }
      await _rotateIfNeeded();
    } catch (_) {
      _logFile = null;
    }
  }

  static void setListener(
      FutureOr<void> Function(AppLogRecord record)? listener) {
    _listener = listener;
  }

  static Future<void> debug(
    String message, {
    String category = 'app',
    Map<String, dynamic> data = const {},
  }) {
    return _write(
      AppLogRecord(
        timestampIso: DateTime.now().toUtc().toIso8601String(),
        level: AppLogLevel.debug,
        category: category,
        message: message,
        data: data,
      ),
    );
  }

  static Future<void> info(
    String message, {
    String category = 'app',
    Map<String, dynamic> data = const {},
  }) {
    return _write(
      AppLogRecord(
        timestampIso: DateTime.now().toUtc().toIso8601String(),
        level: AppLogLevel.info,
        category: category,
        message: message,
        data: data,
      ),
    );
  }

  static Future<void> warning(
    String message, {
    String category = 'app',
    Map<String, dynamic> data = const {},
  }) {
    return _write(
      AppLogRecord(
        timestampIso: DateTime.now().toUtc().toIso8601String(),
        level: AppLogLevel.warning,
        category: category,
        message: message,
        data: data,
      ),
    );
  }

  static Future<void> event(
    String message, {
    String category = 'event',
    Map<String, dynamic> data = const {},
  }) {
    return _write(
      AppLogRecord(
        timestampIso: DateTime.now().toUtc().toIso8601String(),
        level: AppLogLevel.event,
        category: category,
        message: message,
        data: data,
      ),
    );
  }

  static Future<void> error(
    String message, {
    String category = 'error',
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic> data = const {},
  }) {
    return _write(
      AppLogRecord(
        timestampIso: DateTime.now().toUtc().toIso8601String(),
        level: AppLogLevel.error,
        category: category,
        message: message,
        data: {
          ...data,
          if (error != null) 'error': error.toString(),
          if (stackTrace != null) 'stackTrace': stackTrace.toString(),
        },
      ),
    );
  }

  static String formatRecord(AppLogRecord record) {
    return jsonEncode(record.toJson());
  }

  static Future<List<AppLogRecord>> readRecentRecords({
    int maxRecords = 80,
  }) async {
    try {
      final currentFile = _logFile ?? await _resolveLogFile();
      final files = <File>[
        File('${currentFile.parent.path}/app.previous.log'),
        currentFile,
      ];
      final records = <AppLogRecord>[];

      for (final file in files) {
        if (!await file.exists()) {
          continue;
        }
        final lines = await file.readAsLines();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Map<String, dynamic>) {
              records.add(AppLogRecord.fromJson(decoded));
            } else if (decoded is Map) {
              records.add(
                  AppLogRecord.fromJson(Map<String, dynamic>.from(decoded)));
            }
          } catch (_) {
            // Ignore malformed lines in support exports.
          }
        }
      }

      if (records.length <= maxRecords) {
        return records;
      }
      return records.sublist(records.length - maxRecords);
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _write(AppLogRecord record) async {
    final line = formatRecord(record);
    if (AppEnvironment.enableVerboseLogs || record.level == AppLogLevel.error) {
      debugPrint(
          '[${record.level.name}][${record.category}] ${record.message}');
    }
    final listener = _listener;
    if (listener != null) {
      await listener(record);
    }
    final file = _logFile;
    if (file == null) {
      return;
    }
    try {
      await _rotateIfNeeded();
      await file.writeAsString(
        '$line\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Logging must never break the app.
    }
  }

  static Future<void> _rotateIfNeeded() async {
    final file = _logFile;
    if (file == null || !await file.exists()) {
      return;
    }
    final length = await file.length();
    if (length < _maxLogBytes) {
      return;
    }
    final archived = File(
      '${file.parent.path}/${AppEnvironment.storageName('app.previous.log')}',
    );
    if (await archived.exists()) {
      await archived.delete();
    }
    await file.rename(archived.path);
    _logFile = File(file.path);
    await _logFile!.create(recursive: true);
  }

  static Future<File> _resolveLogFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final logsDirectory = Directory('${directory.path}/logs');
    if (!await logsDirectory.exists()) {
      await logsDirectory.create(recursive: true);
    }
    final file = File(
      '${logsDirectory.path}/${AppEnvironment.storageName('app.log')}',
    );
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }
}
