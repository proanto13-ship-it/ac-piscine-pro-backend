import '../models/client.dart';
import '../models/company_profile.dart';
import '../models/feature_gate.dart';
import '../models/intervention_record.dart';
import '../models/onboarding_progress.dart';
import '../models/subscription.dart';
import '../models/workspace_settings.dart';

enum OnboardingStepId {
  companyProfile,
  firstClient,
  firstIntervention,
  firstPdf,
}

class OnboardingChecklistItem {
  final OnboardingStepId id;
  final String title;
  final String description;
  final bool completed;
  final bool locked;
  final bool countsTowardProgress;

  const OnboardingChecklistItem({
    required this.id,
    required this.title,
    required this.description,
    required this.completed,
    required this.locked,
    this.countsTowardProgress = true,
  });
}

class OnboardingChecklistState {
  final List<OnboardingChecklistItem> items;
  final bool dismissed;

  const OnboardingChecklistState({
    required this.items,
    required this.dismissed,
  });

  List<OnboardingChecklistItem> get progressItems =>
      items.where((item) => item.countsTowardProgress).toList();

  int get completedCount =>
      progressItems.where((item) => item.completed).length;

  int get totalCount => progressItems.length;

  int get bonusCount =>
      items.where((item) => !item.countsTowardProgress).length;

  bool get allCompleted => progressItems.every((item) => item.completed);

  bool get hasOutstandingSteps => !allCompleted;

  OnboardingChecklistItem? get nextIncomplete {
    for (final item in items) {
      if (!item.completed) {
        return item;
      }
    }
    return null;
  }
}

class ClientInterventionTarget {
  final Client client;
  final InterventionRecord intervention;

  const ClientInterventionTarget({
    required this.client,
    required this.intervention,
  });
}

class OnboardingChecklistService {
  static OnboardingChecklistState build({
    required CompanyProfile companyProfile,
    required WorkspaceSettings workspaceSettings,
    required List<Client> clients,
    required Subscription subscription,
    required OnboardingProgress progress,
  }) {
    final activeClients = clients.where((client) => !client.isDeleted).toList();
    final hasProfile = isCompanyProfileConfigured(
      companyProfile: companyProfile,
      workspaceSettings: workspaceSettings,
    );
    final hasClient = activeClients.isNotEmpty;
    final hasIntervention = activeClients.any(
      (client) => client.interventions.any((item) => !item.isDeleted),
    );
    final pdfUnlocked =
        FeatureGate.isEnabled(subscription, EntitlementFlag.pdfExport);

    return OnboardingChecklistState(
      dismissed: progress.isDismissed,
      items: [
        OnboardingChecklistItem(
          id: OnboardingStepId.companyProfile,
          title: 'Compléter le profil entreprise',
          description:
              'Ajoutez les informations de votre entreprise pour personnaliser vos documents.',
          completed: hasProfile,
          locked: false,
        ),
        OnboardingChecklistItem(
          id: OnboardingStepId.firstClient,
          title: 'Créer le premier client',
          description:
              'Enregistrez un bassin pour démarrer un vrai parcours terrain.',
          completed: hasClient,
          locked: false,
        ),
        OnboardingChecklistItem(
          id: OnboardingStepId.firstIntervention,
          title: 'Créer la première intervention',
          description:
              'Lancez une analyse puis ouvrez la fiche d’intervention du client.',
          completed: hasIntervention,
          locked: false,
        ),
        OnboardingChecklistItem(
          id: OnboardingStepId.firstPdf,
          title: 'Générer le premier PDF',
          description: pdfUnlocked
              ? 'Exportez un rapport ou un bon d’intervention pour finaliser votre première valeur.'
              : 'Disponible avec l’offre Pro pour exporter vos rapports d’intervention.',
          completed: progress.hasGeneratedFirstPdf,
          locked: !pdfUnlocked,
          countsTowardProgress: pdfUnlocked,
        ),
      ],
    );
  }

  static bool isCompanyProfileConfigured({
    required CompanyProfile companyProfile,
    required WorkspaceSettings workspaceSettings,
  }) {
    final defaultProfile = CompanyProfile.defaults();
    final hasCompanyName = companyProfile.companyName.trim().isNotEmpty &&
        companyProfile.companyName.trim() != defaultProfile.companyName;
    final hasContact = companyProfile.phone.trim().isNotEmpty ||
        companyProfile.email.trim().isNotEmpty ||
        companyProfile.address.trim().isNotEmpty;
    final hasLocaleSettings = workspaceSettings.countryCode.trim().isNotEmpty &&
        workspaceSettings.localeCode.trim().isNotEmpty &&
        workspaceSettings.currencyCode.trim().isNotEmpty;

    return hasCompanyName && hasContact && hasLocaleSettings;
  }

  static Client? preferredClientForFirstIntervention(List<Client> clients) {
    final activeClients = clients.where((client) => !client.isDeleted).toList();
    if (activeClients.isEmpty) {
      return null;
    }

    activeClients.sort((a, b) {
      final aHasIntervention = a.interventions.any((item) => !item.isDeleted);
      final bHasIntervention = b.interventions.any((item) => !item.isDeleted);
      if (aHasIntervention != bHasIntervention) {
        return aHasIntervention ? 1 : -1;
      }
      final aUpdated = DateTime.tryParse(a.updatedAtIso) ?? DateTime(1970);
      final bUpdated = DateTime.tryParse(b.updatedAtIso) ?? DateTime(1970);
      return bUpdated.compareTo(aUpdated);
    });

    return activeClients.first;
  }

  static ClientInterventionTarget? latestInterventionTarget(
      List<Client> clients) {
    ClientInterventionTarget? target;
    DateTime latestDate = DateTime(1970);

    for (final client in clients.where((item) => !item.isDeleted)) {
      for (final intervention in client.interventions.where(
        (item) => !item.isDeleted,
      )) {
        final date =
            DateTime.tryParse(intervention.updatedAtIso) ?? DateTime(1970);
        if (date.isAfter(latestDate)) {
          latestDate = date;
          target = ClientInterventionTarget(
            client: client,
            intervention: intervention,
          );
        }
      }
    }

    return target;
  }
}
