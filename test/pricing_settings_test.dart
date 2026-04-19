import 'package:flutter_test/flutter_test.dart';

import 'package:ac_piscine_pro/models/pricing_settings.dart';

void main() {
  group('PricingSettings', () {
    test('migre les anciennes cles label vers des codes stables', () {
      final settings = PricingSettings.fromJson({
        'showBudgetEstimates': true,
        'defaultMainOeuvre': 95,
        'customPricing': {
          'Chlore choc': {'minPrice': 11, 'maxPrice': 15},
          'pH-': {'minPrice': 7, 'maxPrice': 10},
        },
      });

      expect(settings.customPricing.containsKey('chlore_choc'), isTrue);
      expect(settings.customPricing.containsKey('ph_minus'), isTrue);
      expect(settings.customPricing.containsKey('Chlore choc'), isFalse);
      expect(settings.customPricing.containsKey('pH-'), isFalse);
      expect(settings.priceFor('Chlore choc').minPrice, 11);
      expect(settings.priceFor('chlore_choc').maxPrice, 15);
      expect(settings.priceFor('pH-').minPrice, 7);
      expect(settings.priceFor('ph_minus').maxPrice, 10);
    });

    test('defaults utilise des codes comme cles', () {
      final settings = PricingSettings.defaults();

      expect(settings.customPricing.containsKey('chlore_choc'), isTrue);
      expect(settings.customPricing.containsKey('Chlore choc'), isFalse);
    });

    test('toJson ecrit les codes stables', () {
      final settings = PricingSettings.defaults();
      final json = settings.toJson();
      final customPricing =
          Map<String, dynamic>.from(json['customPricing'] as Map);

      expect(customPricing.containsKey('chlore_choc'), isTrue);
      expect(customPricing.containsKey('Chlore choc'), isFalse);
    });

    test('fournit les helpers temporaires label et code', () {
      expect(productCodeFromLegacyLabel('Chlore choc'), 'chlore_choc');
      expect(legacyLabelForProductCode('chlore_choc'), 'Chlore choc');
      expect(defaultPricingFor('chlore_choc').minPrice, 8);
      expect(defaultPricingFor('Chlore choc').maxPrice, 12);
    });
  });
}
