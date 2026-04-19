import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/company_profile.dart';
import '../models/financial_document.dart';
import '../models/intervention_ticket.dart';
import '../models/workspace_settings.dart';
import 'app_logger.dart';
import 'formatting_service.dart';
import 'onboarding_progress_service.dart';

class PdfService {
  static const int maxEmbeddedPhotos = 4;

  static Future<Uint8List> generateDiagnosticPdf({
    required CompanyProfile companyProfile,
    required String clientName,
    required String date,
    required double ph,
    required double chlore,
    required double tac,
    required double th,
    required double stabilisant,
    required String observation,
    required int score,
    required double volumeM3,
    required double lsi,
    required String lsiInterpretation,
    required String urgenceLabel,
    required List<String> pourquoiMaintenant,
    required String explicationSimple,
    required String interventionTitre,
    required List<String> ajustementChimique,
    required List<String> verificationTechnique,
    required List<String> validation,
    required String dureeEstimee,
    required String stabilisation,
    required List<String> diagnostic,
    required List<Map<String, dynamic>> produits,
    required double totalProduitsMin,
    required double totalProduitsMax,
    required double mainOeuvre,
    required double totalMin,
    required double totalMax,
    required bool showBudgetEstimates,
  }) async {
    await OnboardingProgressService.markFirstPdfGenerated();
    await AppLogger.event(
      'pdf_generated',
      category: 'pdf',
      data: {
        'type': 'diagnostic',
        'clientName': clientName,
      },
    );
    final regularFont =
        pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Regular.ttf"));

    final boldFont =
        pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Bold.ttf"));

    final reportNumber =
        "HZ-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
    final settings = _settingsForCompany(companyProfile);
    final logo = await _loadPdfLogo();

    final teal = PdfColor.fromHex("#0F6D6A");
    final lightGrey = PdfColor.fromHex("#F2F2F2");
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          buildBackground: (context) => pw.Container(
            color: PdfColor.fromHex("#FAFAFA"),
          ),
        ),
        build: (context) => [
          /// HEADER
          _buildHeader(
            title: companyProfile.companyName,
            subtitle: _label(settings,
                fr: 'Rapport technique', en: 'Technical report'),
            rightTitle: reportNumber,
            rightSubtitle: date,
            boldFont: boldFont,
            accentColor: teal,
            logo: logo,
          ),

          pw.SizedBox(height: 20),

          /// BLOC STATUT
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: score < 5
                  ? PdfColor.fromHex("#C62828") // ROUGE FONCÉ
                  : score < 8
                      ? PdfColor.fromHex("#F57C00") // ORANGE
                      : PdfColor.fromHex("#2E7D32"), // VERT
              borderRadius: pw.BorderRadius.circular(16),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      score < 5 ? "INTERVENTION URGENTE" : urgenceLabel,
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 20,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      "Indice LSI : ${lsi.toStringAsFixed(2)}",
                      style: const pw.TextStyle(color: PdfColors.white),
                    ),
                    pw.Text(
                      lsiInterpretation,
                      style: const pw.TextStyle(color: PdfColors.white),
                    ),
                  ],
                ),
                pw.Text(
                  "$score/10",
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 26,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          if (_hasCompanyDetails(companyProfile))
            _card(
              title: "Entreprise",
              boldFont: boldFont,
              color: lightGrey,
              children: _companyDetailsWidgets(companyProfile, settings),
            ),
          if (_hasCompanyDetails(companyProfile)) pw.SizedBox(height: 12),

          /// INFOS + MESURES
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _card(
                  title: "Informations client",
                  boldFont: boldFont,
                  color: lightGrey,
                  children: [
                    pw.Text("Client : $clientName"),
                    pw.Text("Date : $date"),
                    pw.Text("Volume : ${volumeM3.toStringAsFixed(1)} m³"),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _card(
                  title: "Mesures relevées",
                  boldFont: boldFont,
                  color: lightGrey,
                  children: [
                    pw.Text("pH : ${ph.toStringAsFixed(1)}"),
                    pw.Text("Chlore : ${chlore.toStringAsFixed(1)} ppm"),
                    pw.Text("TAC : ${tac.toStringAsFixed(0)} ppm"),
                    pw.Text("TH : ${th.toStringAsFixed(0)} ppm"),
                    pw.Text(
                        "Stabilisant : ${stabilisant.toStringAsFixed(0)} ppm"),
                  ],
                ),
              ),
            ],
          ),

          /// 4. Analyse experte
          _card(
            title: "Analyse experte",
            boldFont: boldFont,
            color: lightGrey,
            children: diagnostic.map((e) => pw.Text("• $e")).toList(),
          ),

          /// 5. Ce que ça veut dire
          _card(
            title: "Ce que ça veut dire concrètement",
            boldFont: boldFont,
            color: lightGrey,
            children: [
              pw.Text(explicationSimple),
            ],
          ),

          /// 6. Pourquoi intervenir
          _card(
            title: "Pourquoi intervenir",
            boldFont: boldFont,
            color: lightGrey,
            children: pourquoiMaintenant.map((e) => pw.Text("• $e")).toList(),
          ),
          _card(
            title: "Intervention proposée",
            boldFont: boldFont,
            color: lightGrey,
            children: [
              // Ajustement chimique
              pw.Text(
                interventionTitre,
                style: pw.TextStyle(font: boldFont),
              ),
              pw.SizedBox(height: 8),
              ...ajustementChimique.map((e) => pw.Text("• $e")),

              pw.SizedBox(height: 12),

              // Vérification technique
              pw.Text(
                "Vérification technique",
                style: pw.TextStyle(font: boldFont),
              ),
              pw.SizedBox(height: 6),
              ...verificationTechnique.map((e) => pw.Text("• $e")),

              pw.SizedBox(height: 12),

              // Validation
              pw.Text(
                "Validation",
                style: pw.TextStyle(font: boldFont),
              ),
              pw.SizedBox(height: 6),
              ...validation.map((e) => pw.Text("• $e")),

              pw.SizedBox(height: 12),

              pw.Text("Durée estimée : $dureeEstimee"),
              pw.Text("Stabilisation complète : $stabilisation"),
            ],
          ),

          if (produits.isNotEmpty)
            _card(
              title: "Produits recommandés",
              boldFont: boldFont,
              color: lightGrey,
              children: produits.map((p) {
                final qty = (p["qty"] as double).toStringAsFixed(1);
                final unit = p["unit"] as String;
                final min = (p["min"] as double);
                final max = (p["max"] as double);
                final base = "• ${p["label"]} ($qty $unit)";
                if (!showBudgetEstimates) {
                  return pw.Text(base);
                }
                return pw.Text(
                  "$base - ${_formatBudgetRange(min, max, settings)}",
                );
              }).toList(),
            ),

          _card(
            title: "Chiffrage",
            boldFont: boldFont,
            color: lightGrey,
            children: showBudgetEstimates
                ? [
                    pw.Text(
                      "Basé sur vos tarifs internes modifiables.",
                      style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      "Produits : ${_formatBudgetRange(totalProduitsMin, totalProduitsMax, settings)}",
                    ),
                    pw.Text(
                      "Main d'œuvre : ${FormattingService.formatCurrency(mainOeuvre, settings)}",
                    ),
                    pw.Text(
                      "Total : ${_formatBudgetRange(totalMin, totalMax, settings)}",
                    ),
                  ]
                : [
                    pw.Text(
                      "Estimations budgétaires désactivées.",
                      style: pw.TextStyle(font: boldFont),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      "Activez le budget estimatif et adaptez vos tarifs internes dans Réglages > Tarifs internes.",
                    ),
                  ],
          ),

          pw.SizedBox(height: 20),
          pw.Divider(),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "HydrAzur Pro",
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 9,
                  color: teal,
                ),
              ),
              pw.Text(
                "Document généré automatiquement",
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateInterventionTicketPdf({
    required CompanyProfile companyProfile,
    required InterventionTicketData ticket,
    Uint8List? signatureBytes,
    List<Uint8List> photoBytes = const [],
  }) async {
    await OnboardingProgressService.markFirstPdfGenerated();
    await AppLogger.event(
      'pdf_generated',
      category: 'pdf',
      data: {
        'type': 'intervention',
        'clientName': ticket.clientName,
      },
    );
    final regularFont =
        pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Regular.ttf"));
    final boldFont =
        pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Bold.ttf"));

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );
    final settings = _settingsForCompany(companyProfile);
    final logo = await _loadPdfLogo();

    final teal = PdfColor.fromHex("#0F6D6A");
    final lightGrey = PdfColor.fromHex("#F2F4F7");

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          buildBackground: (_) =>
              pw.Container(color: PdfColor.fromHex("#FAFAFA")),
        ),
        build: (_) => [
          _buildHeader(
            title: companyProfile.companyName,
            subtitle: _label(
              settings,
              fr: "Bon d'intervention",
              en: 'Service ticket',
            ),
            rightTitle: ticket.clientName,
            rightSubtitle: ticket.dateLabel,
            boldFont: boldFont,
            accentColor: teal,
            logo: logo,
          ),
          pw.SizedBox(height: 18),
          _card(
            title: "Intervenants",
            boldFont: boldFont,
            color: lightGrey,
            children: [
              pw.Text("Technicien : ${ticket.technicianName}"),
              pw.Text("Client / représentant : ${ticket.clientRepresentative}"),
            ],
          ),
          if (_hasCompanyDetails(companyProfile))
            _card(
              title: "Entreprise",
              boldFont: boldFont,
              color: lightGrey,
              children: _companyDetailsWidgets(companyProfile, settings),
            ),
          _card(
            title: "Synthèse bassin",
            boldFont: boldFont,
            color: lightGrey,
            children: [
              pw.Text("Bassin : ${ticket.poolSummary}"),
              pw.Text("Chiffrage : ${ticket.estimateLabel}"),
              pw.Text("Suivi : ${ticket.followUpLabel}"),
            ],
          ),
          _card(
            title: "Intervention réalisée",
            boldFont: boldFont,
            color: lightGrey,
            children: [
              pw.Text(ticket.interventionSummary.isEmpty
                  ? "Aucune intervention détaillée."
                  : ticket.interventionSummary),
            ],
          ),
          _card(
            title: "Recommandations",
            boldFont: boldFont,
            color: lightGrey,
            children: [
              pw.Text(ticket.recommendations.isEmpty
                  ? "Aucune recommandation complémentaire."
                  : ticket.recommendations),
              if (ticket.accessNotes.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  "Accès / remarques",
                  style: pw.TextStyle(font: boldFont),
                ),
                pw.SizedBox(height: 4),
                pw.Text(ticket.accessNotes),
              ],
            ],
          ),
          if (photoBytes.isNotEmpty)
            _card(
              title: "Photos d'intervention",
              boldFont: boldFont,
              color: lightGrey,
              children: [
                pw.Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: photoBytes
                      .take(maxEmbeddedPhotos)
                      .map(
                        (bytes) => pw.Container(
                          width: 120,
                          height: 90,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                              color: PdfColor.fromHex("#D0D5DD"),
                            ),
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Image(
                            pw.MemoryImage(bytes),
                            fit: pw.BoxFit.cover,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          _card(
            title: "Validation",
            boldFont: boldFont,
            color: lightGrey,
            children: [
              pw.Text(
                "Chiffrage validé : ${ticket.estimateApproved ? "Oui" : "Non"}",
              ),
              pw.Text(
                "Intervention réalisée : ${ticket.interventionCompleted ? "Oui" : "Non"}",
              ),
              pw.Text(
                "Contrôle de suivi à programmer : ${ticket.followUpRequired ? "Oui" : "Non"}",
              ),
            ],
          ),
          _card(
            title: "Signature client",
            boldFont: boldFont,
            color: lightGrey,
            children: [
              if (signatureBytes != null)
                pw.Container(
                  height: 120,
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromHex("#D0D5DD")),
                    borderRadius: pw.BorderRadius.circular(12),
                    color: PdfColors.white,
                  ),
                  child: pw.Image(
                    pw.MemoryImage(signatureBytes),
                    fit: pw.BoxFit.contain,
                  ),
                )
              else
                pw.Container(
                  height: 120,
                  width: double.infinity,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromHex("#D0D5DD")),
                    borderRadius: pw.BorderRadius.circular(12),
                    color: PdfColors.white,
                  ),
                  child: pw.Text("Signature non renseignée"),
                ),
              pw.SizedBox(height: 8),
              pw.Text("Nom signataire : ${ticket.clientRepresentative}"),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateFinancialDocumentPdf({
    required CompanyProfile companyProfile,
    required FinancialDocument document,
  }) async {
    await OnboardingProgressService.markFirstPdfGenerated();
    await AppLogger.event(
      'pdf_generated',
      category: 'pdf',
      data: {
        'type': document.type.name,
        'clientName': document.clientName,
        'documentNumber': document.documentNumber,
      },
    );
    final regularFont =
        pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Regular.ttf"));
    final boldFont =
        pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Bold.ttf"));

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );
    final settings = _settingsForCompany(
      companyProfile,
      currencyCode: document.currencyCode,
    );
    final logo = await _loadPdfLogo();

    final teal = PdfColor.fromHex("#0F6D6A");
    final lightGrey = PdfColor.fromHex("#F2F4F7");
    final slate = PdfColor.fromHex("#101828");

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          buildBackground: (_) =>
              pw.Container(color: PdfColor.fromHex("#FAFAFA")),
        ),
        build: (_) => [
          _buildHeader(
            title: companyProfile.companyName,
            subtitle: document.type == FinancialDocumentType.quote
                ? _label(settings, fr: 'Devis', en: 'Quote')
                : _label(settings, fr: 'Facture', en: 'Invoice'),
            rightTitle: document.documentNumber.isEmpty
                ? _label(settings, fr: 'Sans numéro', en: 'No number')
                : document.documentNumber,
            rightSubtitle: _displayIssuedAt(document, settings),
            badgeText: _financialStatusLabel(document.status, settings),
            boldFont: boldFont,
            accentColor: teal,
            logo: logo,
          ),
          pw.SizedBox(height: 18),
          _card(
            title: "Document",
            boldFont: boldFont,
            color: lightGrey,
            children: [
              pw.Text(
                "${_label(settings, fr: 'Statut', en: 'Status')} : ${_financialStatusLabel(document.status, settings)}",
              ),
              pw.Text(
                  "${_label(settings, fr: 'Titre', en: 'Title')} : ${document.title}"),
              pw.Text(
                  "${_label(settings, fr: 'Client', en: 'Client')} : ${document.clientName}"),
              if (document.dueDateLabel.isNotEmpty)
                pw.Text(
                  document.type == FinancialDocumentType.quote
                      ? "${_label(settings, fr: 'Validité', en: 'Validity')} : ${_displayDueAt(document, settings)}"
                      : "${_label(settings, fr: 'Échéance', en: 'Due date')} : ${_displayDueAt(document, settings)}",
                ),
              if (document.paymentMethodLabel.isNotEmpty)
                pw.Text(
                  document.type == FinancialDocumentType.quote
                      ? "${_label(settings, fr: 'Règlement', en: 'Payment')} : ${document.paymentMethodLabel}"
                      : "${_label(settings, fr: 'Mode de règlement', en: 'Payment method')} : ${document.paymentMethodLabel}",
                ),
              pw.Text(
                "${_label(settings, fr: 'Technicien', en: 'Technician')} : ${document.technicianName.isEmpty ? "-" : document.technicianName}",
              ),
            ],
          ),
          if (companyProfile.phone.isNotEmpty ||
              companyProfile.email.isNotEmpty ||
              companyProfile.address.isNotEmpty ||
              companyProfile.website.isNotEmpty ||
              companyProfile.hasBusinessRegistration ||
              companyProfile.hasTaxRegistration)
            _card(
              title: "Entreprise",
              boldFont: boldFont,
              color: lightGrey,
              children: _companyDetailsWidgets(companyProfile, settings),
            ),
          _card(
            title: "Détail",
            boldFont: boldFont,
            color: lightGrey,
            children: [
              pw.TableHelper.fromTextArray(
                headers: [
                  _label(settings, fr: 'Désignation', en: 'Description'),
                  _label(settings, fr: 'Qté', en: 'Qty'),
                  _label(settings, fr: 'PU HT', en: 'Unit price'),
                  _label(settings, fr: 'Total HT', en: 'Subtotal'),
                ],
                data: document.items
                    .map(
                      (item) => [
                        item.label,
                        item.quantity.toStringAsFixed(1),
                        FormattingService.formatCurrency(
                            item.unitPrice, settings),
                        FormattingService.formatCurrency(item.total, settings),
                      ],
                    )
                    .toList(),
                headerStyle: pw.TextStyle(
                  font: boldFont,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: teal,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(6),
              ),
            ],
          ),
          _card(
            title: "Récapitulatif financier",
            boldFont: boldFont,
            color: lightGrey,
            children: [
              _summaryLine(
                label: _label(settings, fr: 'Total HT', en: 'Subtotal'),
                value: FormattingService.formatCurrency(
                  document.subtotalHt,
                  settings,
                ),
                boldFont: boldFont,
                color: slate,
              ),
              pw.SizedBox(height: 6),
              _summaryLine(
                label:
                    '${document.taxLabel} (${_formatRate(document.vatRate)})',
                value: FormattingService.formatCurrency(
                  document.vatAmount,
                  settings,
                ),
                boldFont: boldFont,
                color: slate,
              ),
              pw.SizedBox(height: 6),
              _summaryLine(
                label: _label(settings, fr: 'Acompte', en: 'Deposit'),
                value: FormattingService.formatCurrency(
                  document.depositAmount,
                  settings,
                ),
                boldFont: boldFont,
                color: slate,
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: teal,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          document.type == FinancialDocumentType.quote
                              ? _label(settings,
                                  fr: 'Reste à prévoir',
                                  en: 'Estimated balance')
                              : _label(settings,
                                  fr: 'Net à payer', en: 'Amount due'),
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 11,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _financialStatusLabel(document.status, settings),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            font: boldFont,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      FormattingService.formatCurrency(
                          document.amountDue, settings),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        font: boldFont,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (document.notes.isNotEmpty)
            _card(
              title: "Notes",
              boldFont: boldFont,
              color: lightGrey,
              children: [
                pw.Text(document.notes),
              ],
            ),
          if (companyProfile.legalMention.isNotEmpty)
            _card(
              title: "Mentions",
              boldFont: boldFont,
              color: lightGrey,
              children: [
                pw.Text(companyProfile.legalMention),
              ],
            ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _signatureBox(
                  title: document.type == FinancialDocumentType.quote
                      ? _label(settings,
                          fr: 'Bon pour accord', en: 'Customer approval')
                      : _label(settings,
                          fr: 'Règlement / validation client',
                          en: 'Customer payment / approval'),
                  boldFont: boldFont,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _signatureBox(
                  title: _label(settings,
                      fr: 'Technicien / société', en: 'Technician / company'),
                  boldFont: boldFont,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static String _formatBudgetRange(
    double min,
    double max,
    WorkspaceSettings settings,
  ) {
    if ((min - max).abs() < 0.01) {
      return FormattingService.formatCurrency(min, settings);
    }
    return '${FormattingService.formatCurrency(min, settings)} à ${FormattingService.formatCurrency(max, settings)}';
  }

  static bool _hasCompanyDetails(CompanyProfile companyProfile) {
    return companyProfile.phone.isNotEmpty ||
        companyProfile.email.isNotEmpty ||
        companyProfile.address.isNotEmpty ||
        companyProfile.website.isNotEmpty ||
        companyProfile.hasBusinessRegistration ||
        companyProfile.hasTaxRegistration;
  }

  static List<pw.Widget> _companyDetailsWidgets(
    CompanyProfile companyProfile,
    WorkspaceSettings settings,
  ) {
    return [
      if (companyProfile.phone.isNotEmpty)
        pw.Text(
            "${_label(settings, fr: 'Téléphone', en: 'Phone')} : ${companyProfile.phone}"),
      if (companyProfile.email.isNotEmpty)
        pw.Text(
            "${_label(settings, fr: 'Email', en: 'Email')} : ${companyProfile.email}"),
      if (companyProfile.address.isNotEmpty)
        pw.Text(
            "${_label(settings, fr: 'Adresse', en: 'Address')} : ${companyProfile.address}"),
      if (companyProfile.website.isNotEmpty)
        pw.Text(
            "${_label(settings, fr: 'Site', en: 'Website')} : ${companyProfile.website}"),
      if (companyProfile.hasBusinessRegistration)
        pw.Text(
          "${companyProfile.businessRegistrationDisplayLabel} : ${companyProfile.businessRegistrationValue}",
        ),
      if (companyProfile.hasTaxRegistration)
        pw.Text(
          "${_label(settings, fr: 'Identifiant fiscal', en: 'Tax ID')} : ${companyProfile.taxRegistrationValue}",
        ),
    ];
  }

  static String _financialStatusLabel(
    FinancialDocumentStatus status,
    WorkspaceSettings settings,
  ) {
    switch (status) {
      case FinancialDocumentStatus.draft:
        return _label(settings, fr: 'Brouillon', en: 'Draft');
      case FinancialDocumentStatus.sent:
        return _label(settings, fr: 'Envoyé', en: 'Sent');
      case FinancialDocumentStatus.approved:
        return _label(settings, fr: 'Accepté', en: 'Approved');
      case FinancialDocumentStatus.paid:
        return _label(settings, fr: 'Payé', en: 'Paid');
    }
  }

  static String _formatRate(double value) {
    return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}%';
  }

  static pw.Widget _summaryLine({
    required String label,
    required String value,
    required pw.Font boldFont,
    required PdfColor color,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(color: color, fontSize: 12)),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: color,
            font: boldFont,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  static pw.Widget _signatureBox({
    required String title,
    required pw.Font boldFont,
  }) {
    return pw.Container(
      height: 92,
      margin: const pw.EdgeInsets.only(top: 2),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColor.fromHex("#D0D5DD")),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(font: boldFont, fontSize: 11),
          ),
          pw.Spacer(),
          pw.Container(height: 1, color: PdfColor.fromHex("#98A2B3")),
        ],
      ),
    );
  }

  static pw.Widget _card({
    required String title,
    required pw.Font boldFont,
    required PdfColor color,
    required List<pw.Widget> children,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 13,
              color: PdfColor.fromHex("#0F6D6A"),
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            height: 2,
            width: 30,
            color: PdfColor.fromHex("#0F6D6A"),
          ),
          pw.SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  static WorkspaceSettings _settingsForCompany(
    CompanyProfile companyProfile, {
    String? currencyCode,
  }) {
    return WorkspaceSettings(
      localeCode: companyProfile.localeCode,
      currencyCode: currencyCode ?? companyProfile.currencyCode,
      countryCode: companyProfile.countryCode,
      timeZoneId: WorkspaceSettings.defaults().timeZoneId,
      unitSystem: WorkspaceSettings.defaults().unitSystem,
    );
  }

  static String _label(
    WorkspaceSettings settings, {
    required String fr,
    required String en,
  }) {
    return settings.localeCode.toLowerCase().startsWith('en') ? en : fr;
  }

  static String _displayIssuedAt(
    FinancialDocument document,
    WorkspaceSettings settings,
  ) {
    if (document.issuedAtIso.trim().isNotEmpty) {
      return FormattingService.formatDateFromIso(
          document.issuedAtIso, settings);
    }
    return document.dateLabel;
  }

  static String _displayDueAt(
    FinancialDocument document,
    WorkspaceSettings settings,
  ) {
    if (document.dueAtIso.trim().isNotEmpty) {
      return FormattingService.formatDateFromIso(document.dueAtIso, settings);
    }
    return document.dueDateLabel;
  }

  static Future<pw.MemoryImage?> _loadPdfLogo() async {
    try {
      final bytes = (await rootBundle.load('icon.png')).buffer.asUint8List();
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _buildHeader({
    required String title,
    required String subtitle,
    required String rightTitle,
    required String rightSubtitle,
    required pw.Font boldFont,
    required PdfColor accentColor,
    pw.MemoryImage? logo,
    String? badgeText,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: accentColor,
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logo != null) ...[
                  pw.Container(
                    width: 46,
                    height: 46,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(width: 12),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 22,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        subtitle,
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (badgeText != null && badgeText.trim().isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(999),
                  ),
                  child: pw.Text(
                    badgeText,
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 10,
                      color: accentColor,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
              ],
              pw.Text(
                rightTitle,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 11,
                  color: PdfColors.white,
                ),
              ),
              if (rightSubtitle.trim().isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  rightSubtitle,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
