import 'package:flutter_test/flutter_test.dart';

import 'package:ac_piscine_pro/logic/diagnostic_logic.dart';
import 'package:ac_piscine_pro/models/pricing_settings.dart';

void main() {
  group('DiagnosticLogic', () {
    test('garde une eau equilibrée sans produit inutile', () {
      final result = DiagnosticLogic.build(
        ph: 7.3,
        chlore: 2.0,
        tac: 120,
        th: 200,
        stabilisant: 40,
        volumeM3: 50,
        observation: '',
        treatmentType: 'chlore',
        temperature: 25,
        pricingSettings: PricingSettings.defaults(),
      );

      expect(result.score, greaterThanOrEqualTo(9));
      expect(result.produits, isEmpty);
      expect(result.urgenceLabel, 'Aucune urgence immédiate');
    });

    test('propose des corrections sur une eau desequilibree', () {
      final result = DiagnosticLogic.build(
        ph: 7.9,
        chlore: 0.5,
        tac: 60,
        th: 350,
        stabilisant: 90,
        volumeM3: 40,
        observation: 'eau verte',
        treatmentType: 'chlore',
        temperature: 26,
        pricingSettings: PricingSettings.defaults(),
      );

      final labels = result.produits.map((item) => item.label).toList();
      final chloreChoc =
          result.produits.firstWhere((item) => item.label == 'Chlore choc');

      expect(result.score, lessThan(5));
      expect(result.urgenceLabel, 'Intervention urgente');
      expect(labels, contains('pH-'));
      expect(labels, contains('Chlore choc'));
      expect(labels, contains('TAC+'));
      expect(chloreChoc.qty, closeTo(0.5, 0.1));
      expect(
        result.ajustementChimique.join(' '),
        contains('chloration choc'),
      );
    });

    test('recommande un renouvellement d eau si le stabilisant est trop haut', () {
      final result = DiagnosticLogic.build(
        ph: 7.4,
        chlore: 1.8,
        tac: 110,
        th: 220,
        stabilisant: 100,
        volumeM3: 50,
        observation: '',
        treatmentType: 'chlore',
        temperature: 26,
        pricingSettings: PricingSettings.defaults(),
      );

      expect(
        result.ajustementChimique.join(' '),
        contains('Renouveler environ'),
      );
    });
  });
}
