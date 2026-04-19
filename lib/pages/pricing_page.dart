import 'package:flutter/material.dart';

import '../models/billing_result.dart';
import '../models/billing_snapshot.dart';
import '../models/entitlement.dart';
import '../models/plan.dart';
import '../models/subscription.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import 'support_page.dart';

class PricingPage extends StatefulWidget {
  final Subscription subscription;
  final List<Plan> availablePlans;
  final EntitlementFlag? highlightedFlag;
  final Future<void> Function(BillingSnapshot snapshot)? onSnapshotChanged;

  const PricingPage({
    super.key,
    required this.subscription,
    required this.availablePlans,
    this.highlightedFlag,
    this.onSnapshotChanged,
  });

  @override
  State<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> {
  late Subscription _subscription;
  late List<Plan> _availablePlans;
  bool _purchasing = false;
  bool _restoring = false;
  bool _startingTrial = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _subscription = widget.subscription;
    _availablePlans =
        _normalizedPlans(widget.availablePlans, widget.subscription);
  }

  @override
  Widget build(BuildContext context) {
    final plans = _normalizedPlans(_availablePlans, _subscription);
    final freePlan = _planById('free', plans, Plan.free);
    final proPlan = _planById('pro', plans, Plan.pro);
    final isConnected = AuthService.isAuthenticated;
    final currentPlan =
        _planById(_subscription.planId, plans, _subscription.plan);
    final hasProAccess =
        isConnected && _subscription.planId == 'pro' && _subscription.hasAccess;
    final canStartTrial = proPlan.trialDays > 0 &&
        !_subscription.trialUsed &&
        !(_subscription.planId == 'pro' &&
            (_subscription.isTrial ||
                _subscription.isActive ||
                _subscription.isCanceled));
    final lifecycleMessage = subscriptionLifecycleMessage(
      _subscription,
      proPlan,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voir les offres'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD0D5DD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan actuel : ${isConnected ? _planLabel(currentPlan) : 'Non connecté'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  !isConnected
                      ? 'Connectez-vous pour vérifier votre abonnement.'
                      : currentPlan.id == 'pro'
                          ? 'Votre offre Pro est active.'
                          : 'Certaines fonctions avancées sont disponibles avec l’offre Pro.',
                  style: const TextStyle(
                    color: Color(0xFF475467),
                    height: 1.4,
                  ),
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage!,
                    style: const TextStyle(
                      color: Color(0xFF0F6E7C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (lifecycleMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _lifecycleTone(_subscription).withValues(
                        alpha: 0.10,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _lifecycleTone(_subscription).withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ),
                    child: Text(
                      lifecycleMessage,
                      style: TextStyle(
                        color: _lifecycleTone(_subscription),
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PlanCard(
            title: _planLabel(freePlan),
            accentColor: const Color(0xFF98A2B3),
            badgeLabel: currentPlan.id == freePlan.id ? 'Actuel' : 'Inclus',
            items: [
              _PlanFeatureLine(
                title: featureTitle(EntitlementFlag.unlimitedClients),
                value:
                    'Jusqu’à ${freePlan.clientLimit ?? Plan.free.clientLimit ?? 10} clients',
                enabled: freePlan.hasEntitlement(
                  EntitlementFlag.unlimitedClients,
                ),
              ),
              _PlanFeatureLine(
                title: featureTitle(EntitlementFlag.pdfExport),
                value: 'Non inclus',
                enabled: freePlan.hasEntitlement(EntitlementFlag.pdfExport),
              ),
              _PlanFeatureLine(
                title: featureTitle(EntitlementFlag.cloudSync),
                value: 'Non inclus',
                enabled: freePlan.hasEntitlement(EntitlementFlag.cloudSync),
              ),
              _PlanFeatureLine(
                title: featureTitle(EntitlementFlag.teamMembers),
                value: 'Non inclus',
                enabled: freePlan.hasEntitlement(EntitlementFlag.teamMembers),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PlanCard(
            title: _planLabel(proPlan),
            accentColor: const Color(0xFF0F6E7C),
            badgeLabel: currentPlan.id == proPlan.id ? 'Actuel' : 'Recommandé',
            items: [
              _PlanFeatureLine(
                title: featureTitle(EntitlementFlag.unlimitedClients),
                value: 'Clients illimités',
                enabled: proPlan.hasEntitlement(
                  EntitlementFlag.unlimitedClients,
                ),
              ),
              _PlanFeatureLine(
                title: featureTitle(EntitlementFlag.pdfExport),
                value: 'Création et partage de PDF',
                enabled: proPlan.hasEntitlement(EntitlementFlag.pdfExport),
              ),
              _PlanFeatureLine(
                title: featureTitle(EntitlementFlag.cloudSync),
                value: 'Synchronisation cloud',
                enabled: proPlan.hasEntitlement(EntitlementFlag.cloudSync),
              ),
              _PlanFeatureLine(
                title: featureTitle(EntitlementFlag.teamMembers),
                value: 'Gestion d’équipe',
                enabled: proPlan.hasEntitlement(EntitlementFlag.teamMembers),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasProAccess
                  ? const Color(0xFFECFDF3)
                  : const Color(0xFFFFFAEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasProAccess
                    ? const Color(0xFFABEFC6)
                    : const Color(0xFFFEC84B),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasProAccess ? 'Offre Pro active' : 'Passer à Pro',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasProAccess
                      ? 'Votre offre Pro est active. Les fonctionnalités Pro sont disponibles sur ce compte.'
                      : (BillingService.provider.providerKey == 'dev_manual'
                          ? 'Pendant la bêta, l’offre Pro est activée manuellement par notre équipe. Contactez-nous avec l’email de votre compte pour activer l’accès Pro.'
                          : 'L’offre Pro peut être achetée ou restaurée directement depuis la boutique native.'),
                  style: TextStyle(
                    color: hasProAccess
                        ? const Color(0xFF027A48)
                        : const Color(0xFF6941C6),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!hasProAccess && proPlan.trialDays > 0) ...[
            OutlinedButton.icon(
              onPressed: canStartTrial &&
                      !_startingTrial &&
                      !_purchasing &&
                      !_restoring
                  ? () => _startTrial(context, proPlan)
                  : null,
              icon: _startingTrial
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.hourglass_bottom_outlined),
              label: Text(
                canStartTrial
                    ? (_startingTrial
                        ? 'Activation de l’essai…'
                        : 'Essayer gratuitement ${proPlan.trialDays} jours')
                    : (_subscription.trialUsed
                        ? 'Essai déjà utilisé'
                        : 'Essai gratuit indisponible'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (isConnected && !hasProAccess)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _restoring || _purchasing || _startingTrial
                        ? null
                        : () => _restorePurchases(context),
                    icon: _restoring
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.restore),
                    label: Text(_restoring ? 'Restauration…' : 'Restaurer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _startingTrial || _purchasing || _restoring
                        ? null
                        : () => _startUpgradeFlow(context),
                    icon: _purchasing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.workspace_premium_outlined),
                    label: Text(
                      BillingService.provider.providerKey == 'dev_manual'
                          ? (_purchasing
                              ? 'Demande…'
                              : 'Demander l’activation Pro')
                          : (_purchasing ? 'Achat…' : 'Passer à Pro'),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _startUpgradeFlow(BuildContext context) async {
    setState(() {
      _purchasing = true;
      _statusMessage = null;
    });
    final result = await BillingService.beginUpgradeCheckout(
      subscription: _subscription,
      planId: 'pro',
    );
    if (!mounted) {
      return;
    }
    await _handleBillingResult(result);
    if (mounted) {
      setState(() => _purchasing = false);
    }
  }

  Future<void> _restorePurchases(BuildContext context) async {
    setState(() {
      _restoring = true;
      _statusMessage = null;
    });
    final result = await BillingService.restorePurchases(
      subscription: _subscription,
      planId: 'pro',
    );
    if (!mounted) {
      return;
    }
    await _handleBillingResult(result);
    if (mounted) {
      setState(() => _restoring = false);
    }
  }

  Future<void> _startTrial(BuildContext context, Plan proPlan) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _startingTrial = true;
      _statusMessage = null;
    });
    try {
      final snapshot = await BillingService.startTrial(planId: proPlan.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _availablePlans =
            snapshot.plans.isEmpty ? Plan.catalog : snapshot.plans;
        _subscription = snapshot.subscription;
        _statusMessage = subscriptionLifecycleMessage(
          snapshot.subscription,
          _planById('pro', _availablePlans, Plan.pro),
        );
      });
      if (widget.onSnapshotChanged != null) {
        await widget.onSnapshotChanged!(snapshot);
      }
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Essai gratuit activé.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Impossible de démarrer l’essai : $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _startingTrial = false);
      }
    }
  }

  Future<void> _handleBillingResult(BillingResult result) async {
    BillingSnapshot? snapshot;
    try {
      snapshot = await BillingService.fetchSnapshot();
    } catch (_) {
      snapshot = null;
    }

    if (snapshot != null && mounted) {
      setState(() {
        _availablePlans =
            snapshot!.plans.isEmpty ? Plan.catalog : snapshot.plans;
        _subscription = snapshot.subscription;
      });
      if (widget.onSnapshotChanged != null) {
        await widget.onSnapshotChanged!(snapshot);
      }
    }

    if (!mounted) {
      return;
    }

    setState(() => _statusMessage = result.message);
    final messenger = ScaffoldMessenger.of(context);

    switch (result.status) {
      case BillingResultStatus.pendingManualAction:
        final content = result.session?.message.isNotEmpty == true
            ? result.session!.message
            : result.message;
        if (!mounted) {
          return;
        }
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Activation Pro pendant la bêta'),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Plus tard'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SupportPage(),
                    ),
                  );
                },
                child: const Text('Contacter le support'),
              ),
            ],
          ),
        );
        return;
      case BillingResultStatus.opened:
      case BillingResultStatus.completed:
      case BillingResultStatus.cancelled:
      case BillingResultStatus.failed:
        messenger.showSnackBar(
          SnackBar(content: Text(result.message)),
        );
        return;
    }
  }
}

Future<void> showUpgradePaywall(
  BuildContext context, {
  required Subscription subscription,
  required List<Plan> availablePlans,
  required EntitlementFlag flag,
  Future<void> Function(BillingSnapshot snapshot)? onSnapshotChanged,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fonction Pro',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                featureDescription(flag, subscription.plan.clientLimit),
                style: const TextStyle(
                  color: Color(0xFF475467),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD0D5DD)),
                ),
                child: const Text(
                  'Le plan Pro débloque l’export PDF, la synchronisation cloud, la gestion d’équipe et les clients illimités.',
                  style: TextStyle(
                    color: Color(0xFF344054),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Plus tard'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PricingPage(
                              subscription: subscription,
                              availablePlans: availablePlans,
                              highlightedFlag: flag,
                              onSnapshotChanged: onSnapshotChanged,
                            ),
                          ),
                        );
                      },
                      child: const Text('Voir les offres'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

String featureTitle(EntitlementFlag flag) {
  switch (flag) {
    case EntitlementFlag.unlimitedClients:
      return 'Clients illimités';
    case EntitlementFlag.pdfExport:
      return 'Export PDF';
    case EntitlementFlag.teamMembers:
      return 'Membres d’équipe';
    case EntitlementFlag.cloudSync:
      return 'Synchronisation cloud';
  }
}

String featureDescription(EntitlementFlag flag, int? clientLimit) {
  switch (flag) {
    case EntitlementFlag.unlimitedClients:
      return 'L’offre Gratuit est limitée à ${clientLimit ?? 10} clients. L’offre Pro supprime cette limite.';
    case EntitlementFlag.pdfExport:
      return 'L’offre Pro permet de créer et partager vos PDF de diagnostic, d’intervention et de documents financiers.';
    case EntitlementFlag.teamMembers:
      return 'La gestion des membres d’équipe est disponible avec l’offre Pro.';
    case EntitlementFlag.cloudSync:
      return 'L’offre Pro permet de synchroniser vos données dans le cloud.';
  }
}

String subscriptionLifecycleMessage(Subscription subscription, Plan proPlan) {
  if (!AuthService.isAuthenticated) {
    return 'Connectez-vous pour synchroniser vos données et vérifier vos droits Pro.';
  }
  switch (subscription.status) {
    case SubscriptionStatus.trial:
      if (subscription.trialEndsSoon && subscription.endedAtIso.isNotEmpty) {
        return 'Essai presque terminé. Il se termine le ${subscription.endedAtIso.substring(0, 10)}.';
      }
      return subscription.endedAtIso.isNotEmpty
          ? 'Essai en cours jusqu’au ${subscription.endedAtIso.substring(0, 10)}.'
          : 'Essai en cours.';
    case SubscriptionStatus.active:
      if (subscription.planId == 'pro') {
        return 'Abonnement actif.';
      }
      return proPlan.trialDays > 0 && !subscription.trialUsed
          ? 'Passez à Pro quand vous le souhaitez. Un essai gratuit peut aussi être activé.'
          : 'Passez à Pro quand vous le souhaitez.';
    case SubscriptionStatus.pastDue:
      return 'Paiement en attente. Certaines fonctionnalités Pro sont temporairement bloquées.';
    case SubscriptionStatus.canceled:
      return subscription.endedAtIso.isNotEmpty
          ? 'Abonnement annulé. L’accès reste disponible jusqu’au ${subscription.endedAtIso.substring(0, 10)}.'
          : 'Abonnement annulé.';
    case SubscriptionStatus.expired:
      return proPlan.trialDays > 0 && !subscription.trialUsed
          ? 'Abonnement expiré. Un essai gratuit est disponible.'
          : 'Abonnement expiré. Passez à Pro pour réactiver toutes les fonctionnalités.';
  }
}

String _planLabel(Plan plan) {
  switch (plan.id) {
    case 'free':
      return 'Gratuit';
    case 'pro':
      return 'Pro';
    default:
      return plan.displayName;
  }
}

Color _lifecycleTone(Subscription subscription) {
  switch (subscription.status) {
    case SubscriptionStatus.trial:
      return const Color(0xFFB54708);
    case SubscriptionStatus.active:
      return const Color(0xFF027A48);
    case SubscriptionStatus.pastDue:
      return const Color(0xFFB42318);
    case SubscriptionStatus.canceled:
      return const Color(0xFF0F6E7C);
    case SubscriptionStatus.expired:
      return const Color(0xFFB42318);
  }
}

Plan _planById(String id, List<Plan> plans, Plan fallback) {
  for (final plan in plans) {
    if (plan.id == id) {
      return plan;
    }
  }
  return fallback;
}

List<Plan> _normalizedPlans(List<Plan> plans, Subscription subscription) {
  final merged = <Plan>[
    ...plans,
    if (!plans.any((plan) => plan.id == subscription.plan.id))
      subscription.plan,
  ];
  if (!merged.any((plan) => plan.id == 'free')) {
    merged.add(Plan.free);
  }
  if (!merged.any((plan) => plan.id == 'pro')) {
    merged.add(Plan.pro);
  }
  return merged;
}

class _PlanFeatureLine {
  final String title;
  final String value;
  final bool enabled;

  const _PlanFeatureLine({
    required this.title,
    required this.value,
    required this.enabled,
  });
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String badgeLabel;
  final Color accentColor;
  final List<_PlanFeatureLine> items;

  const _PlanCard({
    required this.title,
    required this.badgeLabel,
    required this.accentColor,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.enabled
                      ? Icons.check_circle
                      : Icons.remove_circle_outline,
                  color: item.enabled
                      ? const Color(0xFF027A48)
                      : const Color(0xFF98A2B3),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.value,
                        style: const TextStyle(
                          color: Color(0xFF475467),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item != items.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
