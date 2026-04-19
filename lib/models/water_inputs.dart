enum TreatmentType { chlore, brome, sel, oxygene }

class WaterInputs {
  final double volumeM3;
  final double ph;
  final double freeChlorinePpm;
  final double tacPpm;
  final double thPpm;
  final double cyaPpm;
  final double waterTempC;
  final bool greenWater;
  final bool cloudyWater;
  final bool strongSun;
  final bool heavyBatherLoad;
  final String observation;
  final TreatmentType treatmentType;

  WaterInputs({
    required this.volumeM3,
    required this.ph,
    required this.freeChlorinePpm,
    required this.tacPpm,
    required this.thPpm,
    required this.cyaPpm,
    required this.waterTempC,
    required this.greenWater,
    required this.cloudyWater,
    required this.strongSun,
    required this.heavyBatherLoad,
    required this.observation,
    required this.treatmentType,
  });
}
