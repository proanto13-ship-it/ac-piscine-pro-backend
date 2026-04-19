import 'package:flutter_test/flutter_test.dart';

import 'package:ac_piscine_pro/models/financial_document.dart';

void main() {
  group('FinancialDocument', () {
    test('parse le format legacy en remplissant les nouveaux champs', () {
      final document = FinancialDocument.fromJson({
        'id': '1',
        'documentNumber': 'DEV-2026-001',
        'createdAtIso': '2026-05-10T08:30:00',
        'type': 'quote',
        'status': 'draft',
        'vatRate': 20,
        'depositAmount': 10,
        'title': 'Devis',
        'dateLabel': '10/05/2026',
        'dueDateLabel': 'Valable 30 jours',
        'clientName': 'Client',
        'technicianName': 'Tech',
        'paymentMethodLabel': 'CB',
        'notes': '',
        'items': [
          {'label': 'Produit', 'quantity': 2, 'unitPrice': 15.0},
        ],
      });

      expect(document.issuedAtIso, '2026-05-10T08:30:00');
      expect(document.dueAtIso, isEmpty);
      expect(document.currencyCode, 'EUR');
      expect(document.taxLabel, 'TVA');
      expect(document.taxRate, 20);
      expect(document.vatRate, 20);
      expect(document.dateLabel, '10/05/2026');
      expect(document.dueDateLabel, 'Valable 30 jours');
      expect(document.subtotalHt, 30);
      expect(document.vatAmount, 6);
      expect(document.total, 36);
      expect(document.amountDue, 26);
    });

    test('parse le nouveau format et reconstruit les labels legacy', () {
      final document = FinancialDocument.fromJson({
        'id': '2',
        'documentNumber': 'FAC-2026-001',
        'createdAtIso': '2026-06-01T09:00:00',
        'issuedAtIso': '2026-06-01',
        'dueAtIso': '2026-06-15',
        'currencyCode': 'USD',
        'taxLabel': 'Sales tax',
        'taxRate': 8.5,
        'type': 'invoice',
        'status': 'sent',
        'depositAmount': 0,
        'title': 'Invoice',
        'clientName': 'Client',
        'technicianName': 'Tech',
        'paymentMethodLabel': 'Wire',
        'notes': '',
        'items': [
          {'label': 'Service', 'quantity': 1, 'unitPrice': 100.0},
        ],
      });

      expect(document.issuedAtIso, '2026-06-01');
      expect(document.dueAtIso, '2026-06-15');
      expect(document.currencyCode, 'USD');
      expect(document.taxLabel, 'Sales tax');
      expect(document.taxRate, 8.5);
      expect(document.vatRate, 8.5);
      expect(document.dateLabel, '01/06/2026');
      expect(document.dueDateLabel, '15/06/2026');
    });

    test('toJson ecrit les nouveaux champs et garde la compatibilite legacy',
        () {
      final document = FinancialDocument(
        id: '3',
        documentNumber: 'FAC-2026-002',
        createdAtIso: '2026-06-02T10:00:00',
        issuedAtIso: '2026-06-02',
        dueAtIso: '2026-06-20',
        currencyCode: 'GBP',
        taxLabel: 'VAT',
        taxRate: 20,
        type: FinancialDocumentType.invoice,
        status: FinancialDocumentStatus.sent,
        depositAmount: 25,
        title: 'Invoice',
        dateLabel: '02/06/2026',
        dueDateLabel: '20/06/2026',
        clientName: 'Client',
        technicianName: 'Tech',
        paymentMethodLabel: 'Card',
        notes: '',
        items: const [
          FinancialLineItem(label: 'Service', quantity: 1, unitPrice: 120),
        ],
      );

      final json = document.toJson();

      expect(json['issuedAtIso'], '2026-06-02');
      expect(json['dueAtIso'], '2026-06-20');
      expect(json['currencyCode'], 'GBP');
      expect(json['taxLabel'], 'VAT');
      expect(json['taxRate'], 20);
      expect(json['vatRate'], 20);
      expect(json['dateLabel'], '02/06/2026');
      expect(json['dueDateLabel'], '20/06/2026');
    });
  });
}
