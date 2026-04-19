import 'entitlement.dart';

class Plan {
  final String id;
  final String displayName;
  final List<Entitlement> entitlements;
  final int? clientLimit;
  final int trialDays;

  const Plan({
    required this.id,
    required this.displayName,
    required this.entitlements,
    this.clientLimit,
    this.trialDays = 0,
  });

  static const Plan free = Plan(
    id: 'free',
    displayName: 'Free',
    clientLimit: 10,
    trialDays: 0,
    entitlements: [
      Entitlement(
        flag: EntitlementFlag.unlimitedClients,
        enabled: false,
      ),
      Entitlement(
        flag: EntitlementFlag.pdfExport,
        enabled: false,
      ),
      Entitlement(
        flag: EntitlementFlag.teamMembers,
        enabled: false,
      ),
      Entitlement(
        flag: EntitlementFlag.cloudSync,
        enabled: false,
      ),
    ],
  );

  static const Plan pro = Plan(
    id: 'pro',
    displayName: 'Pro',
    clientLimit: null,
    trialDays: 0,
    entitlements: [
      Entitlement(
        flag: EntitlementFlag.unlimitedClients,
        enabled: true,
      ),
      Entitlement(
        flag: EntitlementFlag.pdfExport,
        enabled: true,
      ),
      Entitlement(
        flag: EntitlementFlag.teamMembers,
        enabled: true,
      ),
      Entitlement(
        flag: EntitlementFlag.cloudSync,
        enabled: true,
      ),
    ],
  );

  static const List<Plan> catalog = [
    free,
    pro,
  ];

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id']?.toString() ?? '',
      displayName: json['displayName']?.toString() ??
          json['display_name']?.toString() ??
          json['name']?.toString() ??
          '',
      entitlements: ((json['entitlements'] ?? const []) as List)
          .map((item) => Entitlement.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      clientLimit: json['clientLimit'] == null && json['client_limit'] == null
          ? null
          : ((json['clientLimit'] ?? json['client_limit']) as num?)?.toInt(),
      trialDays: ((json['trialDays'] ?? json['trial_days']) as num?)?.toInt() ??
          0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'clientLimit': clientLimit,
        'trialDays': trialDays,
        'entitlements': entitlements.map((item) => item.toJson()).toList(),
      };

  static List<Plan> catalogFromJsonList(List<dynamic> raw) {
    if (raw.isEmpty) {
      return catalog;
    }
    return raw
        .map((item) => Plan.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  factory Plan.fromId(String id, {List<Plan>? catalogOverride}) {
    for (final plan in catalogOverride ?? catalog) {
      if (plan.id == id) {
        return plan;
      }
    }
    return free;
  }

  bool hasEntitlement(EntitlementFlag flag) {
    for (final entitlement in entitlements) {
      if (entitlement.flag == flag) {
        return entitlement.enabled;
      }
    }
    return false;
  }
}
