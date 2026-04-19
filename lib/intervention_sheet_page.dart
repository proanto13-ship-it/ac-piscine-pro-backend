import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import 'logic/diagnostic_logic.dart';
import 'models/company_profile.dart';
import 'models/feature_gate.dart';
import 'models/intervention_record.dart';
import 'models/media_attachment.dart';
import 'models/plan.dart';
import 'models/subscription.dart';
import 'models/team_member.dart';
import 'pages/pricing_page.dart';
import 'services/document_share_service.dart';
import 'services/pdf_service.dart';
import 'services/local_storage_service.dart';
import 'widgets/optimized_file_image.dart';

class InterventionSheetPage extends StatefulWidget {
  final String clientName;
  final String dateLabel;
  final double volumeM3;
  final String treatmentType;
  final DiagnosticResult result;
  final String estimateLabel;
  final CompanyProfile companyProfile;
  final Subscription subscription;
  final List<TeamMember> teamMembers;
  final Future<void> Function(InterventionRecord record)? onSaveRecord;

  const InterventionSheetPage({
    super.key,
    required this.clientName,
    required this.dateLabel,
    required this.volumeM3,
    required this.treatmentType,
    required this.result,
    required this.estimateLabel,
    required this.companyProfile,
    required this.subscription,
    required this.teamMembers,
    this.onSaveRecord,
  });

  @override
  State<InterventionSheetPage> createState() => _InterventionSheetPageState();
}

class _InterventionSheetPageState extends State<InterventionSheetPage> {
  final _techController = TextEditingController();
  final _clientController = TextEditingController();
  final _summaryController = TextEditingController();
  final _recommendationsController = TextEditingController();
  final _accessController = TextEditingController();
  final GlobalKey _signatureKey = GlobalKey();
  final ImagePicker _imagePicker = ImagePicker();
  List<Offset?> _points = [];
  List<MediaAttachment> _attachments = [];

  bool _estimateApproved = false;
  bool _interventionCompleted = true;
  bool _followUpRequired = true;

  @override
  void initState() {
    super.initState();
    _summaryController.text = [
      ...widget.result.ajustementChimique,
      ...widget.result.verificationTechnique,
    ].join('\n');
    _recommendationsController.text = widget.result.validation.join('\n');
    _techController.text = widget.companyProfile.technicianDefaultName;
  }

  @override
  void dispose() {
    _techController.dispose();
    _clientController.dispose();
    _summaryController.dispose();
    _recommendationsController.dispose();
    _accessController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _captureSignature() async {
    if (_points.whereType<Offset>().isEmpty) {
      return null;
    }

    final boundary = _signatureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      return null;
    }

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  InterventionRecord _buildRecord(Uint8List? signature) {
    return InterventionRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      createdAtIso: DateTime.now().toIso8601String(),
      dateLabel: widget.dateLabel,
      technicianName: _techController.text.trim().isEmpty
          ? 'Technicien non renseigné'
          : _techController.text.trim(),
      clientRepresentative: _clientController.text.trim().isEmpty
          ? 'Client non renseigné'
          : _clientController.text.trim(),
      poolSummary:
          '${widget.volumeM3.toStringAsFixed(1)} m3 • ${widget.treatmentType}',
      interventionSummary: _summaryController.text.trim(),
      recommendations: _recommendationsController.text.trim(),
      accessNotes: _accessController.text.trim(),
      followUpLabel:
          '${widget.result.stabilisation} • ${widget.result.dureeEstimee}',
      estimateLabel: widget.estimateLabel,
      estimateApproved: _estimateApproved,
      interventionCompleted: _interventionCompleted,
      followUpRequired: _followUpRequired,
      signatureBase64: signature == null ? null : base64Encode(signature),
      attachments: _attachments,
    );
  }

