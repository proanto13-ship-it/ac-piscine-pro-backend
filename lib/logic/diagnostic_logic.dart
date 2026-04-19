import 'dart:math';

import '../engine/pool_engine.dart';
import '../engine/pool_models.dart';
import '../models/pricing_settings.dart';

class Produit {
  final String label;
  final double qty;
  final String unit;
  final double budgetMin;
  final double budgetMax;

  Produit({
    required this.label,
    required this.qty,
    required this.unit,
    required this.budgetMin,
    required this.budgetMax,
  });
}

class DiagnosticResult {
  final int score;
  final String statut;
  final double lsi;
  final String lsiInterpretation;
  final String urgenceLabel;
  final List<String> whyNow;
  final String simpleExplanation;
  final String interventionTitre;
  final List<String> ajustementChimique;
  final List<String> verificationTechnique;
  final List<String> validation;
  final String dureeEstimee;
  final String stabilisation;
  
  final List<String> analyse;
  final List<Produit> produits;
  final double totalProduitsMin;
  final double totalProduitsMax;
  final double mainOeuvre;
  final double totalMin;
  final double totalMax;
  
  DiagnosticResult({
    required this.score,
    required this.statut,
    required this.lsi,
    required this.lsiInterpretation,
    required this.urgenceLabel,
    required this.whyNow,
    required this.simpleExplanation,
    required this.interventionTitre,
    required this.ajustementChimique,
    required this.verificationTechnique,
    required this.validation,
    required this.dureeEstimee,
    required this.stabilisation,
    
    required this.analyse,
    required this.produits,
    required this.totalProduitsMin,
    required this.totalProduitsMax,
    required this.mainOeuvre,
    required this.totalMin,
    required this.totalMax,
    
  });
}
class DiagnosticLogic {
  static DiagnosticResult build({
    required double ph,
    required double chlore,
    required double tac,
    required double th,
    required double stabilisant,
    required double volumeM3,
    required String observation,
    required String treatmentType,
    double? sel,
    double? temperature,
    PricingSettings? pricingSettings,
  }) {
    final pricing = pricingSettings ?? PricingSettings.defaults();
    final cleanObservation = observation.trim().toLowerCase();
    final hasGreenWater =
        cleanObservation.contains('verte') || cleanObservation.contains('vert');
    final hasCloudyWater =
        cleanObservation.contains('trouble') || cleanObservation.contains('laiteuse');

    final data = PoolData(
      volume: volumeM3,
      ph: ph,
      chlore: chlore,
      tac: tac,
      th: th,
      stabilisant: stabilisant,
      temperature: temperature ?? 25,
      sel: sel,
    );
    final poolResult = PoolEngine.analyse(data);
    final correctedTac = PoolEngine.correctedAlkalinity(data);
    final lsi = poolResult.lsi;

    int score = (poolResult.stabilityScore / 10).round().clamp(0, 10);
    final analyse = <String>[];
    final produits = <Produit>[];
    final ajustementChimique = <String>[];
    final verificationTechnique = <String>[
      "Contrôle pression filtre et débit hydraulique",
      "Contre-lavage ou nettoyage si la charge filtre est élevée",
      "Adapter la filtration à la température et à l’état visuel du bassin",
    ];
    final validation = <String>[
      "Recontrôle complet après brassage homogène de l’eau",
      "Ajuster par paliers, jamais en ajout massif sans re-mesure",
    ];

    void addAnalyse(String text) {
      if (!analyse.contains(text)) analyse.add(text);
    }

    void addAdjustment(String text) {
      if (!ajustementChimique.contains(text)) ajustementChimique.add(text);
    }

    void addValidation(String text) {
      if (!validation.contains(text)) validation.add(text);
    }

    void addVerification(String text) {
      if (!verificationTechnique.contains(text)) verificationTechnique.add(text);
    }

    double roundQuantity(double value, String unit) {
      if (value <= 0) return 0;
      if (unit == 'kg') {
        return (value * 20).ceil() / 20;
      }
      if (unit == 'L') {
        return (value * 10).ceil() / 10;
      }
      return value;
    }

    void addProduct(String label, double qty, String unit) {
      if (qty <= 0) return;
      final roundedQty = roundQuantity(qty, unit);
      final price = pricing.priceFor(label);
      produits.add(
        Produit(
          label: label,
          qty: roundedQty,
          unit: unit,
          budgetMin: roundedQty * price.minPrice,
          budgetMax: roundedQty * price.maxPrice,
        ),
      );
    }

    String lsiInterpretation;
    if (lsi > 0.30) {
      lsiInterpretation = "Eau entartrante";
      addAnalyse(
        "LSI positif : l’eau favorise les dépôts calcaires sur les surfaces et les équipements.",
      );
    } else if (lsi < -0.30) {
      lsiInterpretation = "Eau agressive";
      addAnalyse(
        "LSI négatif : l’eau est agressive et peut accentuer la corrosion ou l’usure des matériaux.",
      );
    } else {
      lsiInterpretation = "Équilibre correct";
      addAnalyse("Équilibre calco-carbonique globalement cohérent.");
    }

    if (ph > 7.8) {
      score -= 2;
      addAnalyse("pH trop élevé : le chlore devient moins efficace et le risque de tartre augmente.");
      addAdjustment("Abaisser le pH par palier jusqu’à 7.2 – 7.4 puis recontrôler.");
      final targetPh = 7.4;
      final delta = max(0, ph - targetPh);
      final qtyKg = (volumeM3 / 10) * (delta / 0.1) * 0.03;
      addProduct("pH-", qtyKg, "kg");
      addValidation("Pour le pH-, fractionner la dose puis laisser circuler avant nouvelle mesure.");
    } else if (ph > 7.6) {
      score -= 1;
      addAnalyse("pH légèrement élevé : un ajustement préventif est conseillé.");
      addAdjustment("Ramener le pH vers 7.3 – 7.4.");
    } else if (ph < 7.0) {
      score -= 2;
      addAnalyse("pH trop bas : l’eau devient agressive pour les équipements et le confort baigneur baisse.");
      addAdjustment("Remonter le pH progressivement vers 7.2 – 7.4.");
      final targetPh = 7.2;
      final delta = max(0, targetPh - ph);
      final qtyKg = (volumeM3 / 10) * (delta / 0.2) * 0.15;
      addProduct("pH+", qtyKg, "kg");
      addValidation("Pour le pH+, procéder par étapes et recontrôler après brassage.");
    } else if (ph < 7.2) {
      score -= 1;
      addAnalyse("pH légèrement bas : un réajustement limitera l’agressivité de l’eau.");
      addAdjustment("Ramener le pH au coeur de zone 7.2 – 7.4.");
    }

    final needsShock = hasGreenWater || hasCloudyWater || chlore < 0.5;
    if (chlore < 1.5) {
      score -= 2;
      final targetChlore = needsShock ? 8.0 : 2.0;
      final delta = max(0, targetChlore - chlore);
      final qtyKg = (delta * volumeM3 / 0.65) / 1000;
      addAnalyse(
        needsShock
            ? "Chlore très bas avec eau dégradée : une remise à niveau choc est nécessaire."
            : "Chlore libre insuffisant pour une désinfection stable.",
      );
      addAdjustment(
        needsShock
            ? "Effectuer une chloration choc puis maintenir un résiduel entre 1.5 et 2 ppm."
            : "Revenir à un chlore libre cible entre 1.5 et 2 ppm.",
      );
      addProduct("Chlore choc", qtyKg, "kg");
      addValidation("Mesurer à nouveau le chlore libre 4 à 12h après traitement selon le brassage.");
    } else if (chlore > 4.0) {
      score -= 1;
      addAnalyse("Chlore élevé : surveiller le confort baigneur et attendre une redescente avant baignade.");
      addAdjustment("Stopper les apports de chlore et laisser la valeur redescendre.");
    }

    if (correctedTac < 80) {
      score -= 1;
      addAnalyse(
        "Alcalinité corrigée trop basse (${correctedTac.toStringAsFixed(0)} ppm) : le pH risque de dériver rapidement.",
      );
      addAdjustment("Remonter l’alcalinité corrigée vers 90 – 120 ppm.");
      final delta = max(0, 100 - correctedTac);
      final qtyKg = (delta / 10) * 0.018 * volumeM3;
      addProduct("TAC+", qtyKg, "kg");
    } else if (correctedTac > 150) {
      score -= 1;
      addAnalyse(
        "Alcalinité corrigée trop haute (${correctedTac.toStringAsFixed(0)} ppm) : le pH sera difficile à redescendre durablement.",
      );
      addAdjustment("Réduire l’alcalinité par cycles acide + aération, avec re-mesure entre chaque étape.");
      final delta = correctedTac - 120;
      final qtyKg = (delta / 10) * 0.024 * volumeM3;
      addProduct("Correcteur TAC", qtyKg, "kg");
      addValidation("Pour le TAC élevé, traiter en plusieurs cycles et ne pas injecter toute la dose d’un coup.");
    }

    if (th < 150 && lsi < -0.10) {
      score -= 1;
      addAnalyse("TH bas : la faible dureté calcique accentue le caractère agressif de l’eau.");
      addAdjustment("Relever le calcium pour sécuriser les surfaces et le LSI.");
      final delta = 180 - th;
      final qtyKg = (max(0, delta) / 10) * 0.015 * volumeM3;
      addProduct("Calcium+", qtyKg, "kg");
    } else if (th > 350 && lsi > 0.20) {
      score -= 1;
      addAnalyse("TH élevé combiné à un LSI positif : risque renforcé de dépôts calcaires.");
      addAdjustment("Limiter l’entartrage et surveiller l’échangeur, la ligne d’eau et la cellule.");
      final qtyL = lsi > 0.6 ? volumeM3 / 40 : volumeM3 / 50;
      addProduct("Séquestrant calcaire", qtyL, "L");
    }

    if (stabilisant > 80) {
      score -= 1;
      final targetCya = treatmentType == 'sel' ? 60.0 : 40.0;
      final renewalFraction = (1 - (targetCya / stabilisant)).clamp(0.0, 1.0);
      final renewalPercent = (renewalFraction * 100).round();
      addAnalyse("Stabilisant trop élevé : le chlore libre devient moins réactif.");
      addAdjustment(
        "Renouveler environ $renewalPercent% d’eau pour revenir sur un stabilisant plus efficace.",
      );
      addValidation("Après renouvellement d’eau, refaire un contrôle complet TAC / pH / chlore.");
    } else if (stabilisant < 20 && treatmentType != 'sel') {
      score -= 1;
      addAnalyse("Stabilisant faible : le chlore sera plus sensible aux UV.");
      addAdjustment("Revenir vers 25 – 40 ppm de stabilisant.");
      final delta = 30 - stabilisant;
      final qtyKg = (max(0, delta) * volumeM3) / 1000;
      addProduct("Stabilisant", qtyKg, "kg");
    }

    if (treatmentType == 'sel') {
      if (sel != null && sel < 3500) {
        score -= 1;
        addAnalyse("Taux de sel insuffisant pour une production stable de l’électrolyseur.");
        addAdjustment("Remonter le taux de sel vers 3800 – 4200 ppm selon la cellule.");
        final kgSel = ((4000 - sel) * volumeM3) / 1000;
        addProduct("Sel piscine", kgSel, "kg");
      } else if (sel != null && sel > 5000) {
        score -= 1;
        addAnalyse("Taux de sel trop élevé : usure accélérée possible de la cellule et surconductivité.");
        addAdjustment("Diluer partiellement le bassin avant nouvelle mise en production.");
      }

      if (chlore < 1.5 && ph >= 7.2 && ph <= 7.6) {
        addAnalyse("Production chlore insuffisante malgré un pH correct : vérifier cellule, inversion de polarité et temps de production.");
        addVerification("Contrôler l’état de la cellule d’électrolyse et l’absence de dépôt.");
      }

      if ((temperature ?? 25) < 15) {
        addAnalyse("Température basse : de nombreux électrolyseurs produisent moins en eau froide.");
      }
    }

    if (hasGreenWater) {
      score -= 2;
      addAnalyse("Observation terrain : présence d’eau verte, signe probable de prolifération algale.");
      addAdjustment("Brossage complet, filtration continue et traitement choc jusqu’au retour de transparence.");
      addVerification("Nettoyer le panier préfiltre et surveiller la pression filtre après traitement.");
    } else if (hasCloudyWater) {
      score -= 1;
      addAnalyse("Observation terrain : eau trouble, possiblement liée à une filtration insuffisante ou à un déséquilibre chimique.");
      addVerification("Contrôler le média filtrant et la durée réelle de filtration.");
    }

    score = score.clamp(0, 10);

    final statut = score >= 8
        ? "Eau équilibrée"
        : score >= 5
            ? "Correction recommandée"
            : "Intervention urgente recommandée";

    final criticalIssue =
        hasGreenWater || chlore < 0.5 || ph <= 6.8 || ph >= 7.9 || lsi.abs() > 0.6;
    final urgenceLabel = criticalIssue
        ? "Intervention urgente"
        : score >= 8
            ? "Aucune urgence immédiate"
            : "Intervention conseillée";

    final whyNow = <String>[];
    String explanation;
    if (lsi < -0.30) {
      whyNow.addAll([
        "Réduire l’agressivité de l’eau",
        "Protéger les surfaces et équipements",
      ]);
      explanation =
          "L’eau est orientée corrosion : l’objectif prioritaire est de sécuriser l’équilibre calco-carbonique avant d’affiner le reste.";
    } else if (lsi > 0.30) {
      whyNow.addAll([
        "Limiter les dépôts calcaires",
        "Préserver filtration et cellule",
      ]);
      explanation =
          "L’équilibre est orienté entartrage : il faut corriger les paramètres qui poussent l’eau à déposer du carbonate de calcium.";
    } else if (criticalIssue) {
      whyNow.addAll([
        "Rétablir une désinfection efficace",
        "Stabiliser rapidement les paramètres critiques",
      ]);
      explanation =
          "Un ou plusieurs paramètres sont franchement sortis de la zone de maîtrise. La priorité est une remise à niveau rapide puis un recontrôle.";
    } else {
      whyNow.addAll([
        "Consolider l’équilibre actuel",
        "Éviter une dérive progressive",
      ]);
      explanation =
          "Le bassin est globalement pilotable, mais quelques ajustements ciblés amélioreront la stabilité et le confort.";
    }

    if (ajustementChimique.isEmpty) {
      ajustementChimique.add("Aucun ajustement chimique immédiat : maintien et recontrôle planifié.");
    }

    final totalMin = produits.fold<double>(0, (a, b) => a + b.budgetMin);
    final totalMax = produits.fold<double>(0, (a, b) => a + b.budgetMax);
    final mainOeuvre = produits.isEmpty ? 0.0 : pricing.defaultMainOeuvre;

    return DiagnosticResult(
      score: score,
      statut: statut,
      lsi: lsi,
      lsiInterpretation: lsiInterpretation,
      urgenceLabel: urgenceLabel,
      whyNow: whyNow,
      simpleExplanation: explanation,
      interventionTitre: "Ajustement chimique",
      ajustementChimique: ajustementChimique,
      verificationTechnique: verificationTechnique,
      validation: validation,
      dureeEstimee: criticalIssue ? "45–60 min" : "30–45 min",
      stabilisation: criticalIssue ? "Sous 12–24h" : "Sous 24–48h",
      analyse: analyse.isEmpty ? ["Paramètres globalement cohérents"] : analyse,
      produits: produits,
      totalProduitsMin: totalMin,
      totalProduitsMax: totalMax,
      mainOeuvre: mainOeuvre,
      totalMin: totalMin + mainOeuvre,
      totalMax: totalMax + mainOeuvre,
    );
  }
}
