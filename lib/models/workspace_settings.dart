class WorkspaceSettings {
  final String localeCode;
  final String currencyCode;
  final String countryCode;
  final String timeZoneId;
  final String unitSystem;

  const WorkspaceSettings({
    required this.localeCode,
    required this.currencyCode,
    required this.countryCode,
    required this.timeZoneId,
    required this.unitSystem,
  });

  factory WorkspaceSettings.defaults() {
    return const WorkspaceSettings(
      localeCode: 'fr-FR',
      currencyCode: 'EUR',
      countryCode: 'FR',
      timeZoneId: 'Europe/Paris',
      unitSystem: 'metric',
    );
  }

  factory WorkspaceSettings.fromJson(Map<String, dynamic> json) {
    final defaults = WorkspaceSettings.defaults();
    return WorkspaceSettings(
      localeCode: json['localeCode'] ?? defaults.localeCode,
      currencyCode: json['currencyCode'] ?? defaults.currencyCode,
      countryCode: json['countryCode'] ?? defaults.countryCode,
      timeZoneId: json['timeZoneId'] ?? defaults.timeZoneId,
      unitSystem: json['unitSystem'] ?? defaults.unitSystem,
    );
  }

  Map<String, dynamic> toJson() => {
        'localeCode': localeCode,
        'currencyCode': currencyCode,
        'countryCode': countryCode,
        'timeZoneId': timeZoneId,
        'unitSystem': unitSystem,
      };

  WorkspaceSettings copyWith({
    String? localeCode,
    String? currencyCode,
    String? countryCode,
    String? timeZoneId,
    String? unitSystem,
  }) {
    return WorkspaceSettings(
      localeCode: localeCode ?? this.localeCode,
      currencyCode: currencyCode ?? this.currencyCode,
      countryCode: countryCode ?? this.countryCode,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      unitSystem: unitSystem ?? this.unitSystem,
    );
  }
}
