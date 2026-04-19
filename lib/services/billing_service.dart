import 'dart:convert';
import 'dart:io';

import '../models/auth_session.dart';
import '../models/billing_result.dart';
import '../models/billing_snapshot.dart';
import '../models/subscription.dart';
import 'billing_provider.dart';
import 'dev_billing_provider.dart';
import 'auth_service.dart';

typedef BillingTransport = Future<Map<String, dynamic>> Function({
  required String endpoint,
  required String token,
});

typedef BillingMutationTransport = Future<Map<String, dynamic>> Function({
  required String method,
  required String endpoint,
  required String token,
  Map<String, dynamic>? payload,
});

class BillingService {
  static BillingProvider _provider = const DevBillingProvider();

  static BillingProvider get provider => _provider;

  static void configureProvider(BillingProvider provider) {
    _provider = provider;
  }

  static Future<BillingSnapshot?> fetchSnapshot({
    AuthSession? session,
    BillingTransport transport = _defaultTransport,
  }) async {
    final resolvedSession = session ?? AuthService.currentSession;
    if (resolvedSession == null || !resolvedSession.isValid) {
      return null;
    }

    final payload = await transport(
      endpoint: _billingEndpoint(resolvedSession.endpoint),
      token: resolvedSession.token,
    );
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      return BillingSnapshot.fromJson(data);
    }
    if (data is Map) {
      return BillingSnapshot.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  static Future<BillingResult> beginUpgradeCheckout({
    String planId = 'pro',
    Subscription? subscription,
    BillingProvider? provider,
    AuthSession? session,
    BillingMutationTransport mutationTransport = _defaultMutationTransport,
  }) async {
    final resolvedProvider = provider ?? _provider;
    final checkoutSession = await resolvedProvider.createCheckoutSession(
      planId: planId,
      subscription: subscription ?? Subscription.defaults(),
    );
    final result =
        await resolvedProvider.startCheckout(session: checkoutSession);
    return _reconcileIfNeeded(
      result,
      session: session ?? AuthService.currentSession,
      transport: mutationTransport,
    );
  }

  static Future<BillingResult> restorePurchases({
    String planId = 'pro',
    Subscription? subscription,
    BillingProvider? provider,
    AuthSession? session,
    BillingMutationTransport mutationTransport = _defaultMutationTransport,
  }) async {
    final resolvedProvider = provider ?? _provider;
    final result = await resolvedProvider.restorePurchases(
      planId: planId,
      subscription: subscription ?? Subscription.defaults(),
    );
    return _reconcileIfNeeded(
      result,
      session: session ?? AuthService.currentSession,
      transport: mutationTransport,
    );
  }

  static Future<BillingSnapshot> startTrial({
    String planId = 'pro',
    AuthSession? session,
    BillingMutationTransport mutationTransport = _defaultMutationTransport,
  }) async {
    final resolvedSession = session ?? AuthService.currentSession;
    if (resolvedSession == null || !resolvedSession.isValid) {
      throw const BillingException(
        'Une session backend valide est requise pour demarrer l essai gratuit.',
      );
    }
    final payload = await mutationTransport(
      method: 'POST',
      endpoint: _billingTrialEndpoint(resolvedSession.endpoint),
      token: resolvedSession.token,
      payload: {
        'plan_id': planId,
      },
    );
    final data = payload['data'];
    final snapshotPayload = data is Map<String, dynamic>
        ? data['snapshot']
        : data is Map
            ? data['snapshot']
            : null;
    if (snapshotPayload is Map<String, dynamic>) {
      return BillingSnapshot.fromJson(snapshotPayload);
    }
    if (snapshotPayload is Map) {
      return BillingSnapshot.fromJson(Map<String, dynamic>.from(snapshotPayload));
    }
    throw const BillingException('Snapshot billing trial invalide.');
  }

  static String _billingEndpoint(String endpoint) {
    final uri = Uri.parse(endpoint.trim());
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    final normalized = segments.contains('v2')
        ? segments.takeWhile((segment) => segment != 'v2').toList()
        : segments.toList();
    return uri.replace(
      pathSegments: [
        ...normalized.where((segment) => segment.isNotEmpty),
        'v2',
        'billing',
        'entitlements',
      ],
      queryParameters: null,
      fragment: null,
    ).toString();
  }

  static String _billingReconcileEndpoint(String endpoint) {
    final uri = Uri.parse(endpoint.trim());
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    final normalized = segments.contains('v2')
        ? segments.takeWhile((segment) => segment != 'v2').toList()
        : segments.toList();
    return uri.replace(
      pathSegments: [
        ...normalized.where((segment) => segment.isNotEmpty),
        'v2',
        'billing',
        'mobile',
        'reconcile',
      ],
      queryParameters: null,
      fragment: null,
    ).toString();
  }

  static String _billingTrialEndpoint(String endpoint) {
    final uri = Uri.parse(endpoint.trim());
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    final normalized = segments.contains('v2')
        ? segments.takeWhile((segment) => segment != 'v2').toList()
        : segments.toList();
    return uri.replace(
      pathSegments: [
        ...normalized.where((segment) => segment.isNotEmpty),
        'v2',
        'billing',
        'trial',
        'start',
      ],
      queryParameters: null,
      fragment: null,
    ).toString();
  }

  static Future<Map<String, dynamic>> _defaultTransport({
    required String endpoint,
    required String token,
  }) async {
    return _sendRequest(
      method: 'GET',
      endpoint: endpoint,
      token: token,
    );
  }

  static Future<Map<String, dynamic>> _defaultMutationTransport({
    required String method,
    required String endpoint,
    required String token,
    Map<String, dynamic>? payload,
  }) async {
    return _sendRequest(
      method: method,
      endpoint: endpoint,
      token: token,
      payload: payload,
    );
  }

  static Future<Map<String, dynamic>> _sendRequest({
    required String method,
    required String endpoint,
    required String token,
    Map<String, dynamic>? payload,
  }) async {
    final uri = Uri.parse(endpoint);
    final client = HttpClient();
    late final HttpClientRequest request;
    switch (method.toUpperCase()) {
      case 'POST':
        request = await client.postUrl(uri);
        break;
      case 'GET':
        request = await client.getUrl(uri);
        break;
      default:
        client.close();
        throw BillingException('Méthode HTTP billing non supportée: $method');
    }
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
    if (payload != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));
    }
    final response = await request.close();
    final raw = await utf8.decoder.bind(response).join();
    client.close();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BillingException(
        'Impossible de recuperer les entitlements backend '
        '(HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw const BillingException('Payload billing V2 invalide.');
  }

