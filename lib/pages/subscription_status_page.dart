import 'package:flutter/material.dart';

import '../main.dart';
import '../models/plan.dart';
import '../services/auth_service.dart';
import 'pricing_page.dart';
import 'support_page.dart';

class SubscriptionStatusPage extends StatefulWidget {
  const SubscriptionStatusPage({super.key});

  @override
  State<SubscriptionStatusPage> createState() => _SubscriptionStatusPageState();
}

class _SubscriptionStatusPageState extends State<SubscriptionStatusPage> {
  bool _refreshing = false;

  Future<void> _refreshFromBackend() async {
    if (!AuthService.isAuthenticated) {
      return;
    }
    setState(() => _refreshing = true);
    try {
      final refreshed = await refreshBillingFromV2();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            refreshed
                ? 'Abonnement mis à jour.'
                : 'Aucune information d’abonnement n’est disponible pour le moment.',
          ),
        ),
      );
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Impossible d’actualiser l’abonnement pour le moment.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = AppStore.subscription;
    final hasProAccess = subscription.planId == 'pro' && subscription.hasAccess;
    final proPlan =
        Plan.fromId('pro', catalogOverride: AppStore.availablePlans);
    final lifecycleMessage =
        subscriptionLifecycleMessage(subscription, proPlan);
    final planLabel = planDisplayLabel(subscription.plan);
    final offerMessage = subscriptionUserOfferMessage(subscription);

    return Scaffold(
      appBar: AppBar(
        title: const Text('État de l’abonnement'),
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
                  'Plan actuel : ${AuthService.isAuthenticated ? planLabel : 'Non connecté'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AuthService.isAuthenticated
                      ? offerMessage
                      : 'Connectez-vous pour vérifier votre abonnement.',
                  style: const TextStyle(
                    color: Color(0xFF475467),
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AuthService.isAuthenticated
                      ? lifecycleMessage
                      : 'La synchronisation cloud et les fonctions Pro nécessitent une connexion.',
                  style: const TextStyle(
                    color: Color(0xFF0F6E7C),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
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
                  AuthService.isAuthenticated && hasProAccess
                      ? 'Offre Pro active'
                      : 'Activation Pro pendant la bêta',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AuthService.isAuthenticated && hasProAccess
                      ? 'Votre offre Pro est active. Les fonctionnalités Pro sont disponibles sur ce compte.'
                      : 'Pendant la bêta, l’offre Pro est activée manuellement par notre équipe. Contactez-nous avec l’email de votre compte pour activer l’accès Pro.',
                  style: TextStyle(
                    color: hasProAccess
                        ? const Color(0xFF027A48)
                        : const Color(0xFF6941C6),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (AuthService.isAuthenticated)
            FilledButton.icon(
              onPressed: _refreshing ? null : _refreshFromBackend,
              icon: _refreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync),
              label: Text(
                _refreshing ? 'Actualisation…' : 'Actualiser mon abonnement',
              ),
            ),
          if (AuthService.isAuthenticated) const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PricingPage(
                    subscription: AppStore.subscription,
                    availablePlans: AppStore.availablePlans,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.workspace_premium_outlined),
            label: const Text('Voir les offres'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SupportPage(),
                ),
              );
            },
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Ouvrir le support'),
          ),
        ],
      ),
    );
  }
}
