import 'plan.dart';
import 'entitlement.dart';

enum SubscriptionStatus {
  trial,
  active,
  pastDue,
  canceled,
  expired;

  static SubscriptionStatus fromJson(dynamic raw) {
    switch (raw?.toString()) {
      case 'trial':
        return SubscriptionStatus.trial;
      case 'past_due':
      case 'pastDue':
        return SubscriptionStatus.pastDue;
      case 'canceled':
        return SubscriptionStatus.canceled;
      case 'expired':
      case 'inactive':
        return SubscriptionStatus.expired;
      case 'active':
      default:
        return SubscriptionStatus.active;
    }
  }
}

class Subscription {
  final String planId;
  final SubscriptionStatus status;
  final String startedAtIso;
  final String endedAtIso;
  final String updatedAtIso;
  final bool trialUsed;
  final List<Entitlement> entitlements;
  final Plan? resolvedPlan;

  const Subscription({
    required this.planId,
    required this.status,
    required this.startedAtIso,
    required this.endedAtIso,
    required this.updatedAtIso,
    this.trialUsed = false,
    this.entitlements = const [],
    this.resolvedPlan,
  });

  factory Subscription.defaults() {
    return const Subscription(
      planId: 'free',
      status: SubscriptionStatus.active,
      startedAtIso: '',
      endedAtIso: '',
      updatedAtIso: '',
      trialUsed: false,
    );
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final defaults = Subscription.defaults();
    return Subscription(
      planId: json['planId']?.toString() ??
          json['plan_id']?.toString() ??
          defaults.planId,
      status: SubscriptionStatus.fromJson(json['status']),
      startedAtIso: json['startedAtIso']?.toString() ??
          json['started_at_iso']?.toString() ??
          defaults.startedAtIso,
      endedAtIso: json['endedAtIso']?.toString() ??
          json['ended_at_iso']?.toString() ??
          defaults.endedAtIso,
      updatedAtIso: json['updatedAtIso']?.toString() ??
          json['updated_at_iso']?.toString() ??
          defaults.updatedAtIso,
      trialUsed: json['trialUsed'] == true || json['trial_used'] == true,
      entitlements: ((json['entitlements'] ?? const []) as List)
          .map((item) => Entitlement.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      resolvedPlan: json['plan'] is Map<String, dynamic>
          ? Plan.fromJson(Map<String, dynamic>.from(json['plan']))
          : json['plan'] is Map
              ? Plan.fromJson(Map<String, dynamic>.from(json['plan'] as Map))
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'planId': planId,
        'status': status.name,
        'startedAtIso': startedAtIso,
        'endedAtIso': endedAtIso,
        'updatedAtIso': updatedAtIso,
        'trialUsed': trialUsed,
        'entitlements': entitlements.map((item) => item.toJson()).toList(),
        if (resolvedPlan != null) 'plan': resolvedPlan!.toJson(),
      };

  Subscription copyWith({
    String? planId,
    SubscriptionStatus? status,
    String? startedAtIso,
    String? endedAtIso,
    String? updatedAtIso,
    bool? trialUsed,
    List<Entitlement>? entitlements,
    Plan? resolvedPlan,
  }) {
    final nextPlanId = planId ?? this.planId;
    final didChangePlan = nextPlanId != this.planId;
    return Subscription(
      planId: nextPlanId,
      status: status ?? this.status,
      startedAtIso: startedAtIso ?? this.startedAtIso,
      endedAtIso: endedAtIso ?? this.endedAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      trialUsed: trialUsed ?? this.trialUsed,
      entitlements:
          entitlements ?? (didChangePlan ? const [] : this.entitlements),
      resolvedPlan: resolvedPlan ?? (didChangePlan ? null : this.resolvedPlan),
    );
  }

  Plan get plan => resolvedPlan ?? Plan.fromId(planId);

  bool get isTrial => status == SubscriptionStatus.trial;

  bool get isActive => status == SubscriptionStatus.active;

  bool get isPastDue => status == SubscriptionStatus.pastDue;

  bool get isCanceled => status == SubscriptionStatus.canceled;

  bool get isExpired => status == SubscriptionStatus.expired;

  bool get hasAccess => isTrial || isActive || isCanceled;

  bool get hasEndDate => endedAtIso.trim().isNotEmpty;

  DateTime? get startedAtDate => _parseIso(startedAtIso);

  DateTime? get endedAtDate => _parseIso(endedAtIso);

  bool get trialEndsSoon {
    if (!isTrial) return false;
    final end = endedAtDate;
    if (end == null) return false;
    final now = DateTime.now().toUtc();
    final remaining = end.difference(now);
    return !remaining.isNegative && remaining.inDays <= 2;
  }

  bool get canStartTrial {
    final trialPlan = planId == 'pro' ? plan : Plan.pro;
    return !trialUsed && trialPlan.trialDays > 0 && !hasAccess;
  }
}

DateTime? _parseIso(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  try {
    return DateTime.parse(trimmed).toUtc();
  } catch (_) {
    return null;
  }
}