  Future<void> _saveRecord() async {
    if (widget.onSaveRecord == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ce bon ne peut pas être enregistré sans client associé.',
          ),
        ),
      );
      return;
    }

    final signature = await _captureSignature();
    final record = _buildRecord(signature);
    await widget.onSaveRecord!(record);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bon d’intervention enregistré dans le dossier client.'),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 76,
      maxWidth: 1400,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final savedPath = await LocalStorageService.saveBinary(
      'intervention_photos',
      '${DateTime.now().microsecondsSinceEpoch}_${file.name}',
      bytes,
    );

    setState(() {
      _attachments = [
        ..._attachments,
        MediaAttachment.fromLegacyPhotoPath(
          savedPath,
          createdAtIso: DateTime.now().toIso8601String(),
        ),
      ];
    });
  }

  Future<void> _previewPdf() async {
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
    final signature = await _captureSignature();
    final record = _buildRecord(signature);
    final photoBytes = <Uint8List>[];
    for (final attachment in record.attachments
        .where((item) => item.hasLocalPath)
        .take(PdfService.maxEmbeddedPhotos)) {
      final bytes = await LocalStorageService.readBinary(attachment.localPath);
      if (bytes != null) {
        photoBytes.add(Uint8List.fromList(bytes));
      }
    }
    final pdf = await PdfService.generateInterventionTicketPdf(
      companyProfile: widget.companyProfile,
      ticket: record.toTicketData(widget.clientName),
      signatureBytes: record.signatureBytes,
      photoBytes: photoBytes,
    );

    if (!mounted) return;

    await Printing.layoutPdf(onLayout: (_) async => pdf);
  }

  Future<void> _sharePdf() async {
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
    final signature = await _captureSignature();
    final record = _buildRecord(signature);
    final photoBytes = <Uint8List>[];
    for (final attachment in record.attachments
        .where((item) => item.hasLocalPath)
        .take(PdfService.maxEmbeddedPhotos)) {
      final bytes = await LocalStorageService.readBinary(attachment.localPath);
      if (bytes != null) {
        photoBytes.add(Uint8List.fromList(bytes));
      }
    }
    final pdf = await PdfService.generateInterventionTicketPdf(
      companyProfile: widget.companyProfile,
      ticket: record.toTicketData(widget.clientName),
      signatureBytes: record.signatureBytes,
      photoBytes: photoBytes,
    );
    await DocumentShareService.sharePdf(
      bytes: pdf,
      filename: DocumentShareService.safePdfFilename(
        'intervention_${widget.clientName}_${record.id}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bon d’intervention'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _sharePdf,
            tooltip: 'Partager',
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            'Intervenants',
            [
              if (widget.teamMembers.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: _techController.text.isEmpty
                      ? widget.teamMembers.first.name
                      : _techController.text,
                  decoration: const InputDecoration(
                    labelText: 'Technicien de l’équipe',
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
                    _techController.text = value;
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
              ],
              _field('Technicien', _techController),
              const SizedBox(height: 12),
              _field('Client / représentant', _clientController),
            ],
          ),
          _section(
            'Synthèse',
            [
              Text('Client : ${widget.clientName}'),
              Text('Date : ${widget.dateLabel}'),
              Text(
                'Bassin : ${widget.volumeM3.toStringAsFixed(1)} m3 • ${widget.treatmentType}',
              ),
              Text('Chiffrage : ${widget.estimateLabel}'),
            ],
          ),
          _section(
            'Compte rendu d’intervention',
            [
              _field(
                'Intervention réalisée',
                _summaryController,
                maxLines: 6,
              ),
            ],
          ),
          _section(
            'Recommandations',
            [
              _field(
                'Consignes de remise en route et de contrôle',
                _recommendationsController,
                maxLines: 5,
              ),
              const SizedBox(height: 12),
              _field('Accès et remarques', _accessController, maxLines: 3),
            ],
          ),
          _section(
            'Validation',
            [
              CheckboxListTile(
                value: _estimateApproved,
                onChanged: (value) =>
                    setState(() => _estimateApproved = value ?? false),
                title: const Text('Chiffrage validé par le client'),
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _interventionCompleted,
                onChanged: (value) =>
                    setState(() => _interventionCompleted = value ?? false),
                title: const Text('Intervention réalisée'),
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _followUpRequired,
                onChanged: (value) =>
                    setState(() => _followUpRequired = value ?? false),
                title: const Text('Contrôle de suivi à programmer'),
                subtitle: Text(widget.result.stabilisation),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          _section(
            'Photos d’intervention',
            [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Prendre une photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galerie'),
                    ),
                  ),
                ],
              ),
              if (_attachments.any((item) => item.hasLocalPath)) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _attachments
                      .where((item) => item.hasLocalPath)
                      .map(
                        (attachment) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: OptimizedFileImage(
                                path: attachment.localPath,
                                width: 92,
                                height: 92,
                                cacheWidth: 184,
                                cacheHeight: 184,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: InkWell(
                                onTap: () => setState(() {
                                  _attachments = _attachments
                                      .where((item) => item.id != attachment.id)
                                      .toList();
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
          _section(
            'Signature client',
            [
              RepaintBoundary(
                key: _signatureKey,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD0D5DD)),
                  ),
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _points = [..._points, details.localPosition];
                      });
                    },
                    onPanEnd: (_) => setState(() {
                      _points = [..._points, null];
                    }),
                    child: CustomPaint(
                      painter: _SignaturePainter(_points),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _points = []),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Effacer'),
                  ),
                  const Spacer(),
                  const Text(
                    'Signature manuscrite',
                    style: TextStyle(color: Color(0xFF667085)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saveRecord,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Enregistrer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _previewPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Prévisualiser'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
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
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
