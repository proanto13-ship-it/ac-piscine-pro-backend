import 'dart:convert';

import '../models/client.dart';
import '../models/cloud_sync_settings.dart';
import '../models/company_profile.dart';
import '../models/financial_document.dart';
import '../models/intervention_record.dart';
import '../models/media_attachment.dart';
import '../models/plan.dart';
import '../models/subscription.dart';
import '../models/team_member.dart';
import '../models/water_analysis.dart';
import '../models/workspace_settings.dart';
import 'app_environment.dart';
import 'local_storage_service.dart';

typedef DemoBinarySaveTransport = Future<String> Function(
  String folderName,
  String fileName,
  List<int> bytes,
);

class DemoDataService {
  static String get _modeFileName =>
      AppEnvironment.storageName('demo_mode.json');
  static String get _demoMediaFolderName =>
      AppEnvironment.folderName('demo_media');
  static const String _transparentPngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+XnqsAAAAASUVORK5CYII=';

  static bool get isAvailable => AppEnvironment.enableDemoMode;

  static Future<bool> isDemoModeEnabled() async {
    final payload = await LocalStorageService.readJsonMap(_modeFileName);
    return payload?['mode'] == 'demo';
  }

  static Future<void> enableDemoMode() async {
    if (!isAvailable) {
      throw StateError(
        'Le mode demo est desactive dans cet environnement.',
      );
    }
    await LocalStorageService.writeJson(
      _modeFileName,
      {
        'mode': 'demo',
        'activatedAtIso': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  static Future<Map<String, dynamic>> buildDemoPayload({
    DemoBinarySaveTransport binarySaveTransport =
        LocalStorageService.saveBinary,
    DateTime? now,
  }) async {
    if (!isAvailable) {
      throw StateError(
        'Le seed demo est desactive dans cet environnement.',
      );
    }
    final anchor = (now ?? DateTime.now()).toUtc();
    final mediaPaths = await Future.wait(
      [
        _savePlaceholderImage(
          binarySaveTransport,
          fileName: 'demo_local_technique.png',
        ),
        _savePlaceholderImage(
          binarySaveTransport,
          fileName: 'demo_pompe_filtres.png',
        ),
        _savePlaceholderImage(
          binarySaveTransport,
          fileName: 'demo_bassin_eau.png',
        ),
      ],
    );

    final companyProfile = CompanyProfile(
      companyName: 'HydrAzur Pilotage',
      phone: '+33 4 92 10 24 40',
      email: 'contact@hydrazur-demo.test',
      address: '18 avenue des Lauriers, 06270 Villeneuve-Loubet',
      website: 'https://hydrazur-demo.test',
      countryCode: 'FR',
      localeCode: 'fr-FR',
      currencyCode: 'EUR',
      businessRegistrationLabel: 'SIRET',
      businessRegistrationValue: '812 345 678 00019',
      taxRegistrationValue: 'FR12812345678',
      technicianDefaultName: 'Clara Martin',
      legalMention:
          'Mode demo local. Donnees de demonstration uniquement, sans valeur contractuelle.',
    );
    final workspaceSettings = WorkspaceSettings.defaults().copyWith(
      localeCode: 'fr-FR',
      currencyCode: 'EUR',
      countryCode: 'FR',
      timeZoneId: 'Europe/Paris',
      unitSystem: 'metric',
    );

    final clients = _buildDemoClients(
      anchor: anchor,
      mediaPaths: mediaPaths,
    );

    return {
      'exportedAt': anchor.toIso8601String(),
      'companyProfile': companyProfile.toJson(),
      'pricingSettings': const {
        'showBudgetEstimates': true,
        'defaultMainOeuvre': 92.0,
      },
      'teamMembers': const [
        TeamMember(
          id: 'team_clara_martin',
          name: 'Clara Martin',
          phone: '+33 6 11 22 33 44',
          email: 'clara@hydrazur-demo.test',
          role: 'Technicienne',
          active: true,
        ),
        TeamMember(
          id: 'team_yanis_rossi',
          name: 'Yanis Rossi',
          phone: '+33 6 55 66 77 88',
          email: 'yanis@hydrazur-demo.test',
          role: 'Responsable exploitation',
          active: true,
        ),
      ].map((member) => member.toJson()).toList(),
      'cloudSyncSettings': CloudSyncSettings.defaults()
          .copyWith(
            enabled: false,
            autoPrepare: false,
            syncMode: CloudSyncMode.legacy,
            endpoint: '',
            lastSyncStatus:
                'Mode demo local charge. Synchronisation cloud desactivee par securite.',
          )
          .toJson(),
      'workspaceSettings': workspaceSettings.toJson(),
      'subscription': const Subscription(
        planId: 'pro',
        status: SubscriptionStatus.active,
        startedAtIso: '',
        endedAtIso: '',
        updatedAtIso: '',
        resolvedPlan: Plan.pro,
      ).toJson(),
      'plans': Plan.catalog.map((plan) => plan.toJson()).toList(),
      'clients': clients.map((client) => client.toJson()).toList(),
    };
  }

  static Future<String> _savePlaceholderImage(
    DemoBinarySaveTransport saveBinary, {
    required String fileName,
  }) {
    return saveBinary(
      _demoMediaFolderName,
      fileName,
      base64Decode(_transparentPngBase64),
    );
  }

  static List<Client> _buildDemoClients({
    required DateTime anchor,
    required List<String> mediaPaths,
  }) {
    final client1 = _buildClient(
      id: 'demo_client_villa_azur',
      name: 'Villa Azur',
      phone: '+33 6 80 12 45 67',
      email: 'maison@villa-azur.test',
      address: '14 allee des Mimosas, 06800 Cagnes-sur-Mer',
      volume: 52,
      treatment: 'Electrolyse au sel',
      bassinType: 'Enterree',
      revetement: 'Membrane armee',
      filtration: 'Filtre a sable',
      equipements: 'PAC, volet, regulation pH',
      notes: 'Client pilote, tres sensible a la clarte de l eau.',
      createdAt: anchor.subtract(const Duration(days: 120)),
      analyses: [
        _buildAnalysis(
          date: anchor.subtract(const Duration(days: 25)),
          ph: 7.3,
          chlore: 1.6,
          tac: 102,
          th: 185,
          stabilisant: 44,
          temperature: 24,
          observation: 'Eau stable, panier skimmer nettoye.',
        ),
        _buildAnalysis(
          date: anchor.subtract(const Duration(days: 9)),
          ph: 7.4,
          chlore: 1.3,
          tac: 96,
          th: 190,
          stabilisant: 42,
          temperature: 23,
          observation: 'RAS, brossage ligne d eau prevu a la prochaine visite.',
        ),
      ],
      interventions: [
        _buildIntervention(
          id: 'demo_int_villa_azur_01',
          date: anchor.subtract(const Duration(days: 35)),
          technicianName: 'Clara Martin',
          clientRepresentative: 'Mme Giraud',
          poolSummary: 'Bassin 10x4 m, eau claire, electrolyse stable.',
          interventionSummary:
              'Nettoyage du prefiltre, controle PAC et reprise de la ligne d eau.',
          recommendations:
              'Maintenir la filtration 10 h/jour avec la hausse des temperatures.',
          accessNotes: 'Acces technique par portillon cote jardin.',
          followUpLabel: 'Controle routine dans 15 jours',
          estimateLabel: 'Sans devis complementaire',
          estimateApproved: true,
          interventionCompleted: true,
          followUpRequired: true,
          createdAtIso:
              anchor.subtract(const Duration(days: 35)).toIso8601String(),
          attachments: [
            _buildAttachment(
              id: 'demo_att_villa_azur_01',
              path: mediaPaths[0],
              createdAt: anchor.subtract(const Duration(days: 35)),
            ),
          ],
        ),
        _buildIntervention(
          id: 'demo_int_villa_azur_02',
          date: anchor.subtract(const Duration(days: 8)),
          technicianName: 'Yanis Rossi',
          clientRepresentative: 'Mme Giraud',
          poolSummary: 'Bon equilibre eau, debit filtration correct.',
          interventionSummary:
              'Traitement preventif anti-calcaire et nettoyage du coffre volet.',
          recommendations: 'Revoir le niveau de sel avant juillet.',
          accessNotes: 'Prevenir 30 min avant passage.',
          followUpLabel: 'Pas de suivi urgent',
          estimateLabel: 'Option entretien volet a confirmer',
          estimateApproved: false,
          interventionCompleted: true,
          followUpRequired: false,
          createdAtIso:
              anchor.subtract(const Duration(days: 8)).toIso8601String(),
          attachments: [
            _buildAttachment(
              id: 'demo_att_villa_azur_02',
              path: mediaPaths[1],
              createdAt: anchor.subtract(const Duration(days: 8)),
            ),
          ],
        ),
      ],
      documents: [
        _buildFinancialDocument(
          id: 'demo_doc_villa_azur_01',
          documentNumber: 'FAC-2026-004',
          createdAt: anchor.subtract(const Duration(days: 8)),
          dueAt: anchor.add(const Duration(days: 22)),
          type: FinancialDocumentType.invoice,
          status: FinancialDocumentStatus.sent,
          title: 'Entretien mensuel premium',
          clientName: 'Villa Azur',
          items: const [
            FinancialLineItem(
              label: 'Entretien bassin 52 m3',
              quantity: 1,
              unitPrice: 145,
            ),
            FinancialLineItem(
              label: 'Sequestrant calcaire',
              quantity: 1,
              unitPrice: 16,
            ),
          ],
          notes: 'Reglement sous 30 jours.',
        ),
      ],
    );

    final client2 = _buildClient(
      id: 'demo_client_residence_oliviers',
      name: 'Residence Les Oliviers',
      phone: '+33 4 93 44 55 66',
      email: 'syndic@oliviers-demo.test',
      address: '3 impasse des Oliviers, 06160 Antibes',
      volume: 96,
      treatment: 'Chlore liquide',
      bassinType: 'Collectif',
      revetement: 'Carrelage',
      filtration: 'Verre filtre',
      equipements: 'Pompe doseuse, nage a contre-courant',
      notes: 'Syndic attentif aux rapports et aux photos.',
      createdAt: anchor.subtract(const Duration(days: 200)),
      analyses: [
        _buildAnalysis(
          date: anchor.subtract(const Duration(days: 18)),
          ph: 7.2,
          chlore: 2.1,
          tac: 105,
          th: 210,
          stabilisant: 36,
          temperature: 22,
          observation:
              'Bassin collectif tres frequente, contre-lavage effectue.',
        ),
      ],
      interventions: [
        _buildIntervention(
          id: 'demo_int_oliviers_01',
          date: anchor.subtract(const Duration(days: 21)),
          technicianName: 'Clara Martin',
          clientRepresentative: 'Syndic M. Vidal',
          poolSummary: 'Bassin collectif avant ouverture saison.',
          interventionSummary:
              'Mise en route printemps, verification pompe doseuse et securites.',
          recommendations: 'Passer en rythme bi-hebdomadaire en haute saison.',
          accessNotes: 'Cle local technique a l accueil.',
          followUpLabel: 'Controle ouverture a J+7',
          estimateLabel: 'Sans devis',
          estimateApproved: true,
          interventionCompleted: true,
          followUpRequired: true,
          createdAtIso:
              anchor.subtract(const Duration(days: 21)).toIso8601String(),
          attachments: [
            _buildAttachment(
              id: 'demo_att_oliviers_01',
              path: mediaPaths[2],
              createdAt: anchor.subtract(const Duration(days: 21)),
            ),
          ],
        ),
        _buildIntervention(
          id: 'demo_int_oliviers_02',
          date: anchor.subtract(const Duration(days: 5)),
          technicianName: 'Yanis Rossi',
          clientRepresentative: 'Gardien M. Lopez',
          poolSummary: 'Debit et filtration conformes, ligne d eau propre.',
          interventionSummary:
              'Recalage consigne pompe doseuse et nettoyage bac tampon.',
          recommendations:
              'Surveiller le TAC apres les premiers gros apports d eau.',
          accessNotes: 'Stationnement service devant le portail B.',
          followUpLabel: 'Controle standard dans 7 jours',
          estimateLabel: 'Option remplacement sonde pH',
          estimateApproved: false,
          interventionCompleted: true,
          followUpRequired: true,
          createdAtIso:
              anchor.subtract(const Duration(days: 5)).toIso8601String(),
          attachments: const [],
        ),
      ],
      documents: [
        _buildFinancialDocument(
          id: 'demo_doc_oliviers_01',
          documentNumber: 'DEV-2026-003',
          createdAt: anchor.subtract(const Duration(days: 6)),
          dueAt: anchor.add(const Duration(days: 14)),
          type: FinancialDocumentType.quote,
          status: FinancialDocumentStatus.approved,
          title: 'Remplacement sonde pH',
          clientName: 'Residence Les Oliviers',
          items: const [
            FinancialLineItem(
              label: 'Sonde pH professionnelle',
              quantity: 1,
              unitPrice: 198,
            ),
            FinancialLineItem(
              label: 'Pose et recalibrage',
              quantity: 1,
              unitPrice: 95,
            ),
          ],
          notes: 'Valide par le syndic pour intervention avant juin.',
        ),
      ],
    );

    final client3 = _buildClient(
      id: 'demo_client_bastide_mimosas',
      name: 'Bastide des Mimosas',
      phone: '+33 6 72 90 34 10',
      email: 'accueil@bastide-demo.test',
      address: '92 chemin des Mimosas, 06560 Valbonne',
      volume: 38,
      treatment: 'Brome',
      bassinType: 'Coque',
      revetement: 'Gel coat',
      filtration: 'Cartouche',
      equipements: 'Robot, couverture a barres',
      notes: 'Site secondaire de demonstration avec bons avant/apres.',
      createdAt: anchor.subtract(const Duration(days: 90)),
      analyses: [
        _buildAnalysis(
          date: anchor.subtract(const Duration(days: 14)),
          ph: 7.5,
          chlore: 1.1,
          tac: 90,
          th: 170,
          stabilisant: 28,
          temperature: 21,
          observation:
              'Eau legerement sous stabilisee, ajout preventif conseille.',
        ),
      ],
      interventions: [
        _buildIntervention(
          id: 'demo_int_mimosas_01',
          date: anchor.subtract(const Duration(days: 16)),
          technicianName: 'Clara Martin',
          clientRepresentative: 'Mme Rolland',
          poolSummary: 'Petit bassin prive, aspiration correcte.',
          interventionSummary:
              'Nettoyage cartouche, reprise equilibre brome et ajout stabilisant.',
          recommendations:
              'Rincer la cartouche chaque semaine en periode pollen.',
          accessNotes: 'Local technique derriere le pool house.',
          followUpLabel: 'Passage de controle dans 10 jours',
          estimateLabel: 'Sans devis',
          estimateApproved: true,
          interventionCompleted: true,
          followUpRequired: true,
          createdAtIso:
              anchor.subtract(const Duration(days: 16)).toIso8601String(),
          attachments: const [],
        ),
        _buildIntervention(
          id: 'demo_int_mimosas_02',
          date: anchor.subtract(const Duration(days: 2)),
          technicianName: 'Yanis Rossi',
          clientRepresentative: 'Mme Rolland',
          poolSummary: 'Bassin propre, couverture controlee.',
          interventionSummary:
              'Verification apres orage, vidange prefiltre et correction pH.',
          recommendations:
              'Laisser la couverture ouverte 2 h apres traitement.',
          accessNotes: 'Code portail 2458.',
          followUpLabel: 'Pas de suivi urgent',
          estimateLabel: 'Sans devis',
          estimateApproved: true,
          interventionCompleted: true,
          followUpRequired: false,
          createdAtIso:
              anchor.subtract(const Duration(days: 2)).toIso8601String(),
          attachments: const [],
        ),
      ],
      documents: const [],
    );

    final client4 = _buildClient(
      id: 'demo_client_hotel_rivage',
      name: 'Hotel Le Rivage',
      phone: '+33 4 97 12 20 20',
      email: 'technique@rivage-demo.test',
      address: '7 boulevard du Littoral, 06220 Vallauris',
      volume: 124,
      treatment: 'UV + chlore',
      bassinType: 'Hotel',
      revetement: 'Mosaique',
      filtration: 'Sable haute performance',
      equipements: 'UV, regulation Redox, bac tampon',
      notes: 'Compte cle pour les demos B2B et les tests de synchro.',
      createdAt: anchor.subtract(const Duration(days: 260)),
      analyses: [
        _buildAnalysis(
          date: anchor.subtract(const Duration(days: 30)),
          ph: 7.25,
          chlore: 1.8,
          tac: 108,
          th: 220,
          stabilisant: 34,
          temperature: 27,
          observation: 'Conforme avant week-end evenementiel.',
        ),
      ],
      interventions: [
        _buildIntervention(
          id: 'demo_int_rivage_01',
          date: anchor.subtract(const Duration(days: 11)),
          technicianName: 'Clara Martin',
          clientRepresentative: 'Direction technique',
          poolSummary: 'Controle complet avant evenement prive.',
          interventionSummary:
              'Audit local technique, calibration Redox et securisation bac tampon.',
          recommendations:
              'Anticiper changement lampe UV au trimestre prochain.',
          accessNotes: 'Acces par service, badge reception.',
          followUpLabel: 'Planifier devis maintenance UV',
          estimateLabel: 'Devis UV en preparation',
          estimateApproved: false,
          interventionCompleted: true,
          followUpRequired: true,
          createdAtIso:
              anchor.subtract(const Duration(days: 11)).toIso8601String(),
          attachments: const [],
        ),
      ],
      documents: [
        _buildFinancialDocument(
          id: 'demo_doc_rivage_01',
          documentNumber: 'DEV-2026-005',
          createdAt: anchor.subtract(const Duration(days: 10)),
          dueAt: anchor.add(const Duration(days: 20)),
          type: FinancialDocumentType.quote,
          status: FinancialDocumentStatus.sent,
          title: 'Maintenance unite UV',
          clientName: 'Hotel Le Rivage',
          items: const [
            FinancialLineItem(
              label: 'Remplacement lampe UV',
              quantity: 2,
              unitPrice: 185,
            ),
            FinancialLineItem(
              label: 'Main d oeuvre et calibration',
              quantity: 1,
              unitPrice: 130,
            ),
          ],
          notes: 'Devis de reference pour les demonstrations commerciales.',
        ),
      ],
    );

    return [
      client1,
      client2,
      client3,
      client4,
    ];
  }

  static Client _buildClient({
    required String id,
    required String name,
    required String phone,
    required String email,
    required String address,
    required double volume,
    required String treatment,
    required String bassinType,
    required String revetement,
    required String filtration,
    required String equipements,
    required String notes,
    required DateTime createdAt,
    required List<WaterAnalysis> analyses,
    required List<InterventionRecord> interventions,
    required List<FinancialDocument> documents,
  }) {
    final createdAtIso = createdAt.toIso8601String();
    final latestInterventionIso = interventions.isEmpty
        ? ''
        : interventions.map((item) => item.updatedAtIso).reduce(_maxIsoString);
    final latestDocumentIso = documents.isEmpty
        ? ''
        : documents.map((item) => item.updatedAtIso).reduce(_maxIsoString);
    final updatedAtIso = [
      createdAtIso,
      latestInterventionIso,
      latestDocumentIso,
    ].reduce(_maxIsoString);
    return Client(
      id: id,
      name: name,
      phone: phone,
      email: email,
      address: address,
      volume: volume,
      treatment: treatment,
      bassinType: bassinType,
      revetement: revetement,
      filtration: filtration,
      equipements: equipements,
      visitFrequencyDays: 14,
      createdAtIso: createdAtIso,
      updatedAtIso: updatedAtIso,
      version: 1,
      deletedAtIso: '',
      notes: notes,
      analyses: analyses,
      interventions: interventions,
      financialDocuments: documents,
    );
  }

  static WaterAnalysis _buildAnalysis({
    required DateTime date,
    required double ph,
    required double chlore,
    required double tac,
    required double th,
    required double stabilisant,
    required double temperature,
    required String observation,
  }) {
    return WaterAnalysis(
      dateIso: date.toIso8601String(),
      ph: ph,
      chlore: chlore,
      tac: tac,
      th: th,
      stabilisant: stabilisant,
      temperature: temperature,
      tds: 0,
      lsi: 0,
      stabilityScore: 8,
      eauSalee: false,
      liner: false,
      observation: observation,
      mainOeuvre: 92,
    );
  }

  static InterventionRecord _buildIntervention({
    required String id,
    required DateTime date,
    required String technicianName,
    required String clientRepresentative,
    required String poolSummary,
    required String interventionSummary,
    required String recommendations,
    required String accessNotes,
    required String followUpLabel,
    required String estimateLabel,
    required bool estimateApproved,
    required bool interventionCompleted,
    required bool followUpRequired,
    required String createdAtIso,
    required List<MediaAttachment> attachments,
  }) {
    final localDate = date.toLocal();
    return InterventionRecord(
      id: id,
      createdAtIso: createdAtIso,
      dateLabel: _formatDateLabel(localDate),
      technicianName: technicianName,
      clientRepresentative: clientRepresentative,
      poolSummary: poolSummary,
      interventionSummary: interventionSummary,
      recommendations: recommendations,
      accessNotes: accessNotes,
      followUpLabel: followUpLabel,
      estimateLabel: estimateLabel,
      estimateApproved: estimateApproved,
      interventionCompleted: interventionCompleted,
      followUpRequired: followUpRequired,
      signatureBase64: null,
      attachments: attachments,
      updatedAtIso: createdAtIso,
      version: 1,
      deletedAtIso: '',
    );
  }

  static MediaAttachment _buildAttachment({
    required String id,
    required String path,
    required DateTime createdAt,
  }) {
    final createdAtIso = createdAt.toIso8601String();
    return MediaAttachment(
      id: id,
      localPath: path,
      remoteUrl: '',
      mimeType: 'image/png',
      uploadStatus: MediaAttachment.pending,
      createdAtIso: createdAtIso,
      updatedAtIso: createdAtIso,
      version: 1,
      deletedAtIso: '',
    );
  }

  static FinancialDocument _buildFinancialDocument({
    required String id,
    required String documentNumber,
    required DateTime createdAt,
    required DateTime dueAt,
    required FinancialDocumentType type,
    required FinancialDocumentStatus status,
    required String title,
    required String clientName,
    required List<FinancialLineItem> items,
    required String notes,
  }) {
    final createdAtIso = createdAt.toIso8601String();
    final dueAtIso = dueAt.toIso8601String();
    return FinancialDocument(
      id: id,
      documentNumber: documentNumber,
      createdAtIso: createdAtIso,
      issuedAtIso: createdAtIso,
      dueAtIso: dueAtIso,
      currencyCode: 'EUR',
      taxLabel: 'TVA',
      taxRate: 20,
      type: type,
      status: status,
      depositAmount: 0,
      title: title,
      dateLabel: _formatDateLabel(createdAt.toLocal()),
      dueDateLabel: _formatDateLabel(dueAt.toLocal()),
      clientName: clientName,
      technicianName: 'Clara Martin',
      paymentMethodLabel: 'Virement',
      notes: notes,
      items: items,
      updatedAtIso: createdAtIso,
      version: 1,
      deletedAtIso: '',
    );
  }

  static String _formatDateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  static String _maxIsoString(String left, String right) {
    final leftValue = DateTime.tryParse(left);
    final rightValue = DateTime.tryParse(right);
    if (leftValue == null) return right;
    if (rightValue == null) return left;
    return leftValue.isAfter(rightValue) ? left : right;
  }
}
