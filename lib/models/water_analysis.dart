class WaterAnalysis {
  String dateIso;
  double ph;
  double chlore;
  double tac;
  double th;
  double stabilisant;
  double temperature;
  double tds;
  double lsi;
  double stabilityScore;
  bool eauSalee;
  bool liner;
  String observation;
  double mainOeuvre;

  WaterAnalysis({
    required this.dateIso,
    required this.ph,
    required this.chlore,
    required this.tac,
    required this.th,
    required this.stabilisant,
    required this.temperature,
    required this.tds,
    required this.lsi,
    required this.stabilityScore,
    required this.eauSalee,
    required this.liner,
    required this.observation,
    required this.mainOeuvre,
  });

  factory WaterAnalysis.fromJson(Map<String, dynamic> json) {
    return WaterAnalysis(
      dateIso: json['dateIso'] ?? '',
      ph: (json['ph'] ?? 0).toDouble(),
      chlore: (json['chlore'] ?? 0).toDouble(),
      tac: (json['tac'] ?? 0).toDouble(),
      th: (json['th'] ?? 0).toDouble(),
      stabilisant: (json['stabilisant'] ?? 0).toDouble(),
      temperature: (json['temperature'] ?? 0).toDouble(),
      tds: (json['tds'] ?? 0).toDouble(),
      lsi: (json['lsi'] ?? 0).toDouble(),
      stabilityScore: (json['stabilityScore'] ?? -1).toDouble(),
      eauSalee: json['eauSalee'] ?? false,
      liner: json['liner'] ?? false,
      observation: json['observation'] ?? '',
      mainOeuvre: (json['mainOeuvre'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'dateIso': dateIso,
        'ph': ph,
        'chlore': chlore,
        'tac': tac,
        'th': th,
        'stabilisant': stabilisant,
        'temperature': temperature,
        'tds': tds,
        'lsi': lsi,
        'stabilityScore': stabilityScore,
        'eauSalee': eauSalee,
        'liner': liner,
        'observation': observation,
        'mainOeuvre': mainOeuvre,
      };

  int get score {
    int s = 10;
    if (ph < 7.2 || ph > 7.6) s -= 2;
    if (chlore < 1 || chlore > 3) s -= 2;
    if (tac < 80 || tac > 120) s -= 2;
    if (th < 150 || th > 250) s -= 2;
    if (stabilisant < 30 || stabilisant > 70) s -= 2;
    return s < 0 ? 0 : s;
  }

  String get status {
    if (score >= 8) return 'Eau equilibree';
    if (score >= 5) return 'Eau a corriger';
    return 'Eau desequilibree';
  }
}
