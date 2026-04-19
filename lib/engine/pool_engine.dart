import 'dart:math';
import 'pool_models.dart';
import 'pool_constants.dart';

class PoolEngine {
  static double correctedAlkalinity(PoolData data) {
    final corrected = data.tac - (data.stabilisant * 0.33);
    return corrected.clamp(25, 400);
  }

  static double estimatedTds(PoolData data) {
    final salt = data.sel ?? 0;
    return max(1000, 1000 + salt);
  }

  static double calculLSI(PoolData data) {
    final tds = estimatedTds(data);
    final carbonateAlkalinity = correctedAlkalinity(data);
    final calciumHardness = data.th.clamp(25, 800);
    final temperatureKelvin = (data.temperature + 273.15).clamp(250, 350);

    final A = (log(tds) / ln10 - 1) / 10;
    final B = -13.12 * log(temperatureKelvin) / ln10 + 34.55;
    final C = log(calciumHardness) / ln10 - 0.4;
    final D = log(carbonateAlkalinity) / ln10;

    final pHs = (9.3 + A + B) - (C + D);
    return data.ph - pHs;
  }

  static double calculScore(PoolData data, double lsi) {
    double scorePH =
        100 - ((data.ph - PoolConstants.idealPH).abs() * 20);
    double scoreChlore =
        100 - ((data.chlore - PoolConstants.idealChlore).abs() * 30);
    double scoreTAC =
        100 - ((data.tac - PoolConstants.idealTAC).abs() * 0.5);
    double scoreLSI =
        100 - (lsi.abs() * 100);
    double scoreStab =
        100 - ((data.stabilisant - PoolConstants.idealStabilisant).abs() * 1.5);

    scorePH = scorePH.clamp(0, 100);
    scoreChlore = scoreChlore.clamp(0, 100);
    scoreTAC = scoreTAC.clamp(0, 100);
    scoreLSI = scoreLSI.clamp(0, 100);
    scoreStab = scoreStab.clamp(0, 100);

    return (scorePH * PoolConstants.weightPH) +
        (scoreChlore * PoolConstants.weightChlore) +
        (scoreTAC * PoolConstants.weightTAC) +
        (scoreLSI * PoolConstants.weightLSI) +
        (scoreStab * PoolConstants.weightStab);
  }

  static String interpretation(double score) {
    if (score < 60) return "Instabilité critique";
    if (score < 75) return "Surveillance nécessaire";
    if (score < 90) return "Équilibre correct";
    return "Eau optimale";
  }

  static PoolResult analyse(PoolData data) {
    final lsi = calculLSI(data);
    final score = calculScore(data, lsi);
    final text = interpretation(score);

    return PoolResult(
      lsi: lsi,
      stabilityScore: score,
      interpretation: text,
    );
  }
}
