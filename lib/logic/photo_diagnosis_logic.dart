import 'dart:math' as math;

enum PhotoSuspicionType { mustard, green, deposit }

class PhotoDiagnosisInput {
  final bool hasContextPhoto;
  final bool contextPhotoUsable;
  final bool hasObservationPhoto;
  final bool observationPhotoUsable;
  final bool hasAfterBrushPhoto;
  final bool afterBrushPhotoUsable;
  final int evidenceQualityScore;
  final bool yellowBrownPowder;
  final bool greenTint;
  final bool reappearsAfterBrushing;
  final bool shadedArea;
  final bool cloudyWater;
  final bool slipperySurface;
  final double? ph;
  final double? freeChlorine;
  final double? stabilizer;
  final double? temperature;

  const PhotoDiagnosisInput({
    required this.hasContextPhoto,
    required this.contextPhotoUsable,
    required this.hasObservationPhoto,
    required this.observationPhotoUsable,
    required this.hasAfterBrushPhoto,
    required this.afterBrushPhotoUsable,
    required this.evidenceQualityScore,
    required this.yellowBrownPowder,
    required this.greenTint,
    required this.reappearsAfterBrushing,
    required this.shadedArea,
    required this.cloudyWater,
    required this.slipperySurface,
    this.ph,
    this.freeChlorine,
    this.stabilizer,
    this.temperature,
  });
}

class PhotoDiagnosisResult {
  final PhotoSuspicionType type;
  final String title;
  final String confidence;
  final String evidenceLabel;
  final bool reliabilityLimited;
  final String summary;
  final List<String> evidenceWarnings;
  final List<String> convergingSigns;
  final List<String> checks;
  final List<String> actions;
  final int mustardScore;
  final int greenScore;
  final int depositScore;

  const PhotoDiagnosisResult({
    required this.type,
    required this.title,
    required this.confidence,
    required this.evidenceLabel,
    required this.reliabilityLimited,
    required this.summary,
    required this.evidenceWarnings,
    required this.convergingSigns,
    required this.checks,
    required this.actions,
    required this.mustardScore,
    required this.greenScore,
    required this.depositScore,
  });
}

