class AiSummaryService {
  static Future<String> generateSummary({
    required String clientName,
    required double ph,
    required double chlore,
    required double tac,
    required double th,
    required double stabilisant,
    required double? sel,
    required double lsi,
    required int score,
    required String lsiInterpretation,
    required List<String> analyse,
    required List<String> ajustementChimique,
    required List<dynamic> produits,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));

    final points = <String>[];

    if (score <= 4) {
      points.add(
        "L’analyse met en évidence un déséquilibre important nécessitant une intervention rapide.",
      );
    } else if (score <= 7) {
      points.add(
        "L’eau présente un équilibre partiel avec des corrections recommandées pour éviter une dégradation.",
      );
    } else {
      points.add(
        "Les paramètres sont globalement satisfaisants avec un bon niveau de stabilité.",
      );
    }

    if (ph < 7.0) {
      points.add(
        "Le pH est trop bas, ce qui rend l’eau corrosive et peut fragiliser les équipements et le revêtement.",
      );
    } else if (ph > 7.6) {
      points.add(
        "Le pH est trop élevé, ce qui réduit l’efficacité du traitement désinfectant.",
      );
    }

    if (chlore < 1.5) {
      points.add(
        "Le niveau de désinfectant est insuffisant pour garantir une protection optimale de l’eau.",
      );
    }

    if (lsi < -0.3) {
      points.add(
        "L’indice de Taylor confirme une eau agressive avec un risque de corrosion.",
      );
    } else if (lsi > 0.3) {
      points.add(
        "L’indice de Taylor indique un risque d’entartrage et de dépôts calcaires.",
      );
    }

    if (sel != null && sel > 0 && sel < 3500) {
      points.add(
        "Le taux de sel est inférieur à la zone optimale pour une production correcte de chlore.",
      );
    }

    if (ajustementChimique.isNotEmpty) {
      points.add(
        "L’action prioritaire consiste à ${ajustementChimique.first.toLowerCase()}.",
      );
    }

    if (produits.isNotEmpty) {
      points.add(
        "Un traitement correctif avec produit(s) adapté(s) est recommandé pour rétablir l’équilibre.",
      );
    }

    return points.join(" ");
  }
}

