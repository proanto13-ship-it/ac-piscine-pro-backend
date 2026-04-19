class ProductPricing {
  final double minPrice;
  final double maxPrice;

  const ProductPricing({
    required this.minPrice,
    required this.maxPrice,
  });

  factory ProductPricing.fromJson(Map<String, dynamic> json) {
    return ProductPricing(
      minPrice: (json['minPrice'] ?? 0).toDouble(),
      maxPrice: (json['maxPrice'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'minPrice': minPrice,
        'maxPrice': maxPrice,
      };

  ProductPricing copyWith({
    double? minPrice,
    double? maxPrice,
  }) {
    return ProductPricing(
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
    );
  }
}

class PricingProductDefinition {
  final String code;
  final String defaultLabel;
  final String unitLabel;
  final ProductPricing defaultPricing;

  const PricingProductDefinition({
    required this.code,
    required this.defaultLabel,
    required this.unitLabel,
    required this.defaultPricing,
  });

  String get label => defaultLabel;
}

const List<PricingProductDefinition> pricingCatalog = [
  PricingProductDefinition(
    code: 'ph_minus',
    defaultLabel: 'pH-',
    unitLabel: '€/kg',
    defaultPricing: ProductPricing(minPrice: 6, maxPrice: 9),
  ),
  PricingProductDefinition(
    code: 'ph_plus',
    defaultLabel: 'pH+',
    unitLabel: '€/kg',
    defaultPricing: ProductPricing(minPrice: 6, maxPrice: 9),
  ),
  PricingProductDefinition(
    code: 'chlore_choc',
    defaultLabel: 'Chlore choc',
    unitLabel: '€/kg',
    defaultPricing: ProductPricing(minPrice: 8, maxPrice: 12),
  ),
  PricingProductDefinition(
    code: 'tac_plus',
    defaultLabel: 'TAC+',
    unitLabel: '€/kg',
    defaultPricing: ProductPricing(minPrice: 5, maxPrice: 8),
  ),
  PricingProductDefinition(
    code: 'correcteur_tac',
    defaultLabel: 'Correcteur TAC',
    unitLabel: '€/kg',
    defaultPricing: ProductPricing(minPrice: 7, maxPrice: 11),
  ),
  PricingProductDefinition(
    code: 'sequestrant_calcaire',
    defaultLabel: 'Séquestrant calcaire',
    unitLabel: '€/L',
    defaultPricing: ProductPricing(minPrice: 12, maxPrice: 18),
  ),
  PricingProductDefinition(
    code: 'sel_piscine',
    defaultLabel: 'Sel piscine',
    unitLabel: '€/kg',
    defaultPricing: ProductPricing(minPrice: 0.25, maxPrice: 0.40),
  ),
  PricingProductDefinition(
    code: 'calcium_plus',
    defaultLabel: 'Calcium+',
    unitLabel: '€/kg',
    defaultPricing: ProductPricing(minPrice: 4, maxPrice: 7),
  ),
  PricingProductDefinition(
    code: 'stabilisant',
    defaultLabel: 'Stabilisant',
    unitLabel: '€/kg',
    defaultPricing: ProductPricing(minPrice: 9, maxPrice: 14),
  ),
];

PricingProductDefinition? pricingProductDefinitionForCode(String code) {
  for (final item in pricingCatalog) {
    if (item.code == code) {
      return item;
    }
  }
  return null;
}

PricingProductDefinition? pricingProductDefinitionForLegacyLabel(String label) {
  for (final item in pricingCatalog) {
    if (item.defaultLabel == label) {
      return item;
    }
  }
  return null;
}

PricingProductDefinition? pricingProductDefinitionFor(
    String codeOrLegacyLabel) {
  return pricingProductDefinitionForCode(codeOrLegacyLabel) ??
      pricingProductDefinitionForLegacyLabel(codeOrLegacyLabel);
}

String? productCodeFromLegacyLabel(String label) {
  return pricingProductDefinitionForLegacyLabel(label)?.code;
}

String? legacyLabelForProductCode(String code) {
  return pricingProductDefinitionForCode(code)?.defaultLabel;
}

ProductPricing defaultPricingFor(String codeOrLegacyLabel) {
  final definition = pricingProductDefinitionFor(codeOrLegacyLabel);
  if (definition != null) {
    return definition.defaultPricing;
  }
  return const ProductPricing(minPrice: 0, maxPrice: 0);
}

class PricingSettings {
  final bool showBudgetEstimates;
  final double defaultMainOeuvre;
  final Map<String, ProductPricing> customPricing;

  const PricingSettings({
    required this.showBudgetEstimates,
    required this.defaultMainOeuvre,
    required this.customPricing,
  });

  factory PricingSettings.defaults() {
    return PricingSettings(
      showBudgetEstimates: false,
      defaultMainOeuvre: 80,
      customPricing: {
        for (final item in pricingCatalog) item.code: item.defaultPricing,
      },
    );
  }

  factory PricingSettings.fromJson(Map<String, dynamic> json) {
    final rawCustom = json['customPricing'];
    final customPricing = <String, ProductPricing>{};

    if (rawCustom is Map) {
      rawCustom.forEach((key, value) {
        final normalizedKey = _normalizePricingKey(key.toString());
        if (value is Map<String, dynamic>) {
          customPricing[normalizedKey] = ProductPricing.fromJson(value);
        } else if (value is Map) {
          customPricing[normalizedKey] = ProductPricing.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }

    final defaults = PricingSettings.defaults();
    final merged = <String, ProductPricing>{
      ...defaults.customPricing,
      ...customPricing,
    };

    return PricingSettings(
      showBudgetEstimates:
          json['showBudgetEstimates'] ?? defaults.showBudgetEstimates,
      defaultMainOeuvre:
          (json['defaultMainOeuvre'] ?? defaults.defaultMainOeuvre).toDouble(),
      customPricing: merged,
    );
  }

  Map<String, dynamic> toJson() => {
        'showBudgetEstimates': showBudgetEstimates,
        'defaultMainOeuvre': defaultMainOeuvre,
        'customPricing': customPricing.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      };

  PricingSettings copyWith({
    bool? showBudgetEstimates,
    double? defaultMainOeuvre,
    Map<String, ProductPricing>? customPricing,
  }) {
    return PricingSettings(
      showBudgetEstimates: showBudgetEstimates ?? this.showBudgetEstimates,
      defaultMainOeuvre: defaultMainOeuvre ?? this.defaultMainOeuvre,
      customPricing: customPricing ?? this.customPricing,
    );
  }

  ProductPricing priceFor(String label) {
    final normalizedKey = _normalizePricingKey(label);
    return customPricing[normalizedKey] ?? defaultPricingFor(label);
  }

  static String _normalizePricingKey(String key) {
    return productCodeFromLegacyLabel(key) ?? key;
  }
}
