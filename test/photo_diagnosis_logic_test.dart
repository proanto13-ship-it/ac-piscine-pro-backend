import 'package:flutter_test/flutter_test.dart';

import 'package:ac_piscine_pro/logic/photo_diagnosis_logic.dart';

void main() {
  group('PhotoDiagnosisLogic', () {
    test('oriente vers les algues moutardes quand les indices convergent', () {
      final result = PhotoDiagnosisLogic.analyze(
        const PhotoDiagnosisInput(
          hasContextPhoto: true,
          contextPhotoUsable: true,
          hasObservationPhoto: true,
          observationPhotoUsable: true,
          hasAfterBrushPhoto: true,
          afterBrushPhotoUsable: true,
          evidenceQualityScore: 7,
          yellowBrownPowder: true,
          greenTint: false,
          reappearsAfterBrushing: true,
          shadedArea: true,
          cloudyWater: false,
          slipperySurface: true,
          ph: 7.7,
          freeChlorine: 0.6,
          stabilizer: 85,
          temperature: 27,
        ),
      );

      expect(result.type, PhotoSuspicionType.mustard);
      expect(result.confidence, anyOf('Moyenne', 'Forte'));
      expect(result.title, contains('moutardes'));
      expect(result.mustardScore, greaterThan(result.greenScore));
      expect(result.mustardScore, greaterThan(result.depositScore));
    });

    test('oriente vers les algues vertes si la lecture est verdissante et trouble', () {
      final result = PhotoDiagnosisLogic.analyze(
        const PhotoDiagnosisInput(
          hasContextPhoto: true,
          contextPhotoUsable: true,
          hasObservationPhoto: true,
          observationPhotoUsable: true,
          hasAfterBrushPhoto: true,
          afterBrushPhotoUsable: true,
          evidenceQualityScore: 7,
          yellowBrownPowder: false,
          greenTint: true,
          reappearsAfterBrushing: true,
          shadedArea: false,
          cloudyWater: true,
          slipperySurface: true,
          ph: 7.8,
          freeChlorine: 0.4,
          stabilizer: 35,
          temperature: 29,
        ),
      );

      expect(result.type, PhotoSuspicionType.green);
      expect(result.title, contains('vertes'));
      expect(result.greenScore, greaterThan(result.mustardScore));
    });

    test('oriente vers un dépôt non biologique quand le dépôt ne revient pas', () {
      final result = PhotoDiagnosisLogic.analyze(
        const PhotoDiagnosisInput(
          hasContextPhoto: true,
          contextPhotoUsable: true,
          hasObservationPhoto: true,
          observationPhotoUsable: true,
          hasAfterBrushPhoto: false,
          afterBrushPhotoUsable: false,
          evidenceQualityScore: 4,
          yellowBrownPowder: true,
          greenTint: false,
          reappearsAfterBrushing: false,
          shadedArea: false,
          cloudyWater: false,
          slipperySurface: false,
          ph: 7.2,
          freeChlorine: 2.5,
          stabilizer: 35,
          temperature: 22,
        ),
      );

      expect(result.type, PhotoSuspicionType.deposit);
      expect(result.title, contains('Dépôt'));
      expect(result.depositScore, greaterThan(result.greenScore));
    });

    test('abaisse la confiance quand la preuve photo est insuffisante', () {
      final result = PhotoDiagnosisLogic.analyze(
        const PhotoDiagnosisInput(
          hasContextPhoto: false,
          contextPhotoUsable: false,
          hasObservationPhoto: false,
          observationPhotoUsable: false,
          hasAfterBrushPhoto: false,
          afterBrushPhotoUsable: false,
          evidenceQualityScore: 0,
          yellowBrownPowder: true,
          greenTint: false,
          reappearsAfterBrushing: true,
          shadedArea: true,
          cloudyWater: false,
          slipperySurface: false,
          ph: 7.6,
          freeChlorine: 0.8,
          stabilizer: 80,
          temperature: 26,
        ),
      );

      expect(result.reliabilityLimited, isTrue);
      expect(result.evidenceLabel, anyOf('Fragile', 'Insuffisante'));
      expect(result.confidence, 'Faible');
      expect(result.evidenceWarnings, isNotEmpty);
    });
  });
}
