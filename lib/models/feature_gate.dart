export 'entitlement.dart';

import 'entitlement.dart';
import 'plan.dart';
import 'subscription.dart';

class FeatureGate {
  static List<Entitlement> _resolvedEntitlements(Subscription subscription) {
    if (subscription.entitlements.isNotEmpty) {
      return subscription.entitlements;
    }
    return subscription.plan.entitlements;
  }

  static bool isEnabled(
    Subscription subscription,
    EntitlementFlag flag,
  ) {
    if (!subscription.hasAccess) {
      return false;
    }
    for (final entitlement in _resolvedEntitlements(subscription)) {
      if (entitlement.flag == flag) {
        return entitlement.enabled;
      }
    }
    return subscription.plan.hasEntitlement(flag);
  }

  static bool canAddClient(
    Subscription subscription,
    int currentClientCount,
  ) {
    if (isEnabled(subscription, EntitlementFlag.unlimitedClients)) {
      return true;
    }
    final limit = subscription.hasAccess
        ? subscription.plan.clientLimit
        : Plan.free.clientLimit;
    if (limit == null) {
      return true;
    }
    return currentClientCount < limit;
  }

  static String blockedMessage(
    Subscription subscription,
    EntitlementFlag flag,
  ) {
    if (subscription.isPastDue) {
      return 'Abonnement en attente de paiement. Mettez à jour votre abonnement pour retrouver l’accès.';
    }
    if (subscription.isExpired) {
      return subscription.canStartTrial
          ? 'Votre abonnement a expiré. Vous pouvez activer un essai gratuit ou passer à Pro.'
          : 'Votre abonnement a expiré. Passez à Pro pour retrouver l’accès.';
    }
    switch (flag) {
      case EntitlementFlag.unlimitedClients:
        final limit = subscription.plan.clientLimit;
        if (limit == null) {
          return 'Fonction non disponible avec le plan actuel.';
        }
        return 'Plan Pro requis pour dépasser $limit clients.';
      case EntitlementFlag.pdfExport:
        return 'Export PDF réservé au plan Pro.';
      case EntitlementFlag.teamMembers:
        return 'Gestion d’équipe réservée au plan Pro.';
      case EntitlementFlag.cloudSync:
        return 'Synchronisation cloud réservée au plan Pro.';
    }
  }
}
