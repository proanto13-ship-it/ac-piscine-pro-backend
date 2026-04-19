import 'dart:typed_data';
import '../services/ai_summary_service.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../financial_document_page.dart';
import '../intervention_sheet_page.dart';
import '../services/document_share_service.dart';
import '../services/pdf_service.dart';
import '../logic/diagnostic_logic.dart';
import '../models/company_profile.dart';
import '../models/feature_gate.dart';
import '../models/financial_document.dart';
import '../models/intervention_record.dart';
import '../models/plan.dart';
import '../models/pricing_settings.dart';
import '../models/subscription.dart';
import '../models/team_member.dart';
import '../pages/pricing_page.dart';

class DiagnosticPagePro extends StatefulWidget {
  final String clientName;
  final String dateLabel;
  final double ph;
  final double chlore;
  final double tac;
  final double th;
  final double stabilisant;
  final double temperature;
  final double lsi;
  final double stabilityScore;
  final String observation;
  final double volumeM3;
  final double? sel;
  final String treatmentType;
  final PricingSettings pricingSettings;
  final CompanyProfile companyProfile;
  final Subscription subscription;
  final List<FinancialDocument> existingDocuments;
  final List<TeamMember> teamMembers;
  final Future<void> Function(InterventionRecord record)? onSaveIntervention;
  final Future<void> Function(FinancialDocument document)?
      onSaveFinancialDocument;

  const DiagnosticPagePro({
    super.key,
    required this.clientName,
    required this.dateLabel,
    required this.ph,
    required this.chlore,
    required this.tac,
    required this.th,
    required this.stabilisant,
    required this.temperature,
    required this.lsi,
    required this.stabilityScore,
    required this.observation,
    required this.volumeM3,
    required this.sel,
    required this.treatmentType,
    required this.pricingSettings,
    required this.companyProfile,
    required this.subscription,
    required this.existingDocuments,
    required this.teamMembers,
    this.onSaveIntervention,
    this.onSaveFinancialDocument,
  });

  @override
  State<DiagnosticPagePro> createState() => _DiagnosticPageProState();
}

class _DiagnosticPageProState extends State<DiagnosticPagePro> {
  final GlobalKey _gaugeKey = GlobalKey();
  late double mainOeuvre;
  late TextEditingController _mainOeuvreController;

  String? _aiSummary;
  bool _isGeneratingAiSummary = false;
  bool _showAiSummary = false;

  Future<Uint8List> _buildDiagnosticPdfBytes(DiagnosticResult result) {
    final showBudgetEstimates = widget.pricingSettings.showBudgetEstimates;
    final produitsMin = result.totalProduitsMin;
    final produitsMax = result.totalProduitsMax;
    final mo = (produitsMax <= 0) ? 0.0 : mainOeuvre;
    final totalMin = produitsMin + mo;
    final totalMax = produitsMax + mo;

    return PdfService.generateDiagnosticPdf(
      companyProfile: widget.companyProfile,
      clientName: widget.clientName,
      date: widget.dateLabel,
      ph: widget.ph,
      chlore: widget.chlore,
      tac: widget.tac,
      th: widget.th,
      stabilisant: widget.stabilisant,
      observation: widget.observation,
      score: result.score,
      volumeM3: widget.volumeM3,
      lsi: result.lsi,
      lsiInterpretation: result.lsiInterpretation,
      urgenceLabel: result.urgenceLabel,
      pourquoiMaintenant: result.whyNow,
      explicationSimple: result.simpleExplanation,
      interventionTitre: result.interventionTitre,
      ajustementChimique: result.ajustementChimique,
      verificationTechnique: result.verificationTechnique,
      validation: result.validation,
      dureeEstimee: result.dureeEstimee,
      stabilisation: result.stabilisation,
      diagnostic: result.analyse,
      produits: result.produits
          .map(
            (p) => {
              "label": p.label,
              "qty": p.qty,
              "unit": p.unit,
              "min": p.budgetMin,
              "max": p.budgetMax,
            },
          )
          .toList(),
      totalProduitsMin: result.totalProduitsMin,
      totalProduitsMax: result.totalProduitsMax,
      mainOeuvre: mo,
      totalMin: totalMin,
      totalMax: totalMax,
      showBudgetEstimates: showBudgetEstimates,
    );
  }