class PhotoDiagnosisLogic {
  static PhotoDiagnosisResult analyze(PhotoDiagnosisInput input) {
    var mustardScore = 0;
    var greenScore = 0;
    var depositScore = 0;
    final mustardSigns = <String>[];
    final greenSigns = <String>[];
    final depositSigns = <String>[];
    final evidenceWarnings = _buildEvidenceWarnings(input);
    final evidenceScore = input.evidenceQualityScore;
    final evidenceLabel = _evidenceLabel(evidenceScore);
    final reliabilityLimited = evidenceScore < 5;

    void addMustard(int points, String sign) {
      mustardScore += points;
      mustardSigns.add(sign);
    }

    void addGreen(int points, String sign) {
      greenScore += points;
      greenSigns.add(sign);
    }

    void addDeposit(int points, String sign) {
      depositScore += points;
      depositSigns.add(sign);
    }

    if (input.yellowBrownPowder) {
      addMustard(4, 'Aspect poudreux jaune / brun compatible avec une algue moutarde.');
      addDeposit(2, 'Le dépôt peut aussi évoquer pollen, poussière ou dépôt minéral.');
    }
    if (input.greenTint) {
      addGreen(4, 'Teinte verte compatible avec une prolifération algale active.');
    }
    if (input.reappearsAfterBrushing) {
      addMustard(4, 'Le dépôt revient après brossage, ce qui oriente vers une contamination active.');
      addGreen(1, 'Le retour après brossage peut aussi être observé avec des algues vertes.');
      depositScore -= 1;
    } else {
      addDeposit(3, 'L’absence de réapparition rapide oriente plutôt vers un dépôt non biologique.');
    }
    if (input.shadedArea) {
      addMustard(2, 'La présence en zone ombragée renforce la suspicion d’algues moutardes.');
    }
    if (input.cloudyWater) {
      addGreen(3, 'Une eau trouble accompagne souvent une contamination algale plus large.');
    }
    if (input.slipperySurface) {
      addGreen(2, 'Une surface glissante évoque volontiers un biofilm ou des algues vertes.');
      addMustard(1, 'Une sensation glissante reste compatible avec une contamination avancée.');
    }

    final freeChlorine = input.freeChlorine;
    if (freeChlorine != null) {
      if (freeChlorine < 1.0) {
        addMustard(3, 'Chlore libre insuffisant pour contenir une contamination.');
        addGreen(3, 'Chlore libre insuffisant pour contenir une contamination.');
      } else if (freeChlorine < 1.5) {
        addMustard(1, 'Résiduel désinfectant un peu faible.');
        addGreen(1, 'Résiduel désinfectant un peu faible.');
      } else if (freeChlorine > 3.5) {
        addDeposit(1, 'Un chlore déjà élevé rend un simple dépôt non biologique plus plausible.');
      }
    }

    final ph = input.ph;
    if (ph != null) {
      if (ph > 7.6) {
        addMustard(1, 'pH élevé : l’efficacité du chlore diminue.');
        addGreen(1, 'pH élevé : l’efficacité du chlore diminue.');
      } else if (ph < 6.9) {
        addDeposit(1, 'pH très bas : vérifier si la coloration provient d’un dépôt ou d’une réaction de surface.');
      }
    }

    final stabilizer = input.stabilizer;
    if (stabilizer != null) {
      if (stabilizer > 70) {
        addMustard(2, 'Stabilisant élevé : le chlore devient moins réactif.');
        addGreen(1, 'Stabilisant élevé : le chlore devient moins réactif.');
      } else if (stabilizer < 20 && freeChlorine != null && freeChlorine < 1.5) {
        addGreen(1, 'Stabilisant faible avec chlore bas : le résiduel peut chuter rapidement au soleil.');
      }
    }

    final temperature = input.temperature;
    if (temperature != null) {
      if (temperature >= 28) {
        addGreen(2, 'Température élevée favorable à une reprise algale.');
        addMustard(1, 'Température élevée favorable à une reprise algale.');
      } else if (temperature >= 24) {
        addGreen(1, 'Température modérée compatible avec une contamination active.');
      }
    }

    if (mustardScore >= greenScore && mustardScore >= depositScore) {
      final confidence = _confidence(
        primary: mustardScore,
        secondary: greenScore > depositScore ? greenScore : depositScore,
        evidenceScore: evidenceScore,
      );
      return PhotoDiagnosisResult(
        type: PhotoSuspicionType.mustard,
        title: 'Algues moutardes probables',
        confidence: confidence,
        evidenceLabel: evidenceLabel,
        reliabilityLimited: reliabilityLimited,
        summary: _withEvidenceGuard(
          'Les indices visuels et les mesures de contrôle convergent vers une suspicion d’algues moutardes. Cette hypothèse reste à confirmer sur site avant traitement complet.',
          evidenceScore,
        ),
        evidenceWarnings: evidenceWarnings,
        convergingSigns: _topSigns(mustardSigns),
        checks: _mustardChecks(input),
        actions: _mustardActions(input),
        mustardScore: mustardScore,
        greenScore: greenScore,
        depositScore: depositScore,
      );
    }

    if (greenScore >= depositScore) {
      final confidence = _confidence(
        primary: greenScore,
        secondary: depositScore,
        evidenceScore: evidenceScore,
      );
      return PhotoDiagnosisResult(
        type: PhotoSuspicionType.green,
        title: 'Algues vertes possibles',
        confidence: confidence,
        evidenceLabel: evidenceLabel,
        reliabilityLimited: reliabilityLimited,
        summary: _withEvidenceGuard(
          'La lecture croisée oriente davantage vers une contamination algale verte qu’une algue moutarde. Vérifiez rapidement l’équilibre de l’eau avant de traiter.',
          evidenceScore,
        ),
        evidenceWarnings: evidenceWarnings,
        convergingSigns: _topSigns(greenSigns),
        checks: _greenChecks(input),
        actions: _greenActions(input),
        mustardScore: mustardScore,
        greenScore: greenScore,
        depositScore: depositScore,
      );
    }

    final confidence = _confidence(
      primary: depositScore,
      secondary: mustardScore > greenScore ? mustardScore : greenScore,
      evidenceScore: evidenceScore,
    );
    return PhotoDiagnosisResult(
      type: PhotoSuspicionType.deposit,
      title: 'Dépôt non biologique possible',
      confidence: confidence,
      evidenceLabel: evidenceLabel,
      reliabilityLimited: reliabilityLimited,
      summary: _withEvidenceGuard(
        'Les indices disponibles orientent plutôt vers un dépôt non biologique que vers une prolifération algale. Un contrôle simple après nettoyage reste indispensable.',
        evidenceScore,
      ),
      evidenceWarnings: evidenceWarnings,
      convergingSigns: _topSigns(depositSigns),
      checks: _depositChecks(input),
      actions: _depositActions(input),
      mustardScore: mustardScore,
      greenScore: greenScore,
      depositScore: depositScore,
    );
  }

