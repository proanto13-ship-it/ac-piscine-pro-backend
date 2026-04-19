class CompanyProfile {
  final String companyName;
  final String phone;
  final String email;
  final String address;
  final String website;
  final String countryCode;
  final String localeCode;
  final String currencyCode;
  final String businessRegistrationLabel;
  final String businessRegistrationValue;
  final String taxRegistrationValue;
  final String technicianDefaultName;
  final String legalMention;

  const CompanyProfile({
    required this.companyName,
    required this.phone,
    required this.email,
    required this.address,
    required this.website,
    required this.countryCode,
    required this.localeCode,
    required this.currencyCode,
    required this.businessRegistrationLabel,
    required this.businessRegistrationValue,
    required this.taxRegistrationValue,
    required this.technicianDefaultName,
    required this.legalMention,
  });

  factory CompanyProfile.defaults() {
    return const CompanyProfile(
      companyName: 'HydrAzur Pro',
      phone: '',
      email: '',
      address: '',
      website: '',
      countryCode: 'FR',
      localeCode: 'fr-FR',
      currencyCode: 'EUR',
      businessRegistrationLabel: '',
      businessRegistrationValue: '',
      taxRegistrationValue: '',
      technicianDefaultName: '',
      legalMention:
          'Document établi à titre d’intervention et de suivi technique.',
    );
  }

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    final defaults = CompanyProfile.defaults();
    final legacySiret = json['siret']?.toString() ?? '';
    return CompanyProfile(
      companyName: json['companyName'] ?? defaults.companyName,
      phone: json['phone'] ?? defaults.phone,
      email: json['email'] ?? defaults.email,
      address: json['address'] ?? defaults.address,
      website: json['website'] ?? defaults.website,
      countryCode: json['countryCode'] ?? defaults.countryCode,
      localeCode: json['localeCode'] ?? defaults.localeCode,
      currencyCode: json['currencyCode'] ?? defaults.currencyCode,
      businessRegistrationLabel: json['businessRegistrationLabel'] ??
          (legacySiret.isNotEmpty
              ? 'SIRET'
              : defaults.businessRegistrationLabel),
      businessRegistrationValue:
          json['businessRegistrationValue'] ?? legacySiret,
      taxRegistrationValue:
          json['taxRegistrationValue'] ?? defaults.taxRegistrationValue,
      technicianDefaultName:
          json['technicianDefaultName'] ?? defaults.technicianDefaultName,
      legalMention: json['legalMention'] ?? defaults.legalMention,
    );
  }

  Map<String, dynamic> toJson() => {
        'companyName': companyName,
        'phone': phone,
        'email': email,
        'address': address,
        'website': website,
        'countryCode': countryCode,
        'localeCode': localeCode,
        'currencyCode': currencyCode,
        'businessRegistrationLabel': businessRegistrationLabel,
        'businessRegistrationValue': businessRegistrationValue,
        'taxRegistrationValue': taxRegistrationValue,
        'technicianDefaultName': technicianDefaultName,
        'legalMention': legalMention,
      };

  CompanyProfile copyWith({
    String? companyName,
    String? phone,
    String? email,
    String? address,
    String? website,
    String? countryCode,
    String? localeCode,
    String? currencyCode,
    String? businessRegistrationLabel,
    String? businessRegistrationValue,
    String? taxRegistrationValue,
    String? technicianDefaultName,
    String? legalMention,
  }) {
    return CompanyProfile(
      companyName: companyName ?? this.companyName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      website: website ?? this.website,
      countryCode: countryCode ?? this.countryCode,
      localeCode: localeCode ?? this.localeCode,
      currencyCode: currencyCode ?? this.currencyCode,
      businessRegistrationLabel:
          businessRegistrationLabel ?? this.businessRegistrationLabel,
      businessRegistrationValue:
          businessRegistrationValue ?? this.businessRegistrationValue,
      taxRegistrationValue: taxRegistrationValue ?? this.taxRegistrationValue,
      technicianDefaultName:
          technicianDefaultName ?? this.technicianDefaultName,
      legalMention: legalMention ?? this.legalMention,
    );
  }

  bool get hasBusinessRegistration =>
      businessRegistrationValue.trim().isNotEmpty;

  bool get hasTaxRegistration => taxRegistrationValue.trim().isNotEmpty;

  String get businessRegistrationDisplayLabel {
    final trimmed = businessRegistrationLabel.trim();
    return trimmed.isEmpty ? 'Business registration' : trimmed;
  }
}
