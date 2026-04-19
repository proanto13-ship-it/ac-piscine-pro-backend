import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'l10n/app_localizations.dart';
import 'models/company_profile.dart';
import 'models/feature_gate.dart';
import 'models/financial_document.dart';
import 'models/plan.dart';
import 'models/subscription.dart';
import 'models/team_member.dart';
import 'pages/pricing_page.dart';
import 'services/document_share_service.dart';
import 'services/document_number_service.dart';
import 'services/pdf_service.dart';

class FinancialDocumentPage extends StatefulWidget {
  final String clientName;
  final String dateLabel;
  final CompanyProfile companyProfile;
  final Subscription subscription;
  final FinancialDocumentType type;
  final List<FinancialLineItem> initialItems;
  final List<FinancialDocument> existingDocuments;
  final List<TeamMember> teamMembers;
  final Future<void> Function(FinancialDocument document)? onSave;

  const FinancialDocumentPage({
    super.key,
    required this.clientName,
    required this.dateLabel,
    required this.companyProfile,
    required this.subscription,
    required this.type,
    required this.initialItems,
    required this.existingDocuments,
    required this.teamMembers,
    this.onSave,
  });

  @override
  State<FinancialDocumentPage> createState() => _FinancialDocumentPageState();
}

class _FinancialDocumentPageState extends State<FinancialDocumentPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _technicianController;
  late final TextEditingController _notesController;
  late final TextEditingController _dueDateController;
  late final TextEditingController _vatRateController;
  late final TextEditingController _depositController;
  late final TextEditingController _paymentMethodController;
  late List<FinancialLineItem> _items;
  late final String _documentNumber;
  late FinancialDocumentStatus _status;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final l10n = AppLocalizations.of(context)!;
    _titleController = TextEditingController(
      text: widget.type == FinancialDocumentType.quote
          ? l10n.financialDocumentDefaultQuoteTitle
          : l10n.financialDocumentDefaultInvoiceTitle,
    );
    _technicianController = TextEditingController(
      text: widget.companyProfile.technicianDefaultName,
    );
    _notesController = TextEditingController();
    _dueDateController = TextEditingController(
      text: widget.type == FinancialDocumentType.quote
          ? l10n.quoteValidityDefault
          : l10n.invoiceDueDefault,
    );
    _vatRateController = TextEditingController(text: '20');
    _depositController = TextEditingController(text: '0');
    _paymentMethodController = TextEditingController(
      text: widget.type == FinancialDocumentType.quote
          ? l10n.quoteDepositPaymentDefault
          : l10n.invoicePaymentMethodDefault,
    );
    _items = List<FinancialLineItem>.from(widget.initialItems);
    _documentNumber = _buildDocumentNumber(widget.type);
    _status = widget.type == FinancialDocumentType.quote
        ? FinancialDocumentStatus.draft
        : FinancialDocumentStatus.sent;
    _initialized = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _technicianController.dispose();
    _notesController.dispose();
    _dueDateController.dispose();
    _vatRateController.dispose();
    _depositController.dispose();
    _paymentMethodController.dispose();
    super.dispose();
  }

  FinancialDocument _buildDocument() {
    final vatRate =
        double.tryParse(_vatRateController.text.trim().replaceAll(',', '.')) ??
            20;
    final depositAmount =
        double.tryParse(_depositController.text.trim().replaceAll(',', '.')) ??
            0;
    return FinancialDocument(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      documentNumber: _documentNumber,
      createdAtIso: DateTime.now().toIso8601String(),
      issuedAtIso: DateTime.now().toIso8601String(),
      currencyCode: widget.companyProfile.currencyCode,
      taxLabel: widget.companyProfile.localeCode.toLowerCase().startsWith('en')
          ? 'VAT'
          : 'TVA',
      type: widget.type,
      status: _status,
      vatRate: vatRate.clamp(0, 100).toDouble(),
      depositAmount: depositAmount < 0 ? 0 : depositAmount,
      title: _titleController.text.trim(),
      dateLabel: widget.dateLabel,
      dueDateLabel: _dueDateController.text.trim(),
      clientName: widget.clientName,
      technicianName: _technicianController.text.trim(),
      paymentMethodLabel: _paymentMethodController.text.trim(),
      notes: _notesController.text.trim(),
      items: _items,
    );
  }

  String _buildDocumentNumber(FinancialDocumentType type) {
    return DocumentNumberService.buildNextNumber(
      type: type,
      existingDocuments: widget.existingDocuments,
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (widget.onSave == null) return;
    await widget.onSave!(_buildDocument());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.type == FinancialDocumentType.quote
              ? l10n.financialDocumentSavedQuote
              : l10n.financialDocumentSavedInvoice,
        ),
      ),
    );
  }

  Future<void> _preview() async {
    if (!FeatureGate.isEnabled(
        widget.subscription, EntitlementFlag.pdfExport)) {
      await showUpgradePaywall(
        context,
        subscription: widget.subscription,
        availablePlans: const [Plan.free, Plan.pro],
        flag: EntitlementFlag.pdfExport,
      );
      return;
    }
    final doc = _buildDocument();
    final bytes = await PdfService.generateFinancialDocumentPdf(
      companyProfile: widget.companyProfile,
      document: doc,
    );
    if (!mounted) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _share() async {
    if (!FeatureGate.isEnabled(
        widget.subscription, EntitlementFlag.pdfExport)) {
      await showUpgradePaywall(
        context,
        subscription: widget.subscription,
        availablePlans: const [Plan.free, Plan.pro],
        flag: EntitlementFlag.pdfExport,
      );
      return;
    }
    final doc = _buildDocument();
    final bytes = await PdfService.generateFinancialDocumentPdf(
      companyProfile: widget.companyProfile,
      document: doc,
    );
    await DocumentShareService.sharePdf(
      bytes: bytes,
      filename: DocumentShareService.safePdfFilename(
        '${doc.type == FinancialDocumentType.quote ? 'devis' : 'facture'}_${widget.clientName}_${doc.documentNumber.isEmpty ? doc.id : doc.documentNumber}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vatRate =
        double.tryParse(_vatRateController.text.trim().replaceAll(',', '.')) ??
            20;
    final depositAmount =
        double.tryParse(_depositController.text.trim().replaceAll(',', '.')) ??
            0;
    final subtotalHt = _items.fold<double>(0, (sum, item) => sum + item.total);
    final vatAmount = subtotalHt * (vatRate / 100);
    final totalTtc = subtotalHt + vatAmount;
    final amountDue =
        (totalTtc - depositAmount).clamp(0, double.infinity).toDouble();
    final title = widget.type == FinancialDocumentType.quote
        ? l10n.createQuoteTitle
        : l10n.createInvoiceTitle;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _share,
            tooltip: l10n.share,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            l10n.documentSectionTitle,
            [
              _infoLine(l10n.numberLabel, _documentNumber),
              const SizedBox(height: 12),
              if (widget.teamMembers.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: _technicianController.text.isEmpty
                      ? widget.teamMembers.first.name
                      : _technicianController.text,
                  decoration: InputDecoration(
                    labelText: l10n.teamTechnicianLabel,
                    border: OutlineInputBorder(),
                  ),
                  items: widget.teamMembers
                      .where((member) => member.active)
                      .map(
                        (member) => DropdownMenuItem(
                          value: member.name,
                          child: Text(member.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    _technicianController.text = value;
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
              ],
              _field(l10n.titleLabel, _titleController),
              const SizedBox(height: 12),
              _field(l10n.technicianLabel, _technicianController),
              const SizedBox(height: 12),
              DropdownButtonFormField<FinancialDocumentStatus>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: l10n.statusLabel,
                  border: OutlineInputBorder(),
                ),
                items: _allowedStatuses(widget.type)
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(_statusLabel(status)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _status = value);
                },
              ),
              const SizedBox(height: 12),
              _field(
                widget.type == FinancialDocumentType.quote
                    ? l10n.quoteValidityLabel
                    : l10n.paymentDueLabel,
                _dueDateController,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _vatRateController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.taxRateFieldLabel,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _depositController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.depositPaidFieldLabel,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _field(
                widget.type == FinancialDocumentType.quote
                    ? l10n.quotePaymentTermsLabel
                    : l10n.invoicePaymentTermsLabel,
                _paymentMethodController,
              ),
            ],
          ),
          _section(
            l10n.billableLinesTitle,
            [
              ..._items.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.label),
                  subtitle: Text(
                    '${item.quantity.toStringAsFixed(1)} x ${item.unitPrice.toStringAsFixed(2)}€ HT',
                  ),
                  trailing: Text(
                    '${item.total.toStringAsFixed(2)}€ HT',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const Divider(),
              _totalLine(l10n.totalExcludingTax, subtotalHt),
              const SizedBox(height: 6),
              _totalLine(
                '${l10n.defaultTaxLabel} (${_formatVatRate(vatRate)})',
                vatAmount,
              ),
              const SizedBox(height: 6),
              _totalLine(l10n.depositLabel, depositAmount),
              const SizedBox(height: 8),
              _totalLine(l10n.totalIncludingTax, totalTtc, emphasize: true),
              const SizedBox(height: 6),
              _totalLine(
                widget.type == FinancialDocumentType.quote
                    ? l10n.remainingEstimate
                    : l10n.netToPay,
                amountDue,
                emphasize: true,
              ),
            ],
          ),
          _section(
            l10n.notesTitle,
            [
              _field(
                l10n.mentionsRemarksLabel,
                _notesController,
                maxLines: 4,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l10n.save),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _preview,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(l10n.preview),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<FinancialDocumentStatus> _allowedStatuses(FinancialDocumentType type) {
    return type == FinancialDocumentType.quote
        ? const [
            FinancialDocumentStatus.draft,
            FinancialDocumentStatus.sent,
            FinancialDocumentStatus.approved,
          ]
        : const [
            FinancialDocumentStatus.draft,
            FinancialDocumentStatus.sent,
            FinancialDocumentStatus.paid,
          ];
  }

  String _statusLabel(FinancialDocumentStatus status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case FinancialDocumentStatus.draft:
        return l10n.draftStatus;
      case FinancialDocumentStatus.sent:
        return l10n.sentStatus;
      case FinancialDocumentStatus.approved:
        return l10n.approvedStatus;
      case FinancialDocumentStatus.paid:
        return l10n.paidStatus;
    }
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Color(0xFF344054),
            fontFamily: 'Roboto',
          ),
          children: [
            TextSpan(
              text: '$label : ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _totalLine(String label, double value, {bool emphasize = false}) {
    final style = TextStyle(
      color: emphasize ? const Color(0xFF101828) : const Color(0xFF344054),
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
      fontSize: emphasize ? 18 : 15,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text('${value.toStringAsFixed(2)}€', style: style),
      ],
    );
  }

  String _formatVatRate(double value) {
    return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}%';
  }
}
