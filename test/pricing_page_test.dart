import 'package:ac_piscine_pro/models/auth_session.dart';
import 'package:ac_piscine_pro/models/entitlement.dart';
import 'package:ac_piscine_pro/models/subscription.dart';
import 'package:ac_piscine_pro/pages/pricing_page.dart';
import 'package:ac_piscine_pro/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AuthService.sessionNotifier.value = null;
  });

  testWidgets('pricing page shows non connected state by default',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PricingPage(
          subscription: Subscription.defaults(),
          availablePlans: const [],
          highlightedFlag: EntitlementFlag.pdfExport,
        ),
      ),
    );

    expect(find.text('Plan actuel : Non connecté'), findsOneWidget);
    expect(find.text('Gratuit'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Export PDF'), findsWidgets);
    expect(find.text('Synchronisation cloud'), findsWidgets);
    expect(find.text('Clients illimités'), findsWidgets);
    expect(find.text('Membres d’équipe'), findsWidgets);
    expect(
      find.text('Connectez-vous pour vérifier votre abonnement.'),
      findsOneWidget,
    );
    expect(find.text('Passer à Pro'), findsNothing);
  });

  testWidgets('pricing page shows upgrade copy for connected free account',
      (tester) async {
    AuthService.sessionNotifier.value = const AuthSession(
      endpoint: 'https://sync.example.com',
      token: 'token',
      userId: 'user_1',
      organizationId: 'org_free',
      email: 'demo-free@hydrazur.test',
      fullName: 'Demo Free',
      role: 'admin',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PricingPage(
          subscription: Subscription.defaults(),
          availablePlans: const [],
        ),
      ),
    );

    expect(find.text('Plan actuel : Gratuit'), findsOneWidget);
    expect(
      find.text(
        'Certaines fonctions avancées sont disponibles avec l’offre Pro.',
      ),
      findsOneWidget,
    );
    expect(find.text('Voir les offres'), findsOneWidget);
  });

  testWidgets('pricing page hides upgrade CTA when Pro is already active',
      (tester) async {
    AuthService.sessionNotifier.value = const AuthSession(
      endpoint: 'https://sync.example.com',
      token: 'token',
      userId: 'user_1',
      organizationId: 'org_pro',
      email: 'demo-pro@hydrazur.test',
      fullName: 'Demo Pro',
      role: 'admin',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PricingPage(
          subscription: Subscription.defaults().copyWith(
            planId: 'pro',
            status: SubscriptionStatus.active,
          ),
          availablePlans: const [],
        ),
      ),
    );

    expect(find.text('Plan actuel : Pro'), findsOneWidget);
    expect(find.textContaining('Votre offre Pro est active.'), findsOneWidget);
    expect(find.text('Demander l’activation Pro'), findsNothing);
    expect(find.text('Passer à Pro'), findsNothing);
  });
}
