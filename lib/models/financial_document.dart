enum FinancialDocumentType {
  quote,
  invoice,
}

enum FinancialDocumentStatus {
  draft,
  sent,
  approved,
  paid,
}

class FinancialLineItem {
  final String label;
  final double quantity;
  final double unitPrice;

  const FinancialLineItem({
    required this.label,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;

  factory FinancialLineItem.fromJson(Map<String, dynamic> json) {
    return FinancialLineItem(
      label: json['label'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };
}

class FinancialDocument {
  final String id;
  final String documentNumber;
  final String createdAtIso;
  final String issuedAtIso;
  final String dueAtIso;
  final String currencyCode;
  final String taxLabel;
  final double taxRate;
  final FinancialDocumentType type;
  final FinancialDocumentStatus status;
  final double depositAmount;
  final String title;
  final String dateLabel;
  final String dueDateLabel;
  final String clientName;
  final String technicianName;
  final String paymentMethodLabel;
  final String notes;
  final List<FinancialLineItem> items;
  final String updatedAtIso;
  final int version;
  final String deletedAtIso;

  FinancialDocument({
    required this.id,
    required this.documentNumber,
    required this.createdAtIso,
    String? issuedAtIso,
    String? dueAtIso,
    String? currencyCode,
    String? taxLabel,
    double? taxRate,
    required this.type,
    required this.status,
    double? vatRate,
    required this.depositAmount,
    required this.title,
    required this.dateLabel,
    required this.dueDateLabel,
    required this.clientName,
    required this.technicianName,
    required this.paymentMethodLabel,
    required this.notes,
    required this.items,
    String? updatedAtIso,
    int? version,
    String? deletedAtIso,
  })  : issuedAtIso = issuedAtIso ?? createdAtIso,
        dueAtIso = dueAtIso ?? '',
        currencyCode = currencyCode ?? 'EUR',
        taxLabel = taxLabel ?? 'TVA',
        taxRate = taxRate ?? vatRate ?? 20,
        updatedAtIso = updatedAtIso ?? createdAtIso,
        version = version ?? 1,
        deletedAtIso = deletedAtIso ?? '';

  double get vatRate => taxRate;

  double get subtotalHt => items.fold(0, (sum, item) => sum + item.total);
  double get vatAmount => subtotalHt * (vatRate / 100);
  double get total => subtotalHt + vatAmount;
  double get amountDue => (total - depositAmount).clamp(0, double.infinity);

  factory FinancialDocument.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? 'quote') == 'invoice'
        ? FinancialDocumentType.invoice
        : FinancialDocumentType.quote;
    final createdAtIso = json['createdAtIso'] ?? '';
    final issuedAtIso = json['issuedAtIso'] ?? createdAtIso;
    final dueAtIso = json['dueAtIso'] ?? '';
    return FinancialDocument(
      id: json['id'] ?? '',
      documentNumber: json['documentNumber'] ?? '',
      createdAtIso: createdAtIso,
      issuedAtIso: issuedAtIso,
      dueAtIso: dueAtIso,
      currencyCode: json['currencyCode'] ?? 'EUR',
      taxLabel: json['taxLabel'] ?? 'TVA',
      taxRate: (json['taxRate'] ?? json['vatRate'] ?? 20).toDouble(),
      type: type,
      status: _statusFromJson(
        json['status'],
        fallback: type == FinancialDocumentType.invoice
            ? FinancialDocumentStatus.sent
            : FinancialDocumentStatus.draft,
      ),
      depositAmount: (json['depositAmount'] ?? 0).toDouble(),
      title: json['title'] ?? '',
      dateLabel: json['dateLabel'] ?? _legacyDateLabelFromIso(issuedAtIso),
      dueDateLabel: json['dueDateLabel'] ?? _legacyDateLabelFromIso(dueAtIso),
      clientName: json['clientName'] ?? '',
      technicianName: json['technicianName'] ?? '',
      paymentMethodLabel: json['paymentMethodLabel'] ?? '',
      notes: json['notes'] ?? '',
      items: ((json['items'] ?? []) as List)
          .map((item) => FinancialLineItem.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      updatedAtIso: json['updatedAtIso'] ?? json['updatedAt'] ?? createdAtIso,
      version: json['version'] is int
          ? json['version'] as int
          : int.tryParse(json['version']?.toString() ?? '') ?? 1,
      deletedAtIso: json['deletedAtIso'] ?? json['deletedAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'documentNumber': documentNumber,
        'createdAtIso': createdAtIso,
        'issuedAtIso': issuedAtIso,
        'dueAtIso': dueAtIso,
        'currencyCode': currencyCode,
        'taxLabel': taxLabel,
        'taxRate': taxRate,
        'type': type == FinancialDocumentType.invoice ? 'invoice' : 'quote',
        'status': status.name,
        'vatRate': vatRate,
        'depositAmount': depositAmount,
        'title': title,
        'dateLabel': dateLabel,
        'dueDateLabel': dueDateLabel,
        'clientName': clientName,
        'technicianName': technicianName,
        'paymentMethodLabel': paymentMethodLabel,
        'notes': notes,
        'updatedAtIso': updatedAtIso,
        'updatedAt': updatedAtIso,
        'version': version,
        'deletedAtIso': deletedAtIso,
        'deletedAt': deletedAtIso,
        'items': items.map((item) => item.toJson()).toList(),
      };

  FinancialDocument copyWith({
    String? id,
    String? documentNumber,
    String? createdAtIso,
    String? issuedAtIso,
    String? dueAtIso,
    String? currencyCode,
    String? taxLabel,
    double? taxRate,
    FinancialDocumentType? type,
    FinancialDocumentStatus? status,
    double? vatRate,
    double? depositAmount,
    String? title,
    String? dateLabel,
    String? dueDateLabel,
    String? clientName,
    String? technicianName,
    String? paymentMethodLabel,
    String? notes,
    List<FinancialLineItem>? items,
    String? updatedAtIso,
    int? version,
    String? deletedAtIso,
  }) {
    return FinancialDocument(
      id: id ?? this.id,
      documentNumber: documentNumber ?? this.documentNumber,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      issuedAtIso: issuedAtIso ?? this.issuedAtIso,
      dueAtIso: dueAtIso ?? this.dueAtIso,
      currencyCode: currencyCode ?? this.currencyCode,
      taxLabel: taxLabel ?? this.taxLabel,
      taxRate: taxRate ?? vatRate ?? this.taxRate,
      type: type ?? this.type,
      status: status ?? this.status,
      depositAmount: depositAmount ?? this.depositAmount,
      title: title ?? this.title,
      dateLabel: dateLabel ?? this.dateLabel,
      dueDateLabel: dueDateLabel ?? this.dueDateLabel,
      clientName: clientName ?? this.clientName,
      technicianName: technicianName ?? this.technicianName,
      paymentMethodLabel: paymentMethodLabel ?? this.paymentMethodLabel,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      version: version ?? this.version,
      deletedAtIso: deletedAtIso ?? this.deletedAtIso,
    );
  }

  bool get isDeleted => deletedAtIso.trim().isNotEmpty;

  static FinancialDocumentStatus _statusFromJson(
    dynamic raw, {
    required FinancialDocumentStatus fallback,
  }) {
    switch (raw) {
      case 'draft':
        return FinancialDocumentStatus.draft;
      case 'sent':
        return FinancialDocumentStatus.sent;
      case 'approved':
        return FinancialDocumentStatus.approved;
      case 'paid':
        return FinancialDocumentStatus.paid;
      default:
        return fallback;
    }
  }

  static String _legacyDateLabelFromIso(dynamic rawIso) {
    final iso = rawIso?.toString() ?? '';
    if (iso.trim().isEmpty) return '';

    final value = DateTime.tryParse(iso);
    if (value == null) return iso;

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    if (value.hour == 0 && value.minute == 0) {
      return '$day/$month/$year';
    }

    return '$day/$month/$year $hour:$minute';
  }
}