  static String _confidence({
    required int primary,
    required int secondary,
    required int evidenceScore,
  }) {
    final margin = primary - secondary;
    var confidenceRank = 0;
    if (primary >= 10 && margin >= 3) {
      confidenceRank = 3;
    } else if (primary >= 6 && margin >= 1) {
      confidenceRank = 2;
    } else {
      confidenceRank = 1;
    }

    if (evidenceScore < 5) {
      confidenceRank -= 1;
    }
    if (evidenceScore < 3) {
      confidenceRank = 1;
    }
    if (evidenceScore < 6) {
      confidenceRank = math.min(confidenceRank, 2);
    }

    if (confidenceRank >= 3) return 'Forte';
    if (confidenceRank == 2) return 'Moyenne';
    return 'Faible';
  }

  static String _evidenceLabel(int evidenceScore) {
    if (evidenceScore >= 6) return 'Solide';
    if (evidenceScore >= 4) return 'Correcte';
    if (evidenceScore >= 2) return 'Fragile';
    return 'Insuffisante';
  }

  static List<String> _buildEvidenceWarnings(PhotoDiagnosisInput input) {
    final warnings = <String>[];
    if (!input.hasContextPhoto) {
      warnings.add('Ajoutez une photo d’ensemble du bassin pour sécuriser la lecture globale.');
    }
    if (input.hasContextPhoto && !input.contextPhotoUsable) {
      warnings.add('La photo d’ensemble n’est pas assez exploitable pour soutenir la lecture.');
    }
    if (!input.hasObservationPhoto) {
      warnings.add('Aucune photo d’observation nette n’est disponible.');
    }
    if (input.hasObservationPhoto && !input.observationPhotoUsable) {
      warnings.add('La photo d’observation n’est pas assez exploitable pour soutenir une lecture fiable.');
    }
    if (!input.hasAfterBrushPhoto) {
      warnings.add('Sans photo après brossage, la différenciation dépôt / contamination reste moins fiable.');
    }
    if (input.hasAfterBrushPhoto && !input.afterBrushPhotoUsable) {
      warnings.add('La photo après brossage n’est pas assez exploitable pour confirmer la réapparition du dépôt.');
    }
    return warnings;
  }

  static String _withEvidenceGuard(String base, int evidenceScore) {
    if (evidenceScore < 2) {
      return '$base La qualité de preuve photo est insuffisante : le résultat doit être considéré comme une présomption faible.';
    }
    if (evidenceScore < 4) {
      return '$base La qualité de preuve photo reste limitée : confirmez impérativement avec une nouvelle prise et un contrôle terrain.';
    }
    if (evidenceScore < 6) {
      return '$base La lecture reste utile, mais une lecture vraiment sûre demande au moins trois photos exploitables : ensemble, observation rapprochée et après brossage.';
    }
    return base;
  }

