import 'package:flutter_test/flutter_test.dart';

import 'package:ac_piscine_pro/models/company_profile.dart';

void main() {
  group('CompanyProfile', () {
    test('migre un ancien siret vers les nouveaux champs', () {
      final profile = CompanyProfile.fromJson({
        'companyName': 'HydrAzur Pro',
        'siret': '12345678901234',
      });

      expect(profile.businessRegistrationLabel, 'SIRET');
      expect(profile.businessRegistrationValue, '12345678901234');
      expect(profile.taxRegistrationValue, isEmpty);
    });

    test('serialize les nouveaux champs sans reintroduire siret', () {
      final profile = CompanyProfile(
        companyName: 'HydrAzur Pro',
        phone: '',
        email: '',
        address: '',
        website: '',
        countryCode: 'FR',
        localeCode: 'fr-FR',
        currencyCode: 'EUR',
        businessRegistrationLabel: 'Company number',
        businessRegistrationValue: 'ABC-42',
        taxRegistrationValue: 'VAT-99',
        technicianDefaultName: '',
        legalMention:
            'Document établi à titre d’intervention et de suivi technique.',
      );

      final json = profile.toJson();

      expect(json['businessRegistrationLabel'], 'Company number');
      expect(json['businessRegistrationValue'], 'ABC-42');
      expect(json['taxRegistrationValue'], 'VAT-99');
      expect(json.containsKey('siret'), isFalse);
    });
  });
}
