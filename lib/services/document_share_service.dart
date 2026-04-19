import 'dart:typed_data';

import 'package:printing/printing.dart';

class DocumentShareService {
  static Future<void> sharePdf({
    required Uint8List bytes,
    required String filename,
  }) {
    return Printing.sharePdf(bytes: bytes, filename: filename);
  }

  static String safePdfFilename(String value) {
    final normalized = value
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '');
    if (normalized.isEmpty) {
      return 'document.pdf';
    }
    return normalized.toLowerCase().endsWith('.pdf')
        ? normalized
        : '$normalized.pdf';
  }
}