  static List<String> _topSigns(List<String> signs) {
    if (signs.isEmpty) {
      return const ['Aucun indice convergent suffisant : compléter avec les mesures d’eau.'];
    }
    return signs.take(4).toList();
  }

  static List<String> _mustardChecks(PhotoDiagnosisInput input) {
    return [
      'Confirmer que le dépôt réapparaît après brossage et aspiration.',
      'Inspecter en priorité les zones d’ombre, escaliers, angles et accessoires.',
      if (input.freeChlorine == null)
        'Mesurer rapidement le chlore libre pour confirmer la perte de résiduel.'
      else if ((input.freeChlorine ?? 99) < 1.5)
        'Le chlore libre est faible : confirmer avec une mesure de contrôle avant traitement.'
      else
        'Malgré un désinfectant présent, vérifier les zones peu brassées et les niches de contamination.',
      if (input.stabilizer == null)
        'Contrôler le stabilisant pour évaluer l’efficacité réelle du chlore.'
      else if ((input.stabilizer ?? 0) > 70)
        'Le stabilisant élevé peut freiner le traitement : prévoir une stratégie adaptée.'
      else
        'Le stabilisant semble compatible : vérifier surtout la qualité du brossage et de la filtration.',
    ];
  }

  static List<String> _mustardActions(PhotoDiagnosisInput input) {
    return [
      'Brosser l’ensemble du bassin, les accessoires, les angles et les zones ombragées.',
      'Lancer un traitement choc adapté puis maintenir un résiduel renforcé sur 24 à 48 h.',
      'Nettoyer le filtre et remettre en circulation avec contrôle visuel rapproché.',
      if ((input.stabilizer ?? 0) > 70)
        'Évaluer un renouvellement partiel d’eau si le stabilisant reste trop élevé.'
      else
        'Recontrôler chlore, pH et stabilisant après remise en circulation.',
    ];
  }

  static List<String> _greenChecks(PhotoDiagnosisInput input) {
    return [
      'Confirmer l’eau trouble et l’aspect glissant sur plusieurs zones du bassin.',
      'Contrôler rapidement le chlore libre, le pH et la filtration.',
      if ((input.temperature ?? 0) >= 28)
        'La température élevée favorise la prolifération : accélérer la remise au propre.'
      else
        'Vérifier le temps de filtration et la fréquentation récente du bassin.',
    ];
  }

  static List<String> _greenActions(PhotoDiagnosisInput input) {
    return [
      'Brosser, aspirer et lancer une désinfection renforcée selon le protocole du bassin.',
      'Prolonger la filtration puis effectuer un contre-lavage avant nouveau contrôle.',
      if ((input.freeChlorine ?? 2) < 1.5)
        'Remonter rapidement le résiduel désinfectant avant la prochaine baignade.'
      else
        'Vérifier si le défaut vient surtout de la filtration ou du brassage.',
    ];
  }

  static List<String> _depositChecks(PhotoDiagnosisInput input) {
    return [
      'Nettoyer mécaniquement puis observer si le dépôt revient dans les 24 h.',
      'Contrôler l’exposition au vent, aux pollens, à la poussière ou à des travaux proches.',
      'Vérifier les mesures d’eau avant tout traitement algicide spécifique.',
    ];
  }

  static List<String> _depositActions(PhotoDiagnosisInput input) {
    return [
      'Aspirer et nettoyer le bassin sans lancer immédiatement un traitement lourd.',
      'Recontrôler visuellement après filtration et brossage.',
      'Si le dépôt revient malgré le nettoyage, basculer vers une analyse complète avec mesures.',
    ];
  }
}
