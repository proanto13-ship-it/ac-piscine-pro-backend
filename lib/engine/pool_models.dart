class PoolData {
  final double volume;
  final double ph;
  final double chlore;
  final double tac;
  final double th;
  final double stabilisant;
  final double temperature;
  final double? sel;

  PoolData({
    required this.volume,
    required this.ph,
    required this.chlore,
    required this.tac,
    required this.th,
    required this.stabilisant,
    required this.temperature,
    this.sel,
  });
}

class PoolResult {
  final double lsi;
  final double stabilityScore;
  final String interpretation;

  PoolResult({
    required this.lsi,
    required this.stabilityScore,
    required this.interpretation,
  });
}
