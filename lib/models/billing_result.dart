import 'billing_checkout_session.dart';

enum BillingResultStatus {
  opened,
  pendingManualAction,
  completed,
  cancelled,
  failed;

  static BillingResultStatus fromJson(dynamic raw) {
    switch (raw?.toString()) {
      case 'opened':
        return BillingResultStatus.opened;
      case 'completed':
        return BillingResultStatus.completed;
      case 'cancelled':
        return BillingResultStatus.cancelled;
      case 'failed':
        return BillingResultStatus.failed;
      case 'pendingManualAction':
      default:
        return BillingResultStatus.pendingManualAction;
    }
  }
}

class BillingResult {
  final BillingResultStatus status;
  final String message;
  final BillingCheckoutSession? session;
  final bool shouldRefreshEntitlements;
  final Map<String, dynamic> metadata;

  const BillingResult({
    required this.status,
    required this.message,
    this.session,
    this.shouldRefreshEntitlements = false,
    this.metadata = const {},
  });

  factory BillingResult.fromJson(Map<String, dynamic> json) {
    return BillingResult(
      status: BillingResultStatus.fromJson(json['status']),
      message: json['message']?.toString() ?? '',
      session: json['session'] is Map<String, dynamic>
          ? BillingCheckoutSession.fromJson(
              Map<String, dynamic>.from(json['session']),
            )
          : json['session'] is Map
              ? BillingCheckoutSession.fromJson(
                  Map<String, dynamic>.from(json['session'] as Map),
                )
              : null,
      shouldRefreshEntitlements: json['shouldRefreshEntitlements'] == true ||
          json['should_refresh_entitlements'] == true,
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'])
          : json['metadata'] is Map
              ? Map<String, dynamic>.from(json['metadata'] as Map)
              : const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'message': message,
        'shouldRefreshEntitlements': shouldRefreshEntitlements,
        'metadata': metadata,
        if (session != null) 'session': session!.toJson(),
      };

  BillingResult copyWith({
    BillingResultStatus? status,
    String? message,
    BillingCheckoutSession? session,
    bool? shouldRefreshEntitlements,
    Map<String, dynamic>? metadata,
  }) {
    return BillingResult(
      status: status ?? this.status,
      message: message ?? this.message,
      session: session ?? this.session,
      shouldRefreshEntitlements:
          shouldRefreshEntitlements ?? this.shouldRefreshEntitlements,
      metadata: metadata ?? this.metadata,
    );
  }
}
