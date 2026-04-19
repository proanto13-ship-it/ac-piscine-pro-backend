import 'package:flutter_test/flutter_test.dart';

import 'package:ac_piscine_pro/models/client.dart';
import 'package:ac_piscine_pro/models/company_profile.dart';
import 'package:ac_piscine_pro/models/financial_document.dart';
import 'package:ac_piscine_pro/models/intervention_record.dart';
import 'package:ac_piscine_pro/models/onboarding_progress.dart';
import 'package:ac_piscine_pro/models/subscription.dart';
import 'package:ac_piscine_pro/models/water_analysis.dart';
import 'package:ac_piscine_pro/models/workspace_settings.dart';
import 'package:ac_piscine_pro/services/onboarding_checklist_service.dart';

void main() {
  test('checklist follows first-value progression and locks PDF on free', () {
    final baseClient = Client(
      id: 'client_1',
      name: 'Villa Azur',
      phone: '0600000000',
      email: 'client@test.dev',
      address: '1 avenue de la Mer',
      volume: 45,
      treatment: 'Chlore',
      bassinType: 'Enterree',
      revetement: 'Liner',
      filtration: 'Sable',
      equipements: 'Volet',
      visitFrequencyDays: 14,
      createdAtIso: '2026-04-17T10:00:00Z',
      updatedAtIso: '2026-04-17T10:00:00Z',
      version: 1,
      deletedAtIso: '',
      notes: '',
      analyses: [
        WaterAnalysis(
          dateIso: '2026-04-17T10:00:00Z',
          ph: 7.2,
          chlore: 1.5,
          tac: 100,
          th: 180,
          stabilisant: 35,
          temperature: 24,
          tds: 0,
          lsi: 0,
          stabilityScore: 8,
          eauSalee: false,
          liner: true,
          observation: '',
          mainOeuvre: 80,
        ),
      ],
      interventions: const [],
      financialDocuments: const [],
    );

    final incompleteProfileState = OnboardingChecklistService.build(
      companyProfile: CompanyProfile.defaults(),
      workspaceSettings: WorkspaceSettings.defaults(),
      clients: const [],
      subscription: Subscription.defaults(),
      progress: OnboardingProgress.defaults(),
    );

    expect(incompleteProfileState.completedCount, 0);
    expect(
      incompleteProfileState.nextIncomplete?.id,
      OnboardingStepId.companyProfile,
    );
    expect(
      incompleteProfileState.items.last.locked,
      isTrue,
    );

    final withClientState = OnboardingChecklistService.build(
      companyProfile: CompanyProfile.defaults().copyWith(
        companyName: 'HydrAzur Pilotage',
        phone: '0400000000',
      ),
      workspaceSettings: WorkspaceSettings.defaults(),
      clients: [baseClient],
      subscription: Subscription.defaults(),
      progress: OnboardingProgress.defaults(),
    );

    expect(withClientState.completedCount, 2);
    expect(
      withClientState.nextIncomplete?.id,
      OnboardingStepId.firstIntervention,
    );

    final withInterventionClient = baseClient
      ..interventions = [
        const InterventionRecord(
          id: 'intervention_1',
          createdAtIso: '2026-04-17T11:00:00Z',
          dateLabel: '17/04/2026',
          technicianName: 'Clara',
          clientRepresentative: 'Mme Martin',
          poolSummary: 'Bassin 45 m3',
          interventionSummary: 'Controle complet',
          recommendations: 'RAS',
          accessNotes: '',
          followUpLabel: 'Controle dans 15 jours',
          estimateLabel: 'Sans devis',
          estimateApproved: true,
          interventionCompleted: true,
          followUpRequired: false,
          attachments: [],
        ),
      ]
      ..financialDocuments = [
        FinancialDocument(
          id: 'doc_1',
          documentNumber: 'FAC-2026-001',
          createdAtIso: '2026-04-17T11:00:00Z',
          type: FinancialDocumentType.invoice,
          status: FinancialDocumentStatus.sent,
          depositAmount: 0,
          title: 'Entretien',
          dateLabel: '17/04/2026',
          dueDateLabel: '17/05/2026',
          clientName: 'Villa Azur',
          technicianName: 'Clara',
          paymentMethodLabel: 'Virement',
          notes: '',
          items: const [],
        ),
      ];

    final completedState = OnboardingChecklistService.build(
      companyProfile: CompanyProfile.defaults().copyWith(
        companyName: 'HydrAzur Pilotage',
        phone: '0400000000',
      ),
      workspaceSettings: WorkspaceSettings.defaults(),
      clients: [withInterventionClient],
      subscription: const Subscription(
        planId: 'pro',
        status: SubscriptionStatus.active,
        startedAtIso: '',
        endedAtIso: '',
        updatedAtIso: '',
      ),
      progress: const OnboardingProgress(
        dismissedAtIso: '',
        firstPdfGeneratedAtIso: '2026-04-17T11:30:00Z',
      ),
    );

    expect(completedState.allCompleted, isTrue);
    expect(completedState.nextIncomplete, isNull);
  });
}
