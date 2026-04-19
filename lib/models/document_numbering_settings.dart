class DocumentNumberingSettings {
  final String quotePrefix;
  final String invoicePrefix;
  final int sequencePadding;
  final bool includeYear;

  const DocumentNumberingSettings({
    required this.quotePrefix,
    required this.invoicePrefix,
    required this.sequencePadding,
    required this.includeYear,
  });

  factory DocumentNumberingSettings.defaults() {
    return const DocumentNumberingSettings(
      quotePrefix: 'DEV',
      invoicePrefix: 'FAC',
      sequencePadding: 3,
      includeYear: true,
    );
  }

  factory DocumentNumberingSettings.fromJson(Map<String, dynamic> json) {
    final defaults = DocumentNumberingSettings.defaults();
    return DocumentNumberingSettings(
      quotePrefix: json['quotePrefix'] ?? defaults.quotePrefix,
      invoicePrefix: json['invoicePrefix'] ?? defaults.invoicePrefix,
      sequencePadding:
          (json['sequencePadding'] ?? defaults.sequencePadding).toInt(),
      includeYear: json['includeYear'] ?? defaults.includeYear,
    );
  }

  Map<String, dynamic> toJson() => {
        'quotePrefix': quotePrefix,
        'invoicePrefix': invoicePrefix,
        'sequencePadding': sequencePadding,
        'includeYear': includeYear,
      };

  DocumentNumberingSettings copyWith({
    String? quotePrefix,
    String? invoicePrefix,
    int? sequencePadding,
    bool? includeYear,
  }) {
    return DocumentNumberingSettings(
      quotePrefix: quotePrefix ?? this.quotePrefix,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      sequencePadding: sequencePadding ?? this.sequencePadding,
      includeYear: includeYear ?? this.includeYear,
    );
  }
}
