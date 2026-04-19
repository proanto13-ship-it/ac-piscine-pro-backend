enum BillingCheckoutMode {
  web,
  native,
  manual;

  static BillingCheckoutMode fromJson(dynamic raw) {
    switch (raw?.toString()) {
      case 'web':
        return BillingCheckoutMode.web;
      case 'native':
        return BillingCheckoutMode.native;
      case 'manual':
      default:
        return BillingCheckoutMode.manual;
    }
  }
}

class BillingCheckoutSession {
  final String sessionId;
  final String providerKey;
  final String planId;
  final BillingCheckoutMode mode;
  final String checkoutUrl;
  final String customerPortalUrl;
  final String message;
  final Map<String, dynamic> metadata;

  const BillingCheckoutSession({
    required this.sessionId,
    required this.providerKey,
    required this.planId,
    required this.mode,
    this.checkoutUrl = '',
    this.customerPortalUrl = '',
    this.message = '',
    this.metadata = const {},
  });

  factory BillingCheckoutSession.fromJson(Map<String, dynamic> json) {
    return BillingCheckoutSession(
      sessionId:
          json['sessionId']?.toString() ?? json['session_id']?.toString() ?? '',
      providerKey: json['providerKey']?.toString() ??
          json['provider_key']?.toString() ??
          '',
      planId: json['planId']?.toString() ?? json['plan_id']?.toString() ?? '',
      mode: BillingCheckoutMode.fromJson(json['mode']),
      checkoutUrl: json['checkoutUrl']?.toString() ??
          json['checkout_url']?.toString() ??
          '',
      customerPortalUrl: json['customerPortalUrl']?.toString() ??
          json['customer_portal_url']?.toString() ??
          '',
      message: json['message']?.toString() ?? '',
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'])
          : json['metadata'] is Map
              ? Map<String, dynamic>.from(json['metadata'] as Map)
              : const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'providerKey': providerKey,
        'planId': planId,
        'mode': mode.name,
        'checkoutUrl': checkoutUrl,
        'customerPortalUrl': customerPortalUrl,
        'message': message,
        'metadata': metadata,
      };
}
