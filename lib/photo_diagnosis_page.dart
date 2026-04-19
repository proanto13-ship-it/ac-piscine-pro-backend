import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'logic/photo_diagnosis_logic.dart';
import 'widgets/optimized_file_image.dart';

enum _PhotoCaptureTarget { context, observation, afterBrush }

class PhotoDiagnosisPage extends StatefulWidget {
  final String? clientName;
  final String? lastAnalysisDateLabel;
  final double? initialPh;
  final double? initialFreeChlorine;
  final double? initialStabilizer;
  final double? initialTemperature;

  const PhotoDiagnosisPage({
    super.key,
    this.clientName,
    this.lastAnalysisDateLabel,
    this.initialPh,
    this.initialFreeChlorine,
    this.initialStabilizer,
    this.initialTemperature,
  });

  @override
  State<PhotoDiagnosisPage> createState() => _PhotoDiagnosisPageState();
}

class _PhotoDiagnosisPageState extends State<PhotoDiagnosisPage> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _phController = TextEditingController();
  final TextEditingController _chlorineController = TextEditingController();
  final TextEditingController _stabilizerController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();

  String? _contextImagePath;
  String? _imagePath;
  String? _afterBrushImagePath;
  _PhotoQualityAssessment? _contextQuality;
  _PhotoQualityAssessment? _observationQuality;
  _PhotoQualityAssessment? _afterBrushQuality;
  bool _yellowBrownPowder = true;
  bool _greenTint = false;
  bool _reappearsAfterBrushing = true;
  bool _shadedArea = true;
  bool _cloudyWater = false;
  bool _slipperySurface = false;

  @override
  void initState() {
    super.initState();
    _phController.text = _formatInitial(widget.initialPh);
    _chlorineController.text = _formatInitial(widget.initialFreeChlorine);
    _stabilizerController.text = _formatInitial(widget.initialStabilizer);
    _temperatureController.text = _formatInitial(widget.initialTemperature);
  }

  @override
  void dispose() {
    _phController.dispose();
    _chlorineController.dispose();
    _stabilizerController.dispose();
    _temperatureController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(
    ImageSource source, {
    required _PhotoCaptureTarget target,
  }) async {
    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 78,
      maxWidth: 1600,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final quality = await _assessPhoto(bytes);
    setState(() {
      if (target == _PhotoCaptureTarget.afterBrush) {
        _afterBrushImagePath = file.path;
        _afterBrushQuality = quality;
      } else if (target == _PhotoCaptureTarget.observation) {
        _imagePath = file.path;
        _observationQuality = quality;
      } else {
        _contextImagePath = file.path;
        _contextQuality = quality;
      }
    });
  }

  double? _parse(String text) {
    final cleaned = text.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  String _formatInitial(double? value) {
    if (value == null) return '';
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  int _captureQualityScore() =>
      (_contextQuality?.score ?? 0) +
      (_observationQuality?.score ?? 0) +
      (_afterBrushQuality?.score ?? 0);

  Color _captureQualityColor() {
    final score = _captureQualityScore();
    if (score >= 6) return const Color(0xFF027A48);
    if (score >= 4) return const Color(0xFF0F6E7C);
    if (score >= 2) return const Color(0xFFB54708);
    return const Color(0xFFB42318);
  }

  List<String> _captureTips() {
    final tips = <String>[];
    if (_imagePath == null) {
      tips.add(
          'Ajoutez une photo rapprochée de la zone suspecte pour lancer la lecture.');
    } else if (_observationQuality != null && !_observationQuality!.usable) {
      tips.addAll(_observationQuality!.warnings);
    }
    if (_contextImagePath == null) {
      tips.add(
          'Ajoutez une photo d’ensemble du bassin pour disposer des 3 vues minimales.');
    } else if (_contextQuality != null && !_contextQuality!.usable) {
      tips.addAll(_contextQuality!.warnings);
    }
    if (_afterBrushImagePath == null) {
      tips.add(
          'Ajoutez une photo après brossage pour compléter les 3 vues minimales.');
    } else if (_afterBrushQuality != null && !_afterBrushQuality!.usable) {
      tips.addAll(_afterBrushQuality!.warnings);
    }
    if (tips.isEmpty) {
      tips.add(
          'Le dossier photo est bien renseigné pour une lecture terrain crédible.');
    }
    return tips;
  }

  Future<_PhotoQualityAssessment> _assessPhoto(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 220);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        return const _PhotoQualityAssessment.unusable(
          warnings: [
            'Le format de la photo ne permet pas une vérification automatique fiable.'
          ],
        );
      }

      final pixels = byteData.buffer.asUint8List();
      final width = image.width;
      final height = image.height;
      final luminances = <double>[];
      double edgeSum = 0;
      var edgeCount = 0;

      double luminanceAt(int x, int y) {
        final index = (y * width + x) * 4;
        final r = pixels[index].toDouble();
        final g = pixels[index + 1].toDouble();
        final b = pixels[index + 2].toDouble();
        return (0.299 * r) + (0.587 * g) + (0.114 * b);
      }

      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final lum = luminanceAt(x, y);
          luminances.add(lum);
          if (x > 0) {
            edgeSum += (lum - luminanceAt(x - 1, y)).abs();
            edgeCount++;
          }
          if (y > 0) {
            edgeSum += (lum - luminanceAt(x, y - 1)).abs();
            edgeCount++;
          }
        }
      }

      final mean =
          luminances.fold<double>(0, (sum, v) => sum + v) / luminances.length;
      final variance = luminances.fold<double>(
            0,
            (sum, v) => sum + math.pow(v - mean, 2).toDouble(),
          ) /
          luminances.length;
      final stdDev = math.sqrt(variance);
      final edgeAverage = edgeCount == 0 ? 0 : edgeSum / edgeCount;

      final warnings = <String>[];
      var score = 0;

      final enoughDefinition = width >= 160 && height >= 160;
      if (enoughDefinition) {
        score += 1;
      } else {
        warnings.add(
            'La définition est trop faible pour juger correctement la zone observée.');
      }

      final exposureBalanced = mean >= 55 && mean <= 205;
      if (exposureBalanced) {
        score += 1;
      } else if (mean < 55) {
        warnings.add(
            'La photo est trop sombre pour distinguer correctement la couleur du dépôt.');
      } else {
        warnings.add(
            'La photo est trop claire ou surexposée pour une lecture fiable.');
      }

      final enoughContrast = stdDev >= 28;
      if (enoughContrast) {
        score += 1;
      } else {
        warnings.add(
            'Le contraste de la photo est trop faible pour lire finement la texture.');
      }

      final sharpEnough = edgeAverage >= 16;
      if (sharpEnough) {
        score += 1;
      } else {
        warnings.add(
            'La photo paraît trop floue pour être pleinement exploitable.');
      }

      final usable = score >= 3;
      return _PhotoQualityAssessment(
        score: score,
        usable: usable,
        meanLuminance: mean,
        contrast: stdDev,
        edgeAverage: edgeAverage.toDouble(),
        warnings: warnings,
      );
    } catch (_) {
      return const _PhotoQualityAssessment.unusable(
        warnings: ['La photo n’a pas pu être analysée automatiquement.'],
      );
    }
  }

  PhotoDiagnosisResult _buildResult() {
    return PhotoDiagnosisLogic.analyze(
      PhotoDiagnosisInput(
        hasContextPhoto: _contextImagePath != null,
        contextPhotoUsable: _contextQuality?.usable ?? false,
        hasObservationPhoto: _imagePath != null,
        observationPhotoUsable: _observationQuality?.usable ?? false,
        hasAfterBrushPhoto: _afterBrushImagePath != null,
        afterBrushPhotoUsable: _afterBrushQuality?.usable ?? false,
        evidenceQualityScore: _captureQualityScore(),
        yellowBrownPowder: _yellowBrownPowder,
        greenTint: _greenTint,
        reappearsAfterBrushing: _reappearsAfterBrushing,
        shadedArea: _shadedArea,
        cloudyWater: _cloudyWater,
        slipperySurface: _slipperySurface,
        ph: _parse(_phController.text),
        freeChlorine: _parse(_chlorineController.text),
        stabilizer: _parse(_stabilizerController.text),
        temperature: _parse(_temperatureController.text),
      ),
    );
  }

  Color _resultColor(PhotoSuspicionType type) {
    switch (type) {
      case PhotoSuspicionType.mustard:
        return const Color(0xFFB54708);
      case PhotoSuspicionType.green:
        return const Color(0xFF027A48);
      case PhotoSuspicionType.deposit:
        return const Color(0xFF667085);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _buildResult();
    final resultColor = _resultColor(result.type);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic photo'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            'Analyse visuelle assistée',
            [
              if (widget.clientName != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F6E7C).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.clientName!,
                        style: const TextStyle(
                          color: Color(0xFF12324A),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (widget.lastAnalysisDateLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Dernier relevé repris : ${widget.lastAnalysisDateLabel!}',
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Ajoutez les vues du bassin puis confirmez les indices observés. Cette lecture assistée est particulièrement utile en cas de suspicion d’algues moutardes.',
                style: TextStyle(
                  color: Color(0xFF475467),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Le résultat ne repose pas sur la photo seule : l’app croise les observations terrain, les mesures d’eau si elles sont disponibles, et la qualité automatique des images. Pour une lecture vraiment sûre, il faut trois photos exploitables : ensemble, zone rapprochée et après brossage.',
                style: TextStyle(
                  color: Color(0xFF667085),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _pickImage(
                        ImageSource.camera,
                        target: _PhotoCaptureTarget.context,
                      ),
                      icon: const Icon(Icons.wb_sunny_outlined),
                      label: const Text('Photo d’ensemble'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _photoCard(
                title: 'Photo d’ensemble',
                path: _contextImagePath,
                emptyLabel:
                    'Ajoutez une vue globale du bassin pour situer la zone touchée.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _pickImage(
                        ImageSource.camera,
                        target: _PhotoCaptureTarget.observation,
                      ),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Photo rapprochée'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(
                        ImageSource.gallery,
                        target: _PhotoCaptureTarget.observation,
                      ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Importer vue'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _photoCard(
                title: 'Photo rapprochée',
                path: _imagePath,
                emptyLabel: 'Aucune photo rapprochée sélectionnée',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(
                        ImageSource.camera,
                        target: _PhotoCaptureTarget.afterBrush,
                      ),
                      icon: const Icon(Icons.compare_outlined),
                      label: const Text('Photo après brossage'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _photoCard(
                title: 'Comparaison après brossage',
                path: _afterBrushImagePath,
                emptyLabel:
                    'Ajoutez une seconde photo après brossage si vous voulez renforcer la lecture.',
              ),
            ],
          ),
          _section(
            'Qualité de la prise',
            [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Niveau de preuve photo',
                      style: const TextStyle(
                        color: Color(0xFF12324A),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _captureQualityColor().withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      result.evidenceLabel,
                      style: TextStyle(
                        color: _captureQualityColor(),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _qualityTile(
                'Photo d’ensemble',
                _contextQuality,
              ),
              const SizedBox(height: 10),
              _qualityTile(
                'Photo d’observation',
                _observationQuality,
              ),
              const SizedBox(height: 10),
              _qualityTile(
                'Photo après brossage',
                _afterBrushQuality,
              ),
              const SizedBox(height: 8),
              ..._captureTips().map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• $item',
                    style: const TextStyle(
                      color: Color(0xFF344054),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (result.reliabilityLimited)
            _section(
              'Sécurité de lecture',
              result.evidenceWarnings
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '• $item',
                        style: const TextStyle(
                          color: Color(0xFFB42318),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          _section(
            'Indices observés',
            [
              _switchTile(
                title: 'Aspect poudre jaune / brun',
                subtitle:
                    'Dépôt fin, souvent sur les parois ou les zones calmes',
                value: _yellowBrownPowder,
                onChanged: (v) => setState(() => _yellowBrownPowder = v),
              ),
              _switchTile(
                title: 'Teinte verte ou eau verdissante',
                subtitle: 'Oriente plutôt vers des algues vertes',
                value: _greenTint,
                onChanged: (v) => setState(() => _greenTint = v),
              ),
              _switchTile(
                title: 'Revient après brossage',
                subtitle:
                    'Très utile pour distinguer un dépôt passager d’une contamination active',
                value: _reappearsAfterBrushing,
                onChanged: (v) => setState(() => _reappearsAfterBrushing = v),
              ),
              _switchTile(
                title: 'Présent en zone ombragée',
                subtitle: 'Escaliers, angles, zones peu brassées',
                value: _shadedArea,
                onChanged: (v) => setState(() => _shadedArea = v),
              ),
              _switchTile(
                title: 'Eau trouble',
                subtitle: 'Peut signaler une contamination plus large',
                value: _cloudyWater,
                onChanged: (v) => setState(() => _cloudyWater = v),
              ),
              _switchTile(
                title: 'Surface glissante',
                subtitle: 'Signe fréquent de biofilm ou d’algues actives',
                value: _slipperySurface,
                onChanged: (v) => setState(() => _slipperySurface = v),
              ),
            ],
          ),
          _section(
            'Mesures de contrôle',
            [
              const Text(
                'Ces valeurs restent facultatives, mais elles renforcent fortement la fiabilité de la lecture.',
                style: TextStyle(
                  color: Color(0xFF667085),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _measureField(
                      'pH',
                      _phController,
                      suffix: '',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _measureField(
                      'Chlore libre',
                      _chlorineController,
                      suffix: 'ppm',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _measureField(
                      'Stabilisant',
                      _stabilizerController,
                      suffix: 'ppm',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _measureField(
                      'Température',
                      _temperatureController,
                      suffix: '°C',
                    ),
                  ),
                ],
              ),
            ],
          ),
          _section(
            'Lecture proposée',
            [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: resultColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: resultColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Confiance ${result.confidence}',
                      style: TextStyle(
                        color: resultColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                result.summary,
                style: const TextStyle(
                  color: Color(0xFF475467),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              _scoreBoard(result),
            ],
          ),
          _section(
            'Indices convergents',
            result.convergingSigns
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '• $item',
                      style: const TextStyle(
                        color: Color(0xFF344054),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          _section(
            'Contrôles à faire',
            result.checks
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '• $item',
                      style: const TextStyle(
                        color: Color(0xFF344054),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          _section(
            'Protocole conseillé',
            result.actions
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '• $item',
                      style: const TextStyle(
                        color: Color(0xFF344054),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _scoreBoard(PhotoDiagnosisResult result) {
    return Row(
      children: [
        Expanded(
          child: _scoreTile(
            'Moutarde',
            result.mustardScore,
            const Color(0xFFB54708),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _scoreTile(
            'Verte',
            result.greenScore,
            const Color(0xFF027A48),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _scoreTile(
            'Dépôt',
            result.depositScore,
            const Color(0xFF667085),
          ),
        ),
      ],
    );
  }

  Widget _photoCard({
    required String title,
    required String? path,
    required String emptyLabel,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF12324A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            height: 190,
            child: path == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        emptyLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                    child: OptimizedFileImage(
                      path: path,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      cacheWidth: 960,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _scoreTile(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _measureField(
    String label,
    TextEditingController controller, {
    required String suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix.isEmpty ? null : suffix,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF12324A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Color(0xFF667085),
          fontWeight: FontWeight.w600,
        ),
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
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF12324A),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _qualityTile(String title, _PhotoQualityAssessment? quality) {
    if (quality == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '$title : en attente de photo.',
          style: const TextStyle(
            color: Color(0xFF667085),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final color =
        quality.usable ? const Color(0xFF027A48) : const Color(0xFFB42318);
    final label = quality.usable ? 'Exploitable' : 'À reprendre';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF12324A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Lumière ${quality.meanLuminance.toStringAsFixed(0)} • Contraste ${quality.contrast.toStringAsFixed(0)} • Netteté ${quality.edgeAverage.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Color(0xFF667085),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoQualityAssessment {
  final int score;
  final bool usable;
  final double meanLuminance;
  final double contrast;
  final double edgeAverage;
  final List<String> warnings;

  const _PhotoQualityAssessment({
    required this.score,
    required this.usable,
    required this.meanLuminance,
    required this.contrast,
    required this.edgeAverage,
    required this.warnings,
  });

  const _PhotoQualityAssessment.unusable({
    required this.warnings,
  })  : score = 0,
        usable = false,
        meanLuminance = 0,
        contrast = 0,
        edgeAverage = 0;
}
