import '../models/document_numbering_settings.dart';
import '../models/financial_document.dart';

class DocumentNumberService {
  static String buildNextNumber({
    required FinancialDocumentType type,
    required Iterable<FinancialDocument> existingDocuments,
    DateTime? now,
    DocumentNumberingSettings? settings,
  }) {
    final numberingSettings = settings ?? DocumentNumberingSettings.defaults();
    final date = now ?? DateTime.now();
    final year = date.year;
    final prefix = type == FinancialDocumentType.quote
        ? numberingSettings.quotePrefix
        : numberingSettings.invoicePrefix;
    final escapedPrefix = RegExp.escape(prefix);
    final minimumDigits = numberingSettings.sequencePadding < 1
        ? 1
        : numberingSettings.sequencePadding;
    final pattern = numberingSettings.includeYear
        ? RegExp('^$escapedPrefix-$year-(\\d{$minimumDigits,})\$')
        : RegExp('^$escapedPrefix-(\\d{$minimumDigits,})\$');

    var maxSequence = 0;
    for (final document in existingDocuments) {
      if (document.type != type) continue;
      final match = pattern.firstMatch(document.documentNumber);
      if (match == null) continue;
      final sequence = int.tryParse(match.group(1) ?? '');
      if (sequence != null && sequence > maxSequence) {
        maxSequence = sequence;
      }
    }

    final nextSequence =
        (maxSequence + 1).toString().padLeft(minimumDigits, '0');
    if (numberingSettings.includeYear) {
      return '$prefix-$year-$nextSequence';
    }
    return '$prefix-$nextSequence';
  }
}
