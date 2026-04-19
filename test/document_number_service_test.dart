import 'package:flutter_test/flutter_test.dart';

import 'package:ac_piscine_pro/models/document_numbering_settings.dart';
import 'package:ac_piscine_pro/models/financial_document.dart';
import 'package:ac_piscine_pro/services/document_number_service.dart';

void main() {
  group('DocumentNumberService', () {
    test('garde le comportement actuel par defaut', () {
      final number = DocumentNumberService.buildNextNumber(
        type: FinancialDocumentType.quote,
        existingDocuments: [
          _document(
            type: FinancialDocumentType.quote,
            documentNumber: 'DEV-2026-001',
          ),
          _document(
            type: FinancialDocumentType.quote,
            documentNumber: 'DEV-2026-009',
          ),
        ],
        now: DateTime(2026, 6, 1),
      );

      expect(number, 'DEV-2026-010');
    });

    test('permet une configuration custom avec annee', () {
      final settings = DocumentNumberingSettings(
        quotePrefix: 'QT',
        invoicePrefix: 'INV',
        sequencePadding: 4,
        includeYear: true,
      );

      final number = DocumentNumberService.buildNextNumber(
        type: FinancialDocumentType.invoice,
        existingDocuments: [
          _document(
            type: FinancialDocumentType.invoice,
            documentNumber: 'INV-2026-0012',
          ),
        ],
        now: DateTime(2026, 7, 4),
        settings: settings,
      );

      expect(number, 'INV-2026-0013');
    });

    test('permet une configuration custom sans annee', () {
      final settings = DocumentNumberingSettings(
        quotePrefix: 'Q',
        invoicePrefix: 'I',
        sequencePadding: 2,
        includeYear: false,
      );

      final number = DocumentNumberService.buildNextNumber(
        type: FinancialDocumentType.quote,
        existingDocuments: [
          _document(
            type: FinancialDocumentType.quote,
            documentNumber: 'Q-07',
          ),
          _document(
            type: FinancialDocumentType.quote,
            documentNumber: 'Q-11',
          ),
          _document(
            type: FinancialDocumentType.quote,
            documentNumber: 'Q-2026-99',
          ),
        ],
        now: DateTime(2026, 1, 1),
        settings: settings,
      );

      expect(number, 'Q-12');
    });

    test('ignore les documents dun autre type', () {
      final number = DocumentNumberService.buildNextNumber(
        type: FinancialDocumentType.quote,
        existingDocuments: [
          _document(
            type: FinancialDocumentType.invoice,
            documentNumber: 'DEV-2026-099',
          ),
        ],
        now: DateTime(2026, 8, 1),
      );

      expect(number, 'DEV-2026-001');
    });
  });
}

FinancialDocument _document({
  required FinancialDocumentType type,
  required String documentNumber,
}) {
  return FinancialDocument(
    id: documentNumber,
    documentNumber: documentNumber,
    createdAtIso: '2026-01-01T00:00:00',
    type: type,
    status: FinancialDocumentStatus.draft,
    vatRate: 20,
    depositAmount: 0,
    title: '',
    dateLabel: '',
    dueDateLabel: '',
    clientName: '',
    technicianName: '',
    paymentMethodLabel: '',
    notes: '',
    items: const [],
  );
}
