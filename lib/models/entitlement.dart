enum EntitlementFlag {
  unlimitedClients,
  pdfExport,
  teamMembers,
  cloudSync,
}

class Entitlement {
  final EntitlementFlag flag;
  final bool enabled;

  const Entitlement({
    required this.flag,
    required this.enabled,
  });

  factory Entitlement.fromJson(Map<String, dynamic> json) {
    return Entitlement(
      flag: _flagFromJson(json['flag']),
      enabled: json['enabled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'flag': flag.name,
        'enabled': enabled,
      };

  static EntitlementFlag _flagFromJson(dynamic raw) {
    switch (raw?.toString()) {
      case 'unlimitedClients':
        return EntitlementFlag.unlimitedClients;
      case 'pdfExport':
        return EntitlementFlag.pdfExport;
      case 'teamMembers':
        return EntitlementFlag.teamMembers;
      case 'cloudSync':
      default:
        return EntitlementFlag.cloudSync;
    }
  }
}