  static Future<BillingResult> _reconcileIfNeeded(
    BillingResult result, {
    required AuthSession? session,
    required BillingMutationTransport transport,
  }) async {
    if (!result.shouldRefreshEntitlements) {
      return result;
    }
    final resolvedSession = session;
    if (resolvedSession == null || !resolvedSession.isValid) {
      return result.copyWith(
        status: BillingResultStatus.failed,
        message:
            'Achat detecte mais aucune session backend valide n est disponible pour synchroniser l abonnement.',
        shouldRefreshEntitlements: false,
      );
    }

    final purchases = _extractPurchases(result.metadata);
    if (purchases.isEmpty) {
      return result.copyWith(
        status: BillingResultStatus.failed,
        message:
            'Achat detecte mais aucune preuve d achat exploitable n a ete recue.',
        shouldRefreshEntitlements: false,
      );
    }

    final payload = await transport(
      method: 'POST',
      endpoint: _billingReconcileEndpoint(resolvedSession.endpoint),
      token: resolvedSession.token,
      payload: {
        'provider': result.session?.providerKey ??
            purchases.first['provider']?.toString() ??
            '',
        'plan_id': result.session?.planId ?? '',
        'purchases': purchases,
      },
    );

    final data = payload['data'];
    final snapshotPayload = data is Map<String, dynamic>
        ? data['snapshot']
        : data is Map
            ? data['snapshot']
            : null;

    BillingSnapshot? snapshot;
    if (snapshotPayload is Map<String, dynamic>) {
      snapshot = BillingSnapshot.fromJson(snapshotPayload);
    } else if (snapshotPayload is Map) {
      snapshot = BillingSnapshot.fromJson(
        Map<String, dynamic>.from(snapshotPayload),
      );
    }

    return result.copyWith(
      message: snapshot == null
          ? result.message
          : 'Abonnement synchronise avec le backend.',
      metadata: {
        ...result.metadata,
        if (snapshot != null)
          'snapshot': {
            'plans': snapshot.plans.map((item) => item.toJson()).toList(),
            'subscription': snapshot.subscription.toJson(),
          },
      },
    );
  }

  static List<Map<String, dynamic>> _extractPurchases(
    Map<String, dynamic> metadata,
  ) {
    final rawPurchases = metadata['purchases'];
    if (rawPurchases is List) {
      return rawPurchases
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }
}

class BillingException implements Exception {
  final String message;

  const BillingException(this.message);

  @override
  String toString() => message;
}
