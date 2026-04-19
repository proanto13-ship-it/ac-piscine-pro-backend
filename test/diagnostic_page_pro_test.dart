import 'package:ac_piscine_pro/diagnostic_page_pro.dart';
import 'package:ac_piscine_pro/models/company_profile.dart';
import 'package:ac_piscine_pro/models/pricing_settings.dart';
import 'package:ac_piscine_pro/models/subscription.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpDiagnosticPage(
    WidgetTester tester, {
    required double width,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosticPagePro(
          clientName: 'Client Démo',
          dateLabel: '19/04/2026',
          ph: 7.2,
          chlore: 1.8,
          tac: 110,
          th: 180,
          stabilisant: 35,
          temperature: 26,
          lsi: 0.0,
          stabilityScore: 8,
          observation: 'RAS',
          volumeM3: 50,
          sel: 4200,
          treatmentType: 'chlore',
          pricingSettings:
              PricingSettings.defaults().copyWith(showBudgetEstimates: true),
          companyProfile: CompanyProfile.defaults(),
          subscription: Subscription.defaults(),
          existingDocuments: const [],
          teamMembers: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollToText(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders cleanly on iPhone 375 width', (tester) async {
    await pumpDiagnosticPage(tester, width: 375);

    expect(find.text('Diagnostic'), findsOneWidget);
    await scrollToText(tester, 'Rapport PDF');
    expect(find.text('Rapport PDF'), findsOneWidget);
    expect(find.text('Bon d’intervention'), findsOneWidget);
    await scrollToText(tester, 'Synthèse du diagnostic');
    expect(find.text('Synthèse du diagnostic'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders cleanly on iPhone 390 width', (tester) async {
    await pumpDiagnosticPage(tester, width: 390);

    expect(find.text('Diagnostic'), findsOneWidget);
    await scrollToText(tester, 'Rapport PDF');
    expect(find.text('Rapport PDF'), findsOneWidget);
    expect(find.text('Bon d’intervention'), findsOneWidget);
    await scrollToText(tester, 'Synthèse du diagnostic');
    expect(find.text('Synthèse du diagnostic'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