  Future<void> _shareDiagnosticPdf(DiagnosticResult result) async {
    if (!FeatureGate.isEnabled(
      widget.subscription,
      EntitlementFlag.pdfExport,
    )) {
      await showUpgradePaywall(
        context,
        subscription: widget.subscription,
        availablePlans: const [Plan.free, Plan.pro],
        flag: EntitlementFlag.pdfExport,
      );
      return;
    }
    final pdf = await _buildDiagnosticPdfBytes(result);
    await DocumentShareService.sharePdf(
      bytes: pdf,
      filename: DocumentShareService.safePdfFilename(
        'diagnostic_${widget.clientName}_${widget.dateLabel}',
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    mainOeuvre = widget.pricingSettings.defaultMainOeuvre;
    _mainOeuvreController = TextEditingController(
      text: mainOeuvre.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _mainOeuvreController.dispose();
    super.dispose();
  }

  Future<void> _generateAiSummary(DiagnosticResult result) async {
    setState(() {
      _isGeneratingAiSummary = true;
      _showAiSummary = true;
    });

    final summary = await AiSummaryService.generateSummary(
      clientName: widget.clientName,
      ph: widget.ph,
      chlore: widget.chlore,
      tac: widget.tac,
      th: widget.th,
      stabilisant: widget.stabilisant,
      sel: widget.sel,
      lsi: result.lsi,
      score: result.score,
      lsiInterpretation: result.lsiInterpretation,
      analyse: result.analyse,
      ajustementChimique: result.ajustementChimique,
      produits: result.produits,
    );

    if (!mounted) return;

    setState(() {
      _aiSummary = summary;
      _isGeneratingAiSummary = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = DiagnosticLogic.build(
      ph: widget.ph,
      chlore: widget.chlore,
      tac: widget.tac,
      th: widget.th,
      stabilisant: widget.stabilisant,
      volumeM3: widget.volumeM3,
      observation: widget.observation,
      treatmentType: widget.treatmentType,
      sel: widget.sel,
      temperature: widget.temperature,
      pricingSettings: widget.pricingSettings,
    );

    final showBudgetEstimates = widget.pricingSettings.showBudgetEstimates;
    final produitsMin = result.totalProduitsMin;
    final produitsMax = result.totalProduitsMax;
    final mo = (produitsMax <= 0) ? 0.0 : mainOeuvre;
    final totalMin = produitsMin + mo;
    final totalMax = produitsMax + mo;
    final ajustements = result.ajustementChimique;
    final documentItems = [
      ...result.produits.map(
        (p) => FinancialLineItem(
          label: p.label,
          quantity: p.qty,
          unitPrice: p.qty <= 0 ? 0 : (p.budgetMax / p.qty),
        ),
      ),
      if (showBudgetEstimates && mo > 0)
        FinancialLineItem(
          label: 'Main d\'oeuvre',
          quantity: 1,
          unitPrice: mo,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _shareDiagnosticPdf(result),
            tooltip: 'Partager',
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _heroCard(result),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Mesures relevées',
            subtitle: 'Valeurs terrain utilisées pour le diagnostic.',
            icon: Icons.water_drop_outlined,
            accent: const Color(0xFF0F6E7C),
            child: _measureGrid(),
          ),
          _sectionCard(
            title: 'Décision d’intervention',
            subtitle: 'Ce qu’il faut faire maintenant et pourquoi.',
            icon: Icons.flash_on,
            accent: const Color(0xFFB54708),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _calloutText(result.simpleExplanation),
                const SizedBox(height: 12),
                _bulletList(result.whyNow),
              ],
            ),
          ),
          _sectionCard(
            title: 'Plan d’intervention',
            subtitle: 'Actions à réaliser sur place.',
            icon: Icons.build_circle_outlined,
            accent: const Color(0xFF027A48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _subsectionTitle('Ajustement chimique'),
                _bulletList(ajustements),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _infoPill(
                      Icons.timer_outlined,
                      'Durée estimée',
                      result.dureeEstimee,
                    ),
                    _infoPill(
                      Icons.schedule_outlined,
                      'Stabilisation',
                      result.stabilisation,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (result.produits.isNotEmpty)
            _sectionCard(
              title: 'Produits recommandés',
              subtitle:
                  'Quantités estimatives calculées sur le volume du bassin.',
              icon: Icons.inventory_2_outlined,
              accent: const Color(0xFF6941C6),
              child: Column(
                children: result.produits
                    .map(
                      (p) => _productTile(
                        label: p.label,
                        quantity:
                            '${p.qty.toStringAsFixed(p.qty < 1 ? 2 : 1)} ${p.unit}',
                        budget: showBudgetEstimates
                            ? _formatBudgetRange(p.budgetMin, p.budgetMax)
                            : null,
                      ),
                    )
                    .toList(),
              ),
            ),
          _sectionCard(
            title: 'Chiffrage',
            subtitle: showBudgetEstimates
                ? 'Synthèse économique basée sur vos tarifs internes.'
                : 'Activez le budget estimatif dans les réglages entreprise.',
            icon: Icons.euro_outlined,
            accent: const Color(0xFF0F6E7C),
            child: showBudgetEstimates
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _priceRow(
                        'Produits',
                        _formatBudgetRange(
                          result.totalProduitsMin,
                          result.totalProduitsMax,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _mainOeuvreController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: "Main d'œuvre (€)",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            mainOeuvre =
                                double.tryParse(value.replaceAll(',', '.')) ??
                                    0;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      _priceRow(
                        'Total estimatif',
                        _formatBudgetRange(totalMin, totalMax),
                        emphasize: true,
                      ),
                    ],
                  )
                : const Text(
                    "Activez le budget estimatif et adaptez vos tarifs internes dans Réglages entreprise.",
                  ),
          ),
          _sectionCard(
            title: 'Analyse technique',
            subtitle: 'Lecture détaillée du bassin, stabilité et contrôles.',
            icon: Icons.analytics_outlined,
            accent: const Color(0xFF184663),
            child: Column(
              children: [
                _balanceTaylorWidget(
                  result.lsi,
                  result.lsiInterpretation,
                  result.score,
                ),
                const SizedBox(height: 16),
                _subsectionTitle('Analyse experte'),
                const SizedBox(height: 10),
                _bulletList(result.analyse),
                const SizedBox(height: 12),
                _subsectionTitle('Vérification technique'),
                const SizedBox(height: 10),
                _bulletList(result.verificationTechnique),
                const SizedBox(height: 12),
                _subsectionTitle('Validation'),
                const SizedBox(height: 10),
                _bulletList(result.validation),
              ],
            ),
          ),
          _sectionCard(
            title: 'Documents et actions',
            subtitle:
                'Exploiter le diagnostic sur le terrain ou pour le client.',
            icon: Icons.description_outlined,
            accent: const Color(0xFF0F6E7C),
            child: Column(
              children: [
                _actionRow(
                  primaryLabel: 'Rapport PDF',
                  primaryIcon: Icons.picture_as_pdf_outlined,
                  onPrimaryTap: () async {
                    if (!FeatureGate.isEnabled(
                      widget.subscription,
                      EntitlementFlag.pdfExport,
                    )) {
                      await showUpgradePaywall(
                        context,
                        subscription: widget.subscription,
                        availablePlans: const [Plan.free, Plan.pro],
                        flag: EntitlementFlag.pdfExport,
                      );
                      return;
                    }
                    final pdf = await _buildDiagnosticPdfBytes(result);

                    await Printing.layoutPdf(
                      onLayout: (format) async => pdf,
                    );
                  },
                  secondaryLabel: 'Bon d’intervention',
                  secondaryIcon: Icons.assignment_turned_in_outlined,
                  onSecondaryTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InterventionSheetPage(
                          clientName: widget.clientName,
                          dateLabel: widget.dateLabel,
                          volumeM3: widget.volumeM3,
                          treatmentType: widget.treatmentType,
                          result: result,
                          estimateLabel: showBudgetEstimates
                              ? _formatBudgetRange(totalMin, totalMax)
                              : 'Chiffrage désactivé',
                          companyProfile: widget.companyProfile,
                          subscription: widget.subscription,
                          teamMembers: widget.teamMembers,
                          onSaveRecord: widget.onSaveIntervention,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _actionRow(
                  primaryLabel: 'Devis',
                  primaryIcon: Icons.request_quote_outlined,
                  onPrimaryTap: documentItems.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FinancialDocumentPage(
                                clientName: widget.clientName,
                                dateLabel: widget.dateLabel,
                                companyProfile: widget.companyProfile,
                                subscription: widget.subscription,
                                type: FinancialDocumentType.quote,
                                initialItems: documentItems,
                                existingDocuments: widget.existingDocuments,
                                teamMembers: widget.teamMembers,
                                onSave: widget.onSaveFinancialDocument,
                              ),
                            ),
                          );
                        },
                  secondaryLabel: 'Facture',
                  secondaryIcon: Icons.receipt_long_outlined,
                  onSecondaryTap: documentItems.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FinancialDocumentPage(
                                clientName: widget.clientName,
                                dateLabel: widget.dateLabel,
                                companyProfile: widget.companyProfile,
                                subscription: widget.subscription,
                                type: FinancialDocumentType.invoice,
                                initialItems: documentItems,
                                existingDocuments: widget.existingDocuments,
                                teamMembers: widget.teamMembers,
                                onSave: widget.onSaveFinancialDocument,
                              ),
                            ),
                          );
                        },
                ),
              ],
            ),
          ),
          _sectionCard(
            title: 'Synthèse du diagnostic',
            subtitle: 'Lecture reformulée, utile en second niveau.',
            icon: Icons.auto_awesome_outlined,
            accent: const Color(0xFF7A5AF8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAiSummary = !_showAiSummary;
                    });
                  },
                  icon: Icon(
                    _showAiSummary
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                  label: Text(
                    _showAiSummary
                        ? 'Masquer la synthèse'
                        : 'Afficher la synthèse',
                  ),
                ),
                if (_showAiSummary) ...[
                  const SizedBox(height: 12),
                  Text(
                    _aiSummary ??
                        'Appuyez sur le bouton ci-dessous pour générer une synthèse automatique.',
                    style: const TextStyle(
                      height: 1.45,
                      color: Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _isGeneratingAiSummary
                        ? null
                        : () => _generateAiSummary(result),
                    icon: _isGeneratingAiSummary
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      _isGeneratingAiSummary
                          ? 'Génération en cours...'
                          : _aiSummary == null
                              ? 'Générer la synthèse'
                              : 'Régénérer la synthèse',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatBudgetRange(double min, double max) {
    if ((min - max).abs() < 0.01) {
      return '${min.toStringAsFixed(0)}€';
    }
    return '${min.toStringAsFixed(0)}€ à ${max.toStringAsFixed(0)}€';
  }

  Widget _heroCard(DiagnosticResult result) {
    final scoreColor = _scoreColor(result.score);
    final urgencyColor = _urgencyColor(result.score);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9E5EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.clientName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF163C57),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.dateLabel,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _smallTag(Icons.pool_outlined, widget.treatmentType),
                        _smallTag(
                          Icons.water_outlined,
                          '${widget.volumeM3.toStringAsFixed(1)} m³',
                        ),
                      ],
                    ),
                    if (widget.observation.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _observationCard(widget.observation),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _scoreWidget(result.score),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: urgencyColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: urgencyColor.withValues(alpha: 0.20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.urgenceLabel,
                  style: TextStyle(
                    color: urgencyColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.statut,
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _measureGrid() {
    final measures = [
      ('pH', widget.ph.toStringAsFixed(1)),
      ('Chlore', '${widget.chlore.toStringAsFixed(1)} ppm'),
      ('TAC', '${widget.tac.toStringAsFixed(0)} ppm'),
      ('TH', '${widget.th.toStringAsFixed(0)} ppm'),
      ('Stabilisant', '${widget.stabilisant.toStringAsFixed(0)} ppm'),
      ('Température', '${widget.temperature.toStringAsFixed(0)}°C'),
      if (widget.sel != null && widget.sel! > 0)
        ('TDS / Sel', '${widget.sel!.toStringAsFixed(0)} ppm'),
    ];

    final rows = <Widget>[];
    for (var i = 0; i < measures.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(
              child: _metricTile(measures[i].$1, measures[i].$2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: i + 1 < measures.length
                  ? _metricTile(measures[i + 1].$1, measures[i + 1].$2)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      if (i + 2 < measures.length) {
        rows.add(const SizedBox(height: 10));
      }
    }
    return Column(children: rows);
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color accent,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E5EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Color(0xFF163C57),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _scoreWidget(int score) {
    return CircularPercentIndicator(
      radius: 52,
      lineWidth: 10,
      percent: score / 10,
      circularStrokeCap: CircularStrokeCap.round,
      progressColor: _scoreColor(score),
      backgroundColor: Colors.grey.shade200,
      center: Text(
        "$score/10",
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _metricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF163C57),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletList(List<String> items) {
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F6E7C),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        height: 1.4,
                        color: Color(0xFF344054),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _calloutText(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.45,
          color: Color(0xFF163C57),
        ),
      ),
    );
  }

  Widget _productTile({
    required String label,
    required String quantity,
    String? budget,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF163C57),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  quantity,
                  style: const TextStyle(color: Color(0xFF667085)),
                ),
              ],
            ),
          ),
          if (budget != null)
            Text(
              budget,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF184663),
              ),
            ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool emphasize = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: emphasize ? Colors.transparent : const Color(0xFFE4E7EC),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                color: const Color(0xFF344054),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: emphasize ? 18 : 15,
              color: const Color(0xFF163C57),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required String primaryLabel,
    required IconData primaryIcon,
    required VoidCallback? onPrimaryTap,
    required String secondaryLabel,
    required IconData secondaryIcon,
    required VoidCallback? onSecondaryTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useVerticalLayout = constraints.maxWidth < 430;
        final primaryButton = SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onPrimaryTap,
            icon: Icon(primaryIcon),
            label: Text(
              primaryLabel,
              textAlign: TextAlign.center,
              softWrap: true,
            ),
          ),
        );
        final secondaryButton = SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onSecondaryTap,
            icon: Icon(secondaryIcon),
            label: Text(
              secondaryLabel,
              textAlign: TextAlign.center,
              softWrap: true,
            ),
          ),
        );

        if (useVerticalLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primaryButton,
              const SizedBox(height: 12),
              secondaryButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: primaryButton),
            const SizedBox(width: 12),
            Expanded(child: secondaryButton),
          ],
        );
      },
    );
  }

  Widget _subsectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 15,
        color: Color(0xFF163C57),
      ),
    );
  }

  Widget _infoPill(IconData icon, String label, String value) {
    final maxWidth = math.max(180.0, MediaQuery.sizeOf(context).width - 92);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF184663)),
            const SizedBox(width: 8),
            Flexible(
              child: RichText(
                softWrap: true,
                text: TextSpan(
                  style: const TextStyle(color: Color(0xFF344054), height: 1.3),
                  children: [
                    TextSpan(
                      text: '$label : ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: value),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF184663)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _observationCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.visibility_outlined,
              size: 16,
              color: Color(0xFF184663),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF344054),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceTaylorWidget(double lsi, String interpretation, int score) {
    final clamped = lsi.clamp(-1.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        children: [
          const Text(
            "Balance de Taylor",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF163C57),
            ),
          ),
          const SizedBox(height: 16),
          RepaintBoundary(
            key: _gaugeKey,
            child: CustomPaint(
              size: const Size(200, 120),
              painter: _TaylorGaugePainter(clamped),
            ),
          ),
          const SizedBox(height: 12),
          Text("LSI : ${lsi.toStringAsFixed(2)}"),
          Text("Stabilité globale : ${score * 10}%"),
          Text(
            interpretation,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF344054),
            ),
          ),
        ],
      ),
    );
  }

  Color _urgencyColor(int score) {
    if (score >= 8) return const Color(0xFF2E7D32);
    if (score >= 5) return const Color(0xFFF57C00);
    return const Color(0xFFC62828);
  }

  Color _scoreColor(int score) {
    if (score >= 8) return Colors.green;
    if (score >= 5) return Colors.orange;
    return Colors.red;
  }
}

class _TaylorGaugePainter extends CustomPainter {
  final double lsi;
  _TaylorGaugePainter(this.lsi);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;
    final totalAngle = math.pi;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;

    paint.color = Colors.blue;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      totalAngle * 0.35,
      false,
      paint,
    );

    paint.color = Colors.green;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi + totalAngle * 0.35,
      totalAngle * 0.30,
      false,
      paint,
    );

    paint.color = Colors.red;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi + totalAngle * 0.65,
      totalAngle * 0.35,
      false,
      paint,
    );

    double normalized = (lsi + 1) / 2;
    final angle = math.pi + totalAngle * normalized;

    final needlePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3;

    final needleEnd = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );

    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 6, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
