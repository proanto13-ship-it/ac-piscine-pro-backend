import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_logger.dart';

class AppErrorService {
  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(
        AppLogger.error(
          'Flutter framework error',
          category: 'unhandled',
          error: details.exception,
          stackTrace: details.stack,
          data: {
            'library': details.library ?? '',
            'context': details.context?.toDescription() ?? '',
          },
        ),
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        AppLogger.error(
          'Platform dispatcher error',
          category: 'unhandled',
          error: error,
          stackTrace: stack,
        ),
      );
      return true;
    };

    ErrorWidget.builder = (details) {
      unawaited(
        AppLogger.error(
          'Widget build failure',
          category: 'ui',
          error: details.exception,
          stackTrace: details.stack,
        ),
      );
      return Material(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Une erreur d affichage est survenue. Redemarrez l application si le probleme persiste.',
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    };
  }

  static Future<void> reportZoneError(
    Object error,
    StackTrace stackTrace,
  ) {
    return AppLogger.error(
      'Uncaught zone error',
      category: 'unhandled',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
