import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'diagnostic_page_pro.dart';
import 'pages/account_data_page.dart';
import 'pages/login_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/pricing_page.dart';
import 'pages/subscription_status_page.dart';
import 'pages/support_page.dart';
import 'pages/visit_plan_page.dart';
import 'photo_diagnosis_page.dart';
import 'splash_screen.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'l10n/app_localizations.dart';
import 'models/cloud_sync_settings.dart';
import 'models/client.dart';
import 'models/company_profile.dart';
import 'models/plan.dart';
import 'models/financial_document.dart';
import 'models/feature_gate.dart';
import 'models/intervention_record.dart';
import 'models/media_attachment.dart';
import 'models/onboarding_progress.dart';
import 'models/pricing_settings.dart';
import 'models/subscription.dart';
import 'models/sync_queue_item.dart';
import 'models/sync_queue_state.dart';
import 'models/team_member.dart';
import 'models/visit_plan.dart';
import 'models/water_analysis.dart';
import 'models/workspace_settings.dart';
import 'services/backup_service.dart';
import 'services/auth_service.dart';
import 'services/billing_service.dart';
import 'services/billing_provider.dart';
import 'services/app_error_service.dart';
import 'services/app_environment.dart';
import 'services/app_logger.dart';
import 'services/dev_billing_provider.dart';
import 'services/cloud_sync_service.dart';
import 'services/document_number_service.dart';
import 'services/document_share_service.dart';
import 'services/formatting_service.dart';
import 'services/local_storage_service.dart';
import 'services/onboarding_checklist_service.dart';
import 'services/onboarding_progress_service.dart';
import 'services/pdf_service.dart';
import 'services/public_share_service.dart';
import 'services/secure_storage_service.dart';
import 'services/sync_merge_service.dart';
import 'services/sync_queue_service.dart';
import 'services/sync_repository.dart';
import 'services/team_service.dart';
import 'services/native_billing_provider.dart';
import 'services/visit_planning_service.dart';
import 'services/visit_reminder_service.dart';
import 'widgets/optimized_file_image.dart';

double calculerScore({
  required double ph,
  required double chlore,
  required double tac,
  required double th,
  required String observation,
}) {
  double score = 10;

  if (ph > 7.8 || ph < 6.8) {
    score -= 3;
  } else if (ph > 7.6 || ph < 7.0) {
    score -= 2;
  }

  if (chlore < 1.0) {
    score -= 3;
  } else if (chlore < 1.5) {
    score -= 1.5;
  }

  if (tac > 200) {
    score -= 2;
  } else if (tac > 150) {
    score -= 1;
  }

  if (th > 300) {
    score -= 1;
  }

  if (observation.toLowerCase().contains("verte")) {
    score -= 2;
  }

  if (score < 0) score = 0;

  return score;
}

double calculateStabilityScore({
  required double ph,
  required double chlore,
  required double tac,
  required double th,
  required double stabilisant,
}) {
  double score = 10;

  // pH idéal 7.2 – 7.6
  if (ph < 7.0 || ph > 7.8) {
    score -= 3;
  } else if (ph < 7.2 || ph > 7.6) {
    score -= 1;
  }

  // Chlore idéal 1.5 – 2 ppm
  if (chlore < 1.0 || chlore > 3.0) {
    score -= 3;
  } else if (chlore < 1.5 || chlore > 2.0) {
    score -= 1;
  }

  // TAC idéal 100 – 150 ppm
  if (tac < 80 || tac > 200) {
    score -= 2;
  }

  // TH idéal 150 – 250 ppm
  if (th < 100 || th > 300) {
    score -= 1;
  }

  // Stabilisant idéal 30 – 50 ppm
  if (stabilisant < 20 || stabilisant > 70) {
    score -= 2;
  }

  if (score < 0) score = 0;

  return score;
}

double calculateLSI({
  required double ph,
  required double temperature,
  required double th,
  required double tac,
  required double stabilisant,
}) {
  double tf;

  if (temperature < 10) {
    tf = 0.0;
  } else if (temperature < 14) {
    tf = 0.1;
  } else if (temperature < 18) {
    tf = 0.2;
  } else if (temperature < 22) {
    tf = 0.3;
  } else if (temperature < 28) {
    tf = 0.4;
  } else if (temperature < 33) {
    tf = 0.5;
  } else {
    tf = 0.6;
  }

  final double cf = th > 0 ? (log(th) / ln10) - 0.4 : 0.0;

  final double tacCorrige = tac - (stabilisant / 3);
  final double af = tacCorrige > 0 ? (log(tacCorrige) / ln10) : 0.0;

  final double lsi = ph + tf + cf + af - 12.1;

  return double.parse(lsi.toStringAsFixed(2));
}

double calculatePremiumScore({
  required double ph,
  required double chlore,
  required double tac,
  required double th,
  required double stabilisant,
  required double lsi,
}) {
  double score = 100;

  if (ph < 7.2 || ph > 7.6) score -= 15;
  if (chlore < 1.5 || chlore > 2.5) score -= 20;
  if (tac < 80 || tac > 180) score -= 15;
  if (lsi.abs() > 0.3) score -= 20;
  if (stabilisant > 60) score -= 10;

  return score.clamp(0, 100);
}

String interpretLSI(double lsi) {
  if (lsi < -0.3) {
    return "Eau agressive ⚠️ Risque corrosion";
  } else if (lsi < 0) {
    return "Légèrement agressive";
  } else if (lsi <= 0.3) {
    return "Équilibre idéal ✔";
  } else if (lsi <= 0.5) {
    return "Légèrement entartrante";
  } else {
    return "Fort risque entartrage ⚠️";
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BillingService.configureProvider(_buildBillingProvider());
  await AppLogger.init();
  AppErrorService.install();
  await runZonedGuarded(
    () async {
      await SyncQueueService.load();
      await AppStore.load();
      runApp(const ACPiscineProApp());
    },
    (error, stackTrace) {
      unawaited(AppErrorService.reportZoneError(error, stackTrace));
    },
  );
}

BillingProvider _buildBillingProvider() {
  if (AppEnvironment.enableNativeBilling &&
      AppEnvironment.hasNativeBillingProductIds &&
      NativeBillingProvider.isSupportedPlatform) {
    return NativeBillingProvider();
  }
  return const DevBillingProvider();
}

bool isInitialOrganizationSetupComplete({
  CompanyProfile? profile,
  WorkspaceSettings? workspaceSettings,
}) {
  final company = profile ?? AppStore.companyProfile;
  final workspace = workspaceSettings ?? AppStore.workspaceSettings;
  final defaultCompanyName = CompanyProfile.defaults().companyName;

  final hasIdentity = company.companyName.trim().isNotEmpty &&
      company.companyName.trim() != defaultCompanyName;
  final hasContact = company.phone.trim().isNotEmpty ||
      company.email.trim().isNotEmpty ||
      company.address.trim().isNotEmpty;
  final hasLocale = workspace.countryCode.trim().isNotEmpty &&
      workspace.localeCode.trim().isNotEmpty &&
      workspace.currencyCode.trim().isNotEmpty;

  return hasIdentity && hasContact && hasLocale;
}

Map<String, dynamic> _organizationSetupPayload({
  required CompanyProfile company,
  required WorkspaceSettings workspace,
}) {
  return {
    'name': company.companyName,
    'companyName': company.companyName,
    'phone': company.phone,
    'email': company.email,
    'address': company.address,
    'countryCode': company.countryCode,
    'localeCode': company.localeCode,
    'currencyCode': company.currencyCode,
    'businessRegistrationLabel': company.businessRegistrationLabel,
    'businessRegistrationValue': company.businessRegistrationValue,
    'taxRegistrationValue': company.taxRegistrationValue,
    'companyProfile': company.toJson(),
    'workspaceSettings': workspace.toJson(),
  };
}

Future<void> hydrateOrganizationSetupFromV2IfPossible() async {
  if (!AuthService.isAuthenticated) {
    return;
  }

  try {
    final remote = await AuthService.fetchOrganizationProfile();
    if (remote == null) {
      if (isInitialOrganizationSetupComplete()) {
        await AuthService.saveOrganizationProfile(
          payload: _organizationSetupPayload(
            company: AppStore.companyProfile,
            workspace: AppStore.workspaceSettings,
          ),
        );
      }
      return;
    }

    final nestedCompany = remote['companyProfile'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(remote['companyProfile'])
        : remote['companyProfile'] is Map
            ? Map<String, dynamic>.from(remote['companyProfile'] as Map)
            : const <String, dynamic>{};
    final nestedWorkspace = remote['workspaceSettings'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(remote['workspaceSettings'])
        : remote['workspaceSettings'] is Map
            ? Map<String, dynamic>.from(remote['workspaceSettings'] as Map)
            : const <String, dynamic>{};

    final currentCompany = AppStore.companyProfile;
    final currentWorkspace = AppStore.workspaceSettings;

    final mergedCompany = currentCompany.copyWith(
      companyName: _firstMeaningfulString([
        nestedCompany['companyName'],
        remote['companyName'],
        remote['name'],
        currentCompany.companyName,
      ], fallback: CompanyProfile.defaults().companyName),
      phone: _firstMeaningfulString([
        nestedCompany['phone'],
        remote['phone'],
        currentCompany.phone,
      ]),
      email: _firstMeaningfulString([
        nestedCompany['email'],
        remote['email'],
        currentCompany.email,
      ]),
      address: _firstMeaningfulString([
        nestedCompany['address'],
        remote['address'],
        currentCompany.address,
      ]),
      countryCode: _firstMeaningfulString([
        nestedCompany['countryCode'],
        nestedWorkspace['countryCode'],
        remote['countryCode'],
        currentCompany.countryCode,
      ], fallback: CompanyProfile.defaults().countryCode),
      localeCode: _firstMeaningfulString([
        nestedCompany['localeCode'],
        nestedWorkspace['localeCode'],
        remote['localeCode'],
        currentCompany.localeCode,
      ], fallback: CompanyProfile.defaults().localeCode),
      currencyCode: _firstMeaningfulString([
        nestedCompany['currencyCode'],
        nestedWorkspace['currencyCode'],
        remote['currencyCode'],
        currentCompany.currencyCode,
      ], fallback: CompanyProfile.defaults().currencyCode),
      businessRegistrationLabel: _firstMeaningfulString([
        nestedCompany['businessRegistrationLabel'],
        remote['businessRegistrationLabel'],
        currentCompany.businessRegistrationLabel,
      ]),
      businessRegistrationValue: _firstMeaningfulString([
        nestedCompany['businessRegistrationValue'],
        remote['businessRegistrationValue'],
        currentCompany.businessRegistrationValue,
      ]),
      taxRegistrationValue: _firstMeaningfulString([
        nestedCompany['taxRegistrationValue'],
        remote['taxRegistrationValue'],
        currentCompany.taxRegistrationValue,
      ]),
    );

    final mergedWorkspace = currentWorkspace.copyWith(
      countryCode: _firstMeaningfulString([
        nestedWorkspace['countryCode'],
        nestedCompany['countryCode'],
        remote['countryCode'],
        currentWorkspace.countryCode,
      ], fallback: WorkspaceSettings.defaults().countryCode),
      localeCode: _firstMeaningfulString([
        nestedWorkspace['localeCode'],
        nestedCompany['localeCode'],
        remote['localeCode'],
        currentWorkspace.localeCode,
      ], fallback: WorkspaceSettings.defaults().localeCode),
      currencyCode: _firstMeaningfulString([
        nestedWorkspace['currencyCode'],
        nestedCompany['currencyCode'],
        remote['currencyCode'],
        currentWorkspace.currencyCode,
      ], fallback: WorkspaceSettings.defaults().currencyCode),
      timeZoneId: _firstMeaningfulString([
        nestedWorkspace['timeZoneId'],
        remote['timeZoneId'],
        currentWorkspace.timeZoneId,
      ], fallback: WorkspaceSettings.defaults().timeZoneId),
      unitSystem: _firstMeaningfulString([
        nestedWorkspace['unitSystem'],
        remote['unitSystem'],
        currentWorkspace.unitSystem,
      ], fallback: WorkspaceSettings.defaults().unitSystem),
    );

    AppStore.companyProfile = mergedCompany;
    AppStore.workspaceSettings = mergedWorkspace;
    await AppStore.saveCompanyProfile();
    await AppStore.saveWorkspaceSettings();
  } catch (_) {
    // Non bloquant: on garde la configuration locale existante.
  }
}

Future<void> hydrateBillingFromV2IfPossible() async {
  if (!AuthService.isAuthenticated) {
    return;
  }

  try {
    await refreshBillingFromV2();
  } catch (_) {
    // Non bloquant: on garde le fallback local existant.
  }
}

Future<bool> refreshBillingFromV2() async {
  final snapshot = await BillingService.fetchSnapshot();
  if (snapshot == null) {
    return false;
  }
  AppStore.plans = snapshot.plans.isEmpty ? Plan.catalog : snapshot.plans;
  AppStore.subscription = snapshot.subscription;
  await AppStore.savePlans();
  await AppStore.saveSubscription();
  return true;
}

Future<void> hydrateTeamFromV2IfPossible() async {
  if (!AuthService.isAuthenticated) {
    return;
  }

  try {
    await refreshTeamFromV2();
  } catch (_) {
    // Non bloquant: on garde le fallback local existant.
  }
}

Future<bool> refreshTeamFromV2() async {
  final members = await TeamService.fetchTeamMembers();
  if (members.isEmpty &&
      !TeamService.canManageTeam(AuthService.currentSession)) {
    AppStore.teamMembers = members;
    await AppStore.saveTeamMembers();
    return true;
  }
  if (members.isEmpty && !AuthService.isAuthenticated) {
    return false;
  }
  AppStore.teamMembers = members;
  await AppStore.saveTeamMembers();
  return true;
}

SyncRepository _repositoryForMode(CloudSyncMode syncMode) {
  return syncMode == CloudSyncMode.v2
      ? const V2SyncRepository()
      : const LegacyCloudSyncRepository();
}

Future<String?> _credentialForSyncMode(CloudSyncMode syncMode) async {
  if (syncMode == CloudSyncMode.v2) {
    return AuthService.currentSession?.token;
  }
  return SecureStorageService.readCloudSyncApiKey();
}

Future<CloudSyncResult> executeQueuedSyncOperation(SyncQueueItem item) async {
  final credential = await _credentialForSyncMode(item.syncMode);
  if (item.syncMode == CloudSyncMode.v2 &&
      (credential == null || credential.trim().isEmpty)) {
    return const CloudSyncResult(
      ok: false,
      message: 'Connexion requise pour traiter la file de synchronisation.',
    );
  }

  final repository = _repositoryForMode(item.syncMode);
  switch (item.type) {
    case SyncQueueOperationType.push:
      return repository.push(
        endpoint: item.endpoint,
        apiKey: credential,
        payload: AppStore.exportPayload(),
      );
    case SyncQueueOperationType.pull:
      return repository.pull(
        endpoint: item.endpoint,
        apiKey: credential,
        basePayload: AppStore.exportPayload(),
        sinceIso: item.sinceIso.trim().isEmpty ? null : item.sinceIso,
      );
  }
}

Future<void> _applyQueuedSyncSuccess(
  SyncQueueItem item,
  CloudSyncResult result,
) async {
  final nowIso = DateTime.now().toIso8601String();
  final currentSettings = AppStore.cloudSyncSettings;

  if (result.ok && result.payload != null) {
    if (item.type == SyncQueueOperationType.push &&
        result.payload!['clients'] is List) {
      await AppStore.importPayload(result.payload!);
    } else if (item.type == SyncQueueOperationType.pull) {
      await AppStore.importPayload(result.payload!);
    }
  }

  AppStore.cloudSyncSettings = currentSettings.copyWith(
    endpoint: item.endpoint,
    syncMode: item.syncMode,
    lastPreparedAtIso:
        item.type == SyncQueueOperationType.push && currentSettings.autoPrepare
            ? nowIso
            : currentSettings.lastPreparedAtIso,
    lastPushedAtIso: item.type == SyncQueueOperationType.push
        ? nowIso
        : currentSettings.lastPushedAtIso,
    lastPulledAtIso: item.type == SyncQueueOperationType.pull
        ? nowIso
        : currentSettings.lastPulledAtIso,
    lastSyncStatus: result.message,
  );
  await AppStore.saveCloudSyncSettings();

  unawaited(
    AppLogger.event(
      item.type == SyncQueueOperationType.push ? 'sync_push' : 'sync_pull',
      category: 'sync',
      data: {
        'mode': item.syncMode.name,
        'endpoint': item.endpoint,
        'ok': result.ok,
        'message': result.message,
        'queued': true,
      },
    ),
  );
}

Future<void> _applyQueuedSyncFailure(
  SyncQueueItem item,
  CloudSyncResult result,
) async {
  AppStore.cloudSyncSettings = AppStore.cloudSyncSettings.copyWith(
    endpoint: item.endpoint,
    syncMode: item.syncMode,
    lastSyncStatus: result.message,
  );
  await AppStore.saveCloudSyncSettings();

  unawaited(
    AppLogger.warning(
      item.type == SyncQueueOperationType.push
          ? 'sync_push_failed'
          : 'sync_pull_failed',
      category: 'sync',
      data: {
        'mode': item.syncMode.name,
        'endpoint': item.endpoint,
        'message': result.message,
        'queued': true,
        'statusCode': result.statusCode,
      },
    ),
  );
}

Future<SyncQueueSnapshot> processPendingSyncQueue({
  bool forceRetryNow = false,
}) {
  return SyncQueueService.processPending(
    executor: executeQueuedSyncOperation,
    onSuccess: _applyQueuedSyncSuccess,
    onFailure: _applyQueuedSyncFailure,
    forceRetryNow: forceRetryNow,
  );
}

String _firstMeaningfulString(
  List<dynamic> values, {
  String fallback = '',
}) {
  for (final value in values) {
    final normalized = value?.toString().trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return fallback;
}

String _teamSummaryLabel(List<TeamMember> members) {
  final activeCount = members.where((member) => member.active).length;
  final pendingCount = members.where((member) => member.isPending).length;
  final activeLabel =
      '$activeCount membre${activeCount > 1 ? 's' : ''} actif${activeCount > 1 ? 's' : ''}';
  if (pendingCount == 0) {
    return activeLabel;
  }
  return '$activeLabel • $pendingCount invitation${pendingCount > 1 ? 's' : ''}';
}

Future<String?> promptPublicShareExpiration(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text('Validité du lien'),
            subtitle: Text('Choisissez la durée de lecture publique.'),
          ),
          ListTile(
            leading: const Icon(Icons.timer_off_outlined),
            title: const Text('Sans expiration'),
            onTap: () => Navigator.pop(context, ''),
          ),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('Expire dans 7 jours'),
            onTap: () => Navigator.pop(
              context,
              DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 7))
                  .toIso8601String(),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Expire dans 30 jours'),
            onTap: () => Navigator.pop(
              context,
              DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 30))
                  .toIso8601String(),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> createAndPresentPublicShareLink(
  BuildContext context, {
  required PublicShareResourceType resourceType,
  required String resourceId,
}) async {
  if (!AuthService.isAuthenticated) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connexion requise pour créer un lien de partage.'),
      ),
    );
    return;
  }

  final expiresAtIso = await promptPublicShareExpiration(context);
  if (context.mounted == false || expiresAtIso == null) {
    return;
  }

  try {
    final link = await PublicShareService.createLink(
      resourceType: resourceType,
      resourceId: resourceId,
      expiresAtIso: expiresAtIso,
    );
    await Clipboard.setData(ClipboardData(text: link.publicUrl));
    if (!context.mounted) return;
    await AppLogger.event(
      'public_share_link_created',
      category: 'sharing',
      data: {
        'resourceType': resourceType.apiValue,
        'resourceId': resourceId,
        'hasExpiration': link.hasExpiration,
      },
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lien de partage prêt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Le lien a été copié dans le presse-papiers. Vous pouvez maintenant l’envoyer au client.',
            ),
            const SizedBox(height: 12),
            SelectableText(link.publicUrl),
            if (link.hasExpiration) ...[
              const SizedBox(height: 12),
              Text(
                'Expiration : ${FormattingService.formatDateTimeFromIso(link.expiresAtIso, AppStore.workspaceSettings)}',
                style: const TextStyle(color: Color(0xFF667085)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
          FilledButton(
            onPressed: () async {
              final uri = Uri.tryParse(link.publicUrl);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Ouvrir le lien'),
          ),
        ],
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }
}

Future<Widget> resolveAuthenticatedEntryPage() async {
  await hydrateBillingFromV2IfPossible();
  await hydrateTeamFromV2IfPossible();
  await hydrateOrganizationSetupFromV2IfPossible();
  await processPendingSyncQueue();
  if (!isInitialOrganizationSetupComplete()) {
    return const OnboardingPage(
      completedPageResolver: resolveAuthenticatedEntryPage,
    );
  }
  return const HomePage();
}

class ACPiscineProApp extends StatelessWidget {
  const ACPiscineProApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F6E7C)),
      scaffoldBackgroundColor: const Color(0xFFF4F7F9),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppEnvironment.appDisplayName(
        AppLocalizations.of(context)?.appTitle ?? 'HydrAzur Pro',
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) {
          return const Locale('fr');
        }
        for (final supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale.languageCode) {
            return supportedLocale;
          }
        }
        return const Locale('fr');
      },
      theme: baseTheme.copyWith(
        textTheme: baseTheme.textTheme.copyWith(
          titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
            letterSpacing: 0.05,
          ),
          titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
            letterSpacing: 0,
          ),
          titleSmall: baseTheme.textTheme.titleSmall?.copyWith(
            letterSpacing: 0,
          ),
          bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(letterSpacing: 0),
          bodyMedium:
              baseTheme.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
          bodySmall: baseTheme.textTheme.bodySmall?.copyWith(letterSpacing: 0),
          labelLarge:
              baseTheme.textTheme.labelLarge?.copyWith(letterSpacing: 0),
          labelMedium:
              baseTheme.textTheme.labelMedium?.copyWith(letterSpacing: 0),
          labelSmall:
              baseTheme.textTheme.labelSmall?.copyWith(letterSpacing: 0),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          isDense: true,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
        listTileTheme: const ListTileThemeData(
          visualDensity: VisualDensity(vertical: -1),
        ),
      ),
      home: SplashScreen(
        resolveNextPage: () async {
          final session = await AuthService.restoreSessionIfNeeded(
            settings: AppStore.cloudSyncSettings,
          );
          if (AuthService.requiresSession(AppStore.cloudSyncSettings)) {
            if (session == null) {
              return const LoginPage(
                resolveAuthenticatedPage: resolveAuthenticatedEntryPage,
              );
            }
            return resolveAuthenticatedEntryPage();
          }
          return const HomePage();
        },
      ),
    );
  }
}

class AppStore {
  static const String _legacyStorageKey = 'ac_piscine_pro_clients_v1';
  static const String _legacyPricingStorageKey = 'ac_piscine_pro_pricing_v1';
  static const String _legacyStorageFileName = 'clients.json';
  static const String _legacyPricingFileName = 'pricing_settings.json';
  static const String _legacyCompanyProfileFileName = 'company_profile.json';
  static const String _legacyTeamMembersFileName = 'team_members.json';
  static const String _legacyCloudSyncFileName = 'cloud_sync.json';
  static const String _legacyWorkspaceSettingsFileName =
      'workspace_settings.json';
  static const String _legacySubscriptionFileName = 'subscription.json';
  static const String _legacyPlansFileName = 'plans.json';
  static const String _legacyOnboardingProgressFileName =
      'onboarding_progress.json';
  static const String _legacyVisitPlansFileName = 'visit_plans.json';
  static String get storageKey => AppEnvironment.storageName(_legacyStorageKey);
  static String get pricingStorageKey =>
      AppEnvironment.storageName(_legacyPricingStorageKey);
  static String get storageFileName =>
      AppEnvironment.storageName(_legacyStorageFileName);
  static String get pricingFileName =>
      AppEnvironment.storageName(_legacyPricingFileName);
  static String get companyProfileFileName =>
      AppEnvironment.storageName(_legacyCompanyProfileFileName);
  static String get teamMembersFileName =>
      AppEnvironment.storageName(_legacyTeamMembersFileName);
  static String get cloudSyncFileName =>
      AppEnvironment.storageName(_legacyCloudSyncFileName);
  static String get workspaceSettingsFileName =>
      AppEnvironment.storageName(_legacyWorkspaceSettingsFileName);
  static String get subscriptionFileName =>
      AppEnvironment.storageName(_legacySubscriptionFileName);
  static String get plansFileName =>
      AppEnvironment.storageName(_legacyPlansFileName);
  static String get onboardingProgressFileName =>
      AppEnvironment.storageName(_legacyOnboardingProgressFileName);
  static String get visitPlansFileName =>
      AppEnvironment.storageName(_legacyVisitPlansFileName);
  static List<Client> clients = [];
  static PricingSettings pricingSettings = PricingSettings.defaults();
  static CompanyProfile companyProfile = CompanyProfile.defaults();
  static List<TeamMember> teamMembers = [];
  static CloudSyncSettings cloudSyncSettings = CloudSyncSettings.defaults();
  static WorkspaceSettings workspaceSettings = WorkspaceSettings.defaults();
  static Subscription subscription = Subscription.defaults();
  static List<Plan> plans = Plan.catalog;
  static OnboardingProgress onboardingProgress = OnboardingProgress.defaults();
  static List<VisitPlan> visitPlans = [];
  static List<Client> get activeClients =>
      clients.where((client) => !client.isDeleted).toList();
  static List<Plan> get availablePlans => plans.isEmpty ? Plan.catalog : plans;

  static void resetInMemory() {
    clients = [];
    pricingSettings = PricingSettings.defaults();
    companyProfile = CompanyProfile.defaults();
    teamMembers = [];
    cloudSyncSettings = CloudSyncSettings.defaults();
    workspaceSettings = WorkspaceSettings.defaults();
    subscription = Subscription.defaults();
    plans = Plan.catalog;
    onboardingProgress = OnboardingProgress.defaults();
    visitPlans = [];
    OnboardingProgressService.resetInMemory();
    SyncQueueService.resetInMemory();
  }

  static Future<void> load() async {
    final storedClients = await _readJsonListWithLegacyFallback(
      storageFileName,
      _legacyStorageFileName,
    );
    final storedPricing = await _readJsonMapWithLegacyFallback(
      pricingFileName,
      _legacyPricingFileName,
    );
    final storedCompany = await _readJsonMapWithLegacyFallback(
      companyProfileFileName,
      _legacyCompanyProfileFileName,
    );
    final storedTeam = await _readJsonListWithLegacyFallback(
      teamMembersFileName,
      _legacyTeamMembersFileName,
    );
    final storedCloud = await _readJsonMapWithLegacyFallback(
      cloudSyncFileName,
      _legacyCloudSyncFileName,
    );
    final storedWorkspaceSettings = await _readJsonMapWithLegacyFallback(
      workspaceSettingsFileName,
      _legacyWorkspaceSettingsFileName,
    );
    final storedSubscription = await _readJsonMapWithLegacyFallback(
      subscriptionFileName,
      _legacySubscriptionFileName,
    );
    final storedPlans = await _readJsonListWithLegacyFallback(
      plansFileName,
      _legacyPlansFileName,
    );
    final storedOnboardingProgress = await _readJsonMapWithLegacyFallback(
      onboardingProgressFileName,
      _legacyOnboardingProgressFileName,
    );
    final storedVisitPlans = await _readJsonListWithLegacyFallback(
      visitPlansFileName,
      _legacyVisitPlansFileName,
    );

    if (storedClients != null) {
      clients = storedClients
          .map((e) => Client.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else {
      await _migrateLegacyClients();
    }

    if (storedPricing != null) {
      pricingSettings = PricingSettings.fromJson(storedPricing);
    } else {
      await _migrateLegacyPricing();
    }

    companyProfile = storedCompany == null
        ? CompanyProfile.defaults()
        : CompanyProfile.fromJson(storedCompany);
    teamMembers = storedTeam == null
        ? []
        : storedTeam
            .map(
                (e) => TeamMember.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
    cloudSyncSettings = storedCloud == null
        ? CloudSyncSettings.defaults()
        : CloudSyncSettings.fromJson(storedCloud);
    if (storedCloud != null) {
      final legacyApiKey = CloudSyncSettings.extractLegacyApiKey(storedCloud);
      final didImportLegacyApiKey =
          await SecureStorageService.importLegacyCloudSyncApiKeyIfNeeded(
        legacyApiKey,
      );
      if (didImportLegacyApiKey || storedCloud.containsKey('apiKey')) {
        await saveCloudSyncSettings();
      }
    }
    workspaceSettings = storedWorkspaceSettings == null
        ? WorkspaceSettings.defaults()
        : WorkspaceSettings.fromJson(storedWorkspaceSettings);
    subscription = storedSubscription == null
        ? Subscription.defaults()
        : Subscription.fromJson(storedSubscription);
    plans = storedPlans == null
        ? Plan.catalog
        : Plan.catalogFromJsonList(storedPlans);
    onboardingProgress = storedOnboardingProgress == null
        ? await OnboardingProgressService.load()
        : OnboardingProgress.fromJson(storedOnboardingProgress);
    await OnboardingProgressService.replace(onboardingProgress);
    visitPlans = storedVisitPlans == null
        ? []
        : storedVisitPlans
            .map((item) => VisitPlan.fromJson(Map<String, dynamic>.from(item)))
            .toList();
  }

  static Future<void> save() async {
    await LocalStorageService.writeJson(
      storageFileName,
      clients.map((e) => e.toJson()).toList(),
    );
  }

  static Future<void> clearLocalData() async {
    await LocalStorageService.clearAllApplicationData();
    await SecureStorageService.clearAllAppSecrets();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    await prefs.remove(pricingStorageKey);
    if (storageKey != _legacyStorageKey) {
      await prefs.remove(_legacyStorageKey);
    }
    if (pricingStorageKey != _legacyPricingStorageKey) {
      await prefs.remove(_legacyPricingStorageKey);
    }
    resetInMemory();
    await AuthService.logout(
      clearStoredSession: () async {},
    );
  }

  static Future<void> savePricingSettings() async {
    await LocalStorageService.writeJson(
      pricingFileName,
      pricingSettings.toJson(),
    );
  }

  static Future<void> saveCompanyProfile() async {
    await LocalStorageService.writeJson(
      companyProfileFileName,
      companyProfile.toJson(),
    );
  }

  static Future<void> saveTeamMembers() async {
    await LocalStorageService.writeJson(
      teamMembersFileName,
      teamMembers.map((member) => member.toJson()).toList(),
    );
  }

  static Future<void> saveCloudSyncSettings() async {
    await LocalStorageService.writeJson(
      cloudSyncFileName,
      cloudSyncSettings.toJson(),
    );
  }

  static Future<void> saveWorkspaceSettings() async {
    await LocalStorageService.writeJson(
      workspaceSettingsFileName,
      workspaceSettings.toJson(),
    );
  }

  static Future<void> saveSubscription() async {
    await LocalStorageService.writeJson(
      subscriptionFileName,
      subscription.toJson(),
    );
  }

  static Future<void> savePlans() async {
    await LocalStorageService.writeJson(
      plansFileName,
      plans.map((plan) => plan.toJson()).toList(),
    );
  }

  static Future<void> saveOnboardingProgress() async {
    onboardingProgress = OnboardingProgressService.current.value;
    await LocalStorageService.writeJson(
      onboardingProgressFileName,
      onboardingProgress.toJson(),
    );
  }

  static Future<void> saveVisitPlans() async {
    await LocalStorageService.writeJson(
      visitPlansFileName,
      visitPlans.map((plan) => plan.toJson()).toList(),
    );
  }

  static Map<String, dynamic> exportPayload() {
    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'companyProfile': companyProfile.toJson(),
      'pricingSettings': pricingSettings.toJson(),
      'teamMembers': teamMembers.map((member) => member.toJson()).toList(),
      'cloudSyncSettings': cloudSyncSettings.toJson(),
      'workspaceSettings': workspaceSettings.toJson(),
      'subscription': subscription.toJson(),
      'plans': plans.map((plan) => plan.toJson()).toList(),
      'onboardingProgress': OnboardingProgressService.current.value.toJson(),
      'visitPlans': visitPlans.map((plan) => plan.toJson()).toList(),
      'clients': clients.map((client) => client.toJson()).toList(),
    };
  }

  static Future<void> importPayload(Map<String, dynamic> payload) async {
    final importedClients = ((payload['clients'] ?? []) as List)
        .map((item) => Client.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    clients = SyncMergeService.mergeClients(
      existing: clients,
      incoming: importedClients,
    );

    if (payload['pricingSettings'] is Map) {
      pricingSettings = PricingSettings.fromJson(
        Map<String, dynamic>.from(payload['pricingSettings']),
      );
    }

    if (payload['companyProfile'] is Map) {
      companyProfile = CompanyProfile.fromJson(
        Map<String, dynamic>.from(payload['companyProfile']),
      );
    }

    if (payload['teamMembers'] is List) {
      teamMembers = (payload['teamMembers'] as List)
          .map((item) => TeamMember.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    if (payload['cloudSyncSettings'] is Map) {
      cloudSyncSettings = CloudSyncSettings.fromJson(
        Map<String, dynamic>.from(payload['cloudSyncSettings']),
      );
    }

    if (payload['workspaceSettings'] is Map) {
      workspaceSettings = WorkspaceSettings.fromJson(
        Map<String, dynamic>.from(payload['workspaceSettings']),
      );
    }

    if (payload['subscription'] is Map) {
      subscription = Subscription.fromJson(
        Map<String, dynamic>.from(payload['subscription']),
      );
    }

    if (payload['plans'] is List) {
      plans = Plan.catalogFromJsonList(payload['plans'] as List);
    }

    if (payload['onboardingProgress'] is Map) {
      onboardingProgress = OnboardingProgress.fromJson(
        Map<String, dynamic>.from(payload['onboardingProgress']),
      );
      await OnboardingProgressService.replace(onboardingProgress);
    }
    if (payload['visitPlans'] is List) {
      visitPlans = (payload['visitPlans'] as List)
          .map((item) => VisitPlan.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    await save();
    await savePricingSettings();
    await saveCompanyProfile();
    await saveTeamMembers();
    await saveCloudSyncSettings();
    await saveWorkspaceSettings();
    await saveSubscription();
    await savePlans();
    await saveOnboardingProgress();
    await saveVisitPlans();
  }

  static Future<void> _migrateLegacyClients() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    final fallbackRaw = storageKey == _legacyStorageKey
        ? null
        : prefs.getString(_legacyStorageKey);
    final resolvedRaw = (raw != null && raw.isNotEmpty) ? raw : fallbackRaw;
    if (resolvedRaw == null || resolvedRaw.isEmpty) {
      clients = [];
      return;
    }

    final List<dynamic> decoded = jsonDecode(resolvedRaw);
    clients = decoded
        .map((e) => Client.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    await save();
  }

  static Future<void> _migrateLegacyPricing() async {
    final prefs = await SharedPreferences.getInstance();
    final rawPricing = prefs.getString(pricingStorageKey);
    final fallbackRawPricing = pricingStorageKey == _legacyPricingStorageKey
        ? null
        : prefs.getString(_legacyPricingStorageKey);
    final resolvedRawPricing = (rawPricing != null && rawPricing.isNotEmpty)
        ? rawPricing
        : fallbackRawPricing;
    if (resolvedRawPricing == null || resolvedRawPricing.isEmpty) {
      pricingSettings = PricingSettings.defaults();
      return;
    }

    pricingSettings = PricingSettings.fromJson(
      Map<String, dynamic>.from(jsonDecode(resolvedRawPricing)),
    );
    await savePricingSettings();
  }

  static Future<Map<String, dynamic>?> _readJsonMapWithLegacyFallback(
    String namespacedFileName,
    String legacyFileName,
  ) async {
    final namespaced =
        await LocalStorageService.readJsonMap(namespacedFileName);
    if (namespaced != null || namespacedFileName == legacyFileName) {
      return namespaced;
    }
    return LocalStorageService.readJsonMap(legacyFileName);
  }

  static Future<List<dynamic>?> _readJsonListWithLegacyFallback(
    String namespacedFileName,
    String legacyFileName,
  ) async {
    final namespaced =
        await LocalStorageService.readJsonList(namespacedFileName);
    if (namespaced != null || namespacedFileName == legacyFileName) {
      return namespaced;
    }
    return LocalStorageService.readJsonList(legacyFileName);
  }
}

String formatDate(String iso) {
  return FormattingService.formatDateTimeFromIso(
      iso, AppStore.workspaceSettings);
}

String formatShortDate(DateTime date) {
  return FormattingService.formatDate(date, AppStore.workspaceSettings);
}

String subscriptionStatusLabel(Subscription subscription) {
  switch (subscription.status) {
    case SubscriptionStatus.trial:
      return 'Essai';
    case SubscriptionStatus.active:
      return 'Actif';
    case SubscriptionStatus.pastDue:
      return 'Paiement en attente';
    case SubscriptionStatus.canceled:
      return 'Annulé';
    case SubscriptionStatus.expired:
      return 'Expiré';
  }
}

String planDisplayLabel(Plan plan) {
  switch (plan.id) {
    case 'free':
      return 'Gratuit';
    case 'pro':
      return 'Pro';
    default:
      return plan.displayName;
  }
}

String visibleSubscriptionPlanLabel(Subscription subscription) {
  if (!AuthService.isAuthenticated) {
    return 'Non connecté';
  }
  return planDisplayLabel(subscription.plan);
}

String userVisibleSyncMessage(String rawMessage) {
  final message = rawMessage.trim();
  if (message.isEmpty) {
    return '';
  }
  final normalized = message.toLowerCase();
  if (normalized.contains('media') && normalized.contains('indisponibles')) {
    return 'Synchronisation terminée. Certaines pièces jointes restent disponibles sur cet appareil.';
  }
  if (normalized.contains('erreur http') ||
      normalized.contains('invalide') ||
      normalized.contains('impossible')) {
    return 'Synchronisation impossible pour le moment. Réessayez plus tard.';
  }
  if (normalized.contains('pieces jointes') ||
      normalized.contains('pièces jointes')) {
    return 'Synchronisation des pièces jointes terminée.';
  }
  if (normalized.contains('synchronise') ||
      normalized.contains('synchronisé')) {
    return 'Synchronisation terminée.';
  }
  return message
      .replaceAll('V2', '')
      .replaceAll('v2', '')
      .replaceAll('backend', 'cloud')
      .replaceAll('Backend', 'Cloud')
      .replaceAll('fallback local conserve', '')
      .replaceAll('fallback local', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(' .', '.')
      .trim();
}

String subscriptionSummaryLabel(Subscription subscription) {
  final planName = planDisplayLabel(subscription.plan);
  final statusLabel = subscriptionStatusLabel(subscription);
  final parts = <String>['$planName • $statusLabel'];
  if (subscription.startedAtIso.isNotEmpty) {
    parts.add(
        'Début ${FormattingService.formatDateFromIso(subscription.startedAtIso, AppStore.workspaceSettings)}');
  }
  if (subscription.endedAtIso.isNotEmpty) {
    parts.add(
        'Fin ${FormattingService.formatDateFromIso(subscription.endedAtIso, AppStore.workspaceSettings)}');
  }
  return parts.join(' • ');
}

String subscriptionUserOfferMessage(Subscription subscription) {
  if (!AuthService.isAuthenticated) {
    return 'Connectez-vous pour vérifier votre abonnement.';
  }
  if (subscription.planId == 'pro' &&
      (subscription.isActive ||
          subscription.isTrial ||
          subscription.isCanceled)) {
    return 'Votre offre Pro est active.';
  }
  return 'Certaines fonctions avancées sont disponibles avec l’offre Pro.';
}

Future<void> clearServerSubscriptionState() async {
  AppStore.subscription = Subscription.defaults();
  AppStore.plans = Plan.catalog;
  await AppStore.saveSubscription();
  await AppStore.savePlans();
}

DateTime? nextVisitDateForClient(Client client) {
  return VisitPlanningService.nextVisitDateForClient(
    client: client,
    plans: AppStore.visitPlans,
  );
}

String nextVisitLabel(Client client) {
  if (client.requiresFirstVisit) {
    return 'Première analyse à planifier';
  }

  final next = nextVisitDateForClient(client);
  if (next == null) {
    return 'Suivi non planifié';
  }

  final today = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);
  final startOfNext = DateTime(next.year, next.month, next.day);
  final days = startOfNext.difference(startOfToday).inDays;

  if (days < 0) {
    return 'Suivi en retard depuis ${formatShortDate(next)}';
  }
  if (days == 0) {
    return 'Suivi prévu aujourd’hui';
  }
  if (days <= 3) {
    return 'Suivi à faire sous $days jour${days > 1 ? 's' : ''}';
  }
  return 'Prochaine visite le ${formatShortDate(next)}';
}

Color nextVisitColor(Client client) {
  if (client.requiresFirstVisit) {
    return const Color(0xFF0F6E7C);
  }
  final next = nextVisitDateForClient(client);
  if (next == null) {
    return const Color(0xFF667085);
  }
  final today = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);
  final startOfNext = DateTime(next.year, next.month, next.day);
  final days = startOfNext.difference(startOfToday).inDays;
  if (days < 0) {
    return const Color(0xFFB42318);
  }
  if (days <= 3) {
    return const Color(0xFFB54708);
  }
  return const Color(0xFF027A48);
}

Future<void> saveInterventionForClient(
  Client client,
  InterventionRecord record,
) async {
  final nowIso = SyncMergeService.nowIso();
  final normalized = record.copyWith(
    updatedAtIso: nowIso,
    version: record.version <= 0 ? 1 : record.version,
    deletedAtIso: '',
    attachments: record.attachments
        .map(
          (attachment) => attachment.copyWith(
            updatedAtIso: nowIso,
            version: attachment.version <= 0 ? 1 : attachment.version,
            deletedAtIso: '',
          ),
        )
        .toList(),
  );
  client.interventions = SyncMergeService.mergeInterventions(
    existing: client.interventions,
    incoming: [normalized],
  );
  AppStore.visitPlans = VisitPlanningService.advancePlanForClient(
    existing: AppStore.visitPlans,
    clientId: client.id,
    completedAt: DateTime.tryParse(normalized.createdAtIso)?.toLocal(),
  );
  await AppStore.save();
  await AppStore.saveVisitPlans();
  unawaited(
    AppLogger.event(
      'intervention_created',
      category: 'business',
      data: {
        'clientId': client.id,
        'clientName': client.name,
        'interventionId': normalized.id,
        'attachmentsCount': normalized.attachments.length,
      },
    ),
  );
}

Future<void> saveFinancialDocumentForClient(
  Client client,
  FinancialDocument document,
) async {
  final nowIso = SyncMergeService.nowIso();
  client.financialDocuments = SyncMergeService.mergeFinancialDocuments(
    existing: client.financialDocuments,
    incoming: [
      document.copyWith(
        updatedAtIso: nowIso,
        version: document.version <= 0 ? 1 : document.version,
        deletedAtIso: '',
      ),
    ],
  );
  await AppStore.save();
}

Future<void> updateFinancialDocumentForClient(
  Client client,
  FinancialDocument document,
) async {
  final index =
      client.financialDocuments.indexWhere((item) => item.id == document.id);
  if (index == -1) return;
  client.financialDocuments[index] = document.copyWith(
    updatedAtIso: SyncMergeService.nowIso(),
    version: SyncMergeService.nextVersion(document.version),
  );
  await AppStore.save();
}

bool isFeatureEnabled(EntitlementFlag flag) {
  return FeatureGate.isEnabled(AppStore.subscription, flag);
}

Future<void> showFeatureBlockedSnackBar(
  BuildContext context,
  EntitlementFlag flag, {
  Subscription? subscription,
}) {
  if (!AuthService.isAuthenticated) {
    return showModalBottomSheet<void>(
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
                const Text(
                  'Connexion requise',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connectez-vous pour vérifier votre abonnement et activer les fonctions Pro.',
                  style: TextStyle(
                    color: Color(0xFF475467),
                    height: 1.4,
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
                              builder: (_) => const LoginPage(
                                resolveAuthenticatedPage:
                                    resolveAuthenticatedEntryPage,
                              ),
                            ),
                          );
                        },
                        child: const Text('Se connecter'),
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
  unawaited(
    AppLogger.event(
      'paywall_opened',
      category: 'billing',
      data: {
        'feature': flag.name,
        'planId': (subscription ?? AppStore.subscription).planId,
      },
    ),
  );
  return showUpgradePaywall(
    context,
    subscription: subscription ?? AppStore.subscription,
    availablePlans: AppStore.availablePlans,
    flag: flag,
    onSnapshotChanged: (snapshot) async {
      AppStore.plans = snapshot.plans.isEmpty ? Plan.catalog : snapshot.plans;
      AppStore.subscription = snapshot.subscription;
      await AppStore.savePlans();
      await AppStore.saveSubscription();
    },
  );
}

class InterventionPhotoItem {
  final InterventionRecord intervention;
  final MediaAttachment attachment;

  const InterventionPhotoItem({
    required this.intervention,
    required this.attachment,
  });

  String get path => attachment.localPath;
}

List<InterventionPhotoItem> collectClientPhotos(Client client) {
  final photos = <InterventionPhotoItem>[];

  for (final intervention in client.interventions) {
    if (intervention.isDeleted) continue;
    for (final attachment in intervention.attachments.where(
      (item) => item.hasLocalPath && !item.isDeleted,
    )) {
      photos.add(
        InterventionPhotoItem(
          intervention: intervention,
          attachment: attachment,
        ),
      );
    }
  }

  photos.sort((a, b) {
    final dateA =
        DateTime.tryParse(a.intervention.createdAtIso) ?? DateTime(1970);
    final dateB =
        DateTime.tryParse(b.intervention.createdAtIso) ?? DateTime(1970);
    return dateB.compareTo(dateA);
  });

  return photos;
}

class ActivitySummary {
  final int totalClients;
  final int firstVisits;
  final int overdueVisits;
  final int urgentPools;
  final int visitsThisWeek;

  const ActivitySummary({
    required this.totalClients,
    required this.firstVisits,
    required this.overdueVisits,
    required this.urgentPools,
    required this.visitsThisWeek,
  });
}

ActivitySummary buildActivitySummary(List<Client> clients) {
  final now = DateTime.now();
  final endOfWeek = now.add(const Duration(days: 7));

  var firstVisits = 0;
  var overdueVisits = 0;
  var urgentPools = 0;
  var visitsThisWeek = 0;

  for (final client in clients) {
    if (client.requiresFirstVisit) {
      firstVisits += 1;
    }
    final next = nextVisitDateForClient(client);
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfNext =
        next == null ? null : DateTime(next.year, next.month, next.day);
    if (startOfNext != null && startOfNext.isBefore(startOfToday)) {
      overdueVisits += 1;
    }
    final latest = client.latestAnalysis;
    if (latest != null && latest.score < 5) {
      urgentPools += 1;
    }
    if (next != null &&
        next.isAfter(now.subtract(const Duration(days: 1))) &&
        next.isBefore(endOfWeek.add(const Duration(days: 1)))) {
      visitsThisWeek += 1;
    }
  }

  return ActivitySummary(
    totalClients: clients.length,
    firstVisits: firstVisits,
    overdueVisits: overdueVisits,
    urgentPools: urgentPools,
    visitsThisWeek: visitsThisWeek,
  );
}

List<String> buildDiagnosis(Client client, WaterAnalysis a) {
  final List<String> lines = [];

  if (a.ph > 7.6) {
    lines.add(
      "pH trop eleve (${a.ph.toStringAsFixed(1)}) : desinfection moins efficace, risque deau trouble et de depots.",
    );

    if (a.ph > 7.8) {
      lines.add(
        "pH tres eleve : verifier le systeme dinjection pH-, et controler letalonnage de la sonde.",
      );
    }
  } else if (a.ph < 7.2) {
    lines.add(
      "pH trop bas (${a.ph.toStringAsFixed(1)}) : eau agressive, inconfort possible et consommation de produit plus importante.",
    );
  } else {
    lines.add(
      "pH correct (${a.ph.toStringAsFixed(1)}) : zone equilibree.",
    );
  }

  if (a.chlore < 1.0) {
    lines.add(
      "Chlore insuffisant (${a.chlore.toStringAsFixed(1)} ppm) : risque de algues et degradation rapide de la qualite de leau.",
    );
  } else if (a.chlore > 3.0) {
    lines.add(
      "Chlore trop eleve (${a.chlore.toStringAsFixed(1)} ppm) : eau potentiellement irritante, attendre avant nouvel apport.",
    );
  } else {
    lines.add(
      "Chlore correct (${a.chlore.toStringAsFixed(1)} ppm) : desinfection satisfaisante.",
    );
  }

  if (a.tac > 120) {
    lines.add(
      "TAC trop eleve (${a.tac.toStringAsFixed(0)} ppm) : tendance du pH a remonter, equilibre plus difficile a stabiliser.",
    );
  } else if (a.tac < 80) {
    lines.add(
      "TAC trop bas (${a.tac.toStringAsFixed(0)} ppm) : pH instable, risque de variations rapides.",
    );
  } else {
    lines.add(
      "TAC correct (${a.tac.toStringAsFixed(0)} ppm) : bon pouvoir tampon.",
    );
  }

  if (a.th > 250) {
    lines.add(
      "TH eleve (${a.th.toStringAsFixed(0)} ppm) : risque de depots calcaires et deau terne.",
    );
  } else if (a.th < 150) {
    lines.add(
      "TH bas (${a.th.toStringAsFixed(0)} ppm) : eau peu mineralisee, a surveiller.",
    );
  } else {
    lines.add(
      "TH correct (${a.th.toStringAsFixed(0)} ppm) : equilibre calcaire satisfaisant.",
    );
  }

  if (a.stabilisant > 70) {
    lines.add(
      "Stabilisant trop eleve (${a.stabilisant.toStringAsFixed(0)} ppm) : efficacite du chlore reduite, renouvellement deau conseille.",
    );
  } else if (a.stabilisant < 30) {
    lines.add(
      "Stabilisant trop bas (${a.stabilisant.toStringAsFixed(0)} ppm) : protection UV insuffisante, le chlore se detruit plus vite.",
    );
  } else {
    lines.add(
      "Stabilisant correct (${a.stabilisant.toStringAsFixed(0)} ppm) : zone acceptable.",
    );
  }

  if (a.observation.toLowerCase().contains('verte') ||
      a.observation.toLowerCase().contains('algue')) {
    lines.add(
      "Observation terrain : presence deau verte ou de algues probable. Une action rapide est necessaire.",
    );
  }

  if (a.ph > 7.6 && a.chlore < 1.0) {
    lines.add(
      "Le bassin presente une desinfection insuffisante aggravee par un pH trop eleve. Le chlore agit mal tant que le pH nest pas corrige.",
    );
  }

  if (a.th > 250 && a.ph > 7.6) {
    lines.add(
      "Le couple TH eleve + pH eleve favorise lentartrage. Le risque de depots calcaires est renforce.",
    );
  }

  if (a.tac > 120 && a.ph > 7.6) {
    lines.add(
      "Le bassin presente une tendance structurelle a la hausse du pH. Sans correction de lalcalinite, les desequilibres reviennent rapidement.",
    );
  }

  return lines;
}

List<String> buildIntervention(Client client, WaterAnalysis a) {
  final List<String> actions = [];

  // pH trop élevé
  if (a.ph > 7.6) {
    actions.add(
      "Injection de pH- pour retour zone 7.2 – 7.4.",
    );

    actions.add(
      "Verifier l’etalonnage de la sonde pH. Recalibrage ou remplacement si necessaire.",
    );
  }

  // pH trop bas
  if (a.ph < 7.2) {
    actions.add(
      "Injection de pH+ pour stabilisation.",
    );
  }

  // Chlore insuffisant
  if (a.chlore < 1.5) {
    actions.add(
      "Apport de chlore choc ou ajustement production electrolyseur.",
    );
  }

  // Stabilisant trop élevé
  if (a.stabilisant > 70) {
    actions.add(
      "Renouvellement partiel du bassin recommande.",
    );
  }

  return actions;
}

Future<Uint8List> buildClientReportPdf(Client client) async {
  final pdf = pw.Document();
  final analyses = client.analyses.reversed.toList();
  final company = AppStore.companyProfile;

  final regularFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
  );

  final boldFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
  );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
      build: (context) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#0F6E7C'),
            borderRadius: pw.BorderRadius.circular(14),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                company.companyName,
                style: pw.TextStyle(
                  font: boldFont,
                  color: PdfColors.white,
                  fontSize: 24,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Rapport client',
                style: pw.TextStyle(
                  font: regularFont,
                  color: PdfColors.white,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        if (company.phone.isNotEmpty ||
            company.email.isNotEmpty ||
            company.address.isNotEmpty ||
            company.website.isNotEmpty ||
            company.hasBusinessRegistration ||
            company.hasTaxRegistration)
          _pdfCard(
            title: 'Entreprise',
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (company.phone.isNotEmpty)
                  _pdfLine('Téléphone', company.phone),
                if (company.email.isNotEmpty) _pdfLine('Email', company.email),
                if (company.address.isNotEmpty)
                  _pdfLine('Adresse', company.address),
                if (company.website.isNotEmpty)
                  _pdfLine('Site', company.website),
                if (company.hasBusinessRegistration)
                  _pdfLine(
                    company.businessRegistrationDisplayLabel,
                    company.businessRegistrationValue,
                  ),
                if (company.hasTaxRegistration)
                  _pdfLine('Identifiant fiscal', company.taxRegistrationValue),
              ],
            ),
          ),
        if (company.phone.isNotEmpty ||
            company.email.isNotEmpty ||
            company.address.isNotEmpty ||
            company.website.isNotEmpty ||
            company.hasBusinessRegistration ||
            company.hasTaxRegistration)
          pw.SizedBox(height: 12),
        _pdfCard(
          title: 'Informations client',
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfLine('Nom', client.name),
              _pdfLine('Téléphone', client.phone.isEmpty ? '-' : client.phone),
              _pdfLine('Email', client.email.isEmpty ? '-' : client.email),
              _pdfLine(
                  'Adresse', client.address.isEmpty ? '-' : client.address),
              _pdfLine('Volume', '${client.volume.toStringAsFixed(1)} m3'),
              _pdfLine(
                'Traitement',
                client.treatment.isEmpty ? '-' : client.treatment,
              ),
              _pdfLine(
                'Type de bassin',
                client.bassinType.isEmpty ? '-' : client.bassinType,
              ),
              _pdfLine(
                'Revêtement',
                client.revetement.isEmpty ? '-' : client.revetement,
              ),
              _pdfLine(
                'Filtration',
                client.filtration.isEmpty ? '-' : client.filtration,
              ),
              _pdfLine(
                'Suivi',
                nextVisitLabel(client),
              ),
              _pdfLine('Nombre d’analyses', client.analyses.length.toString()),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        _pdfCard(
          title: 'Configuration bassin',
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfLine(
                'Équipements',
                client.equipements.isEmpty ? '-' : client.equipements,
              ),
              _pdfLine(
                'Rythme de passage',
                '${client.visitFrequencyDays} jours',
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        _pdfCard(
          title: 'Notes',
          child: pw.Text(client.notes.isEmpty ? 'Aucune note' : client.notes),
        ),
        pw.SizedBox(height: 12),
        _pdfCard(
          title: 'Historique des analyses',
          child: analyses.isEmpty
              ? pw.Text('Aucune analyse')
              : pw.TableHelper.fromTextArray(
                  headers: [
                    'Date',
                    'pH',
                    'Chlore',
                    'TAC',
                    'TH',
                    'Stab',
                    'Score'
                  ],
                  data: analyses
                      .map((a) => [
                            formatDate(a.dateIso),
                            a.ph.toStringAsFixed(1),
                            a.chlore.toStringAsFixed(1),
                            a.tac.toStringAsFixed(1),
                            a.th.toStringAsFixed(1),
                            a.stabilisant.toStringAsFixed(1),
                            '${a.score}/10',
                          ])
                      .toList(),
                  headerStyle: pw.TextStyle(
                    font: boldFont,
                    color: PdfColors.white,
                  ),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#0F6E7C'),
                  ),
                  cellStyle: pw.TextStyle(font: regularFont),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: const pw.EdgeInsets.all(6),
                ),
        ),
      ],
    ),
  );

  return pdf.save();
}

String sanitizeForPdf(String text) {
  return text
      // apostrophes / guillemets
      .replaceAll("’", "'")
      .replaceAll("‘", "'")
      .replaceAll("`", "'")
      .replaceAll("´", "'")
      .replaceAll("‛", "'")
      .replaceAll("“", '"')
      .replaceAll("”", '"')

      // tirets
      .replaceAll("–", "-")
      .replaceAll("—", "-")
      .replaceAll("−", "-")

      // puces / symboles
      .replaceAll("•", "-")
      .replaceAll("◦", "-")
      .replaceAll("▪", "-")
      .replaceAll("■", "-")

      // accents
      .replaceAll("é", "e")
      .replaceAll("è", "e")
      .replaceAll("ê", "e")
      .replaceAll("ë", "e")
      .replaceAll("É", "E")
      .replaceAll("È", "E")
      .replaceAll("Ê", "E")
      .replaceAll("Ë", "E")
      .replaceAll("à", "a")
      .replaceAll("â", "a")
      .replaceAll("ä", "a")
      .replaceAll("À", "A")
      .replaceAll("Â", "A")
      .replaceAll("Ä", "A")
      .replaceAll("ù", "u")
      .replaceAll("û", "u")
      .replaceAll("ü", "u")
      .replaceAll("Ù", "U")
      .replaceAll("Û", "U")
      .replaceAll("Ü", "U")
      .replaceAll("ô", "o")
      .replaceAll("ö", "o")
      .replaceAll("Ô", "O")
      .replaceAll("Ö", "O")
      .replaceAll("î", "i")
      .replaceAll("ï", "i")
      .replaceAll("Î", "I")
      .replaceAll("Ï", "I")
      .replaceAll("ç", "c")
      .replaceAll("Ç", "C")

      // caractères pourris / invisibles
      .replaceAll("\uFFFD", "") // <- le plus important
      .replaceAll("\u200B", "")
      .replaceAll("\u200C", "")
      .replaceAll("\u200D", "")
      .replaceAll("\u2060", "")
      .replaceAll("\u00A0", " ")
      .replaceAll("\uFEFF", "")

      // nettoyage final
      .replaceAll(RegExp(r"[^\x20-\x7E\n\r\t]"), "");
}

Future<Uint8List> buildInterventionPdf(Client client, WaterAnalysis a) async {
  final pdf = pw.Document();
  final company = AppStore.companyProfile;

  final regularFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
  );

  final boldFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
  );

  final diag = buildDiagnosis(client, a)
      .map((e) => sanitizeForPdf(e))
      .where((e) => e.trim().isNotEmpty)
      .toList();

  final interventions = buildIntervention(client, a)
      .map((e) => sanitizeForPdf(e))
      .where((e) => e.trim().isNotEmpty)
      .toList();

  final cleanClientName = sanitizeForPdf(client.name);
  final cleanTreatment =
      client.treatment.isEmpty ? '-' : sanitizeForPdf(client.treatment);
  final cleanPoolType =
      client.bassinType.isEmpty ? '-' : sanitizeForPdf(client.bassinType);
  final cleanCoating =
      client.revetement.isEmpty ? '-' : sanitizeForPdf(client.revetement);
  final cleanFiltration =
      client.filtration.isEmpty ? '-' : sanitizeForPdf(client.filtration);
  final cleanEquipment =
      client.equipements.isEmpty ? '-' : sanitizeForPdf(client.equipements);
  final cleanStatus = sanitizeForPdf(a.status);
  final cleanNotes =
      client.notes.isEmpty ? 'Aucune note' : sanitizeForPdf(client.notes);
  final cleanDate = sanitizeForPdf(formatDate(a.dateIso));

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
      build: (context) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#0F6E7C'),
            borderRadius: pw.BorderRadius.circular(14),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    company.companyName,
                    style: pw.TextStyle(
                      font: boldFont,
                      color: PdfColors.white,
                      fontSize: 24,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Fiche intervention',
                    style: pw.TextStyle(
                      font: regularFont,
                      color: PdfColors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(14),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Score eau',
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 10,
                        color: PdfColor.fromHex('#8A8A8A'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${a.score}/10',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 22,
                        color: PdfColor.fromHex('#C94A38'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 18),
        if (company.phone.isNotEmpty ||
            company.email.isNotEmpty ||
            company.address.isNotEmpty ||
            company.website.isNotEmpty ||
            company.hasBusinessRegistration ||
            company.hasTaxRegistration)
          _pdfCard(
            title: 'Entreprise',
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (company.phone.isNotEmpty)
                  _pdfLine('Téléphone', company.phone),
                if (company.email.isNotEmpty) _pdfLine('Email', company.email),
                if (company.address.isNotEmpty)
                  _pdfLine('Adresse', company.address),
                if (company.website.isNotEmpty)
                  _pdfLine('Site', company.website),
                if (company.hasBusinessRegistration)
                  _pdfLine(
                    company.businessRegistrationDisplayLabel,
                    company.businessRegistrationValue,
                  ),
                if (company.hasTaxRegistration)
                  _pdfLine('Identifiant fiscal', company.taxRegistrationValue),
              ],
            ),
          ),
        if (company.phone.isNotEmpty ||
            company.email.isNotEmpty ||
            company.address.isNotEmpty ||
            company.website.isNotEmpty ||
            company.hasBusinessRegistration ||
            company.hasTaxRegistration)
          pw.SizedBox(height: 14),
        _pdfCard(
          title: 'Client',
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfLine('Nom', cleanClientName),
              _pdfLine('Date', cleanDate),
              _pdfLine('Volume', '${client.volume.toStringAsFixed(1)} m3'),
              _pdfLine('Traitement', cleanTreatment),
              _pdfLine('Type de bassin', cleanPoolType),
              _pdfLine('Revêtement', cleanCoating),
              _pdfLine('Filtration', cleanFiltration),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        _pdfCard(
          title: 'Exploitation',
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfLine('Équipements', cleanEquipment),
              _pdfLine(
                  'Suivi conseillé', sanitizeForPdf(nextVisitLabel(client))),
              _pdfLine('Fréquence cible', '${client.visitFrequencyDays} jours'),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        _pdfCard(
          title: 'Mesures',
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfLine('pH', a.ph.toStringAsFixed(1)),
              _pdfLine('Chlore', '${a.chlore.toStringAsFixed(1)} ppm'),
              _pdfLine('TAC', '${a.tac.toStringAsFixed(1)} ppm'),
              _pdfLine('TH', '${a.th.toStringAsFixed(1)} ppm'),
              _pdfLine(
                  'Stabilisant', '${a.stabilisant.toStringAsFixed(1)} ppm'),
              _pdfLine('Etat', cleanStatus),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        _pdfCard(
          title: 'Diagnostic expert',
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: diag
                .map(
                  (e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Text(
                      "- ${sanitizeForPdf(e)}",
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        pw.SizedBox(height: 12),
        _pdfCard(
          title: 'Notes',
          child: pw.Text(cleanNotes),
        ),
        pw.SizedBox(height: 14),
        _pdfCard(
          title: 'Intervention proposee',
          child: interventions.isEmpty
              ? pw.Text("Aucune intervention necessaire")
              : pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: interventions
                      .map(
                        (e) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 8),
                          child: pw.Text(
                            "- $e",
                            style: pw.TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        pw.SizedBox(height: 12),
        _pdfCard(
          title: 'Historique des analyses',
          child: client.analyses.isEmpty
              ? pw.Text('Aucune analyse')
              : pw.TableHelper.fromTextArray(
                  headers: [
                    'Date',
                    'pH',
                    'Chlore',
                    'TAC',
                    'TH',
                    'Stab',
                    'Score',
                  ],
                  data: client.analyses
                      .map((item) => [
                            sanitizeForPdf(formatDate(item.dateIso)),
                            item.ph.toStringAsFixed(1),
                            item.chlore.toStringAsFixed(1),
                            item.tac.toStringAsFixed(1),
                            item.th.toStringAsFixed(1),
                            item.stabilisant.toStringAsFixed(1),
                            '${item.score}/10',
                          ])
                      .toList(),
                  headerStyle: pw.TextStyle(
                    font: boldFont,
                    color: PdfColors.white,
                  ),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#0F6E7C'),
                  ),
                  cellStyle: pw.TextStyle(font: regularFont),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: const pw.EdgeInsets.all(6),
                ),
        ),
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _pdfCard({required String title, required pw.Widget child}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColor.fromHex('#D9E1E5')),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 16,
          ),
        ),
        pw.SizedBox(height: 8),
        child,
      ],
    ),
  );
}

pw.Widget _pdfLine(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 110,
          child: pw.Text(
            '$label :',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(child: pw.Text(value)),
      ],
    ),
  );
}

enum ClientActionMode {
  view,
  edit,
  delete,
  analyse,
  photoDiagnosis,
  history,
  diagnostic,
  follow,
  planning,
}

enum ClientListFilter {
  all,
  due,
  urgent,
  newClients,
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    unawaited(processPendingSyncQueue());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        VisitReminderService.maybeShowReminder(
          context,
          dashboard: VisitPlanningService.buildDashboard(
            clients: AppStore.activeClients,
            plans: AppStore.visitPlans,
          ),
        ),
      );
    });
  }

  Future<void> _pushPage(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openOnboardingProfile() {
    return _pushPage(
      OnboardingPage(
        completedPageResolver: () async => const HomePage(),
      ),
    );
  }

  Future<void> _openFirstClientFlow() {
    return _pushPage(const ClientFormPage());
  }

  Future<void> _openFirstInterventionFlow() async {
    final client =
        OnboardingChecklistService.preferredClientForFirstIntervention(
      AppStore.activeClients,
    );
    if (client == null) {
      await _openFirstClientFlow();
      return;
    }
    await _pushPage(AnalysisFormPage(client: client));
  }

  Future<void> _openFirstPdfFlow() async {
    if (!isFeatureEnabled(EntitlementFlag.pdfExport)) {
      await showFeatureBlockedSnackBar(context, EntitlementFlag.pdfExport);
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final target = OnboardingChecklistService.latestInterventionTarget(
      AppStore.activeClients,
    );
    if (target == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Commencez par enregistrer une première intervention.',
          ),
        ),
      );
      return;
    }

    final photoBytes = <Uint8List>[];
    for (final attachment in target.intervention.attachments
        .where(
          (item) => item.hasLocalPath,
        )
        .take(PdfService.maxEmbeddedPhotos)) {
      final bytes = await LocalStorageService.readBinary(attachment.localPath);
      if (bytes != null) {
        photoBytes.add(Uint8List.fromList(bytes));
      }
    }
    final pdf = await PdfService.generateInterventionTicketPdf(
      companyProfile: AppStore.companyProfile,
      ticket: target.intervention.toTicketData(target.client.name),
      signatureBytes: target.intervention.signatureBytes,
      photoBytes: photoBytes,
    );
    if (!mounted) return;

    await Printing.layoutPdf(
      onLayout: (_) async => pdf,
      name: 'onboarding_${target.client.name}_${target.intervention.id}.pdf',
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openCloudLogin() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(
          resolveAuthenticatedPage: resolveAuthenticatedEntryPage,
        ),
      ),
    );
    if (mounted && result != null) {
      setState(() {});
    }
  }

  Future<void> _handleOnboardingStep(OnboardingStepId stepId) {
    switch (stepId) {
      case OnboardingStepId.companyProfile:
        return _openOnboardingProfile();
      case OnboardingStepId.firstClient:
        return _openFirstClientFlow();
      case OnboardingStepId.firstIntervention:
        return _openFirstInterventionFlow();
      case OnboardingStepId.firstPdf:
        return _openFirstPdfFlow();
    }
  }

  Future<void> _dismissChecklist() async {
    await OnboardingProgressService.dismissChecklist();
    AppStore.onboardingProgress = OnboardingProgressService.current.value;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _resumeChecklist() async {
    await OnboardingProgressService.resumeChecklist();
    AppStore.onboardingProgress = OnboardingProgressService.current.value;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = buildActivitySummary(AppStore.activeClients);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: const Color(0xFFF3F7FB),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.18,
              child: Image.asset(
                'assets/bg.PNG',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              color: const Color(0xFFF3F7FB).withValues(alpha: 0.78),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: ValueListenableBuilder<OnboardingProgress>(
                valueListenable: OnboardingProgressService.current,
                builder: (context, progress, _) {
                  AppStore.onboardingProgress = progress;
                  final checklistState = OnboardingChecklistService.build(
                    companyProfile: AppStore.companyProfile,
                    workspaceSettings: AppStore.workspaceSettings,
                    clients: AppStore.activeClients,
                    subscription: AppStore.subscription,
                    progress: progress,
                  );

                  return Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'HydrAzur Pro',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF163C57),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'L’outil terrain des piscinistes',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF5B7183),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFDCE5EC)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: IconButton(
                              tooltip: 'Réglages',
                              icon: const Icon(
                                Icons.settings_suggest_rounded,
                                color: Color(0xFF184663),
                              ),
                              onPressed: () => _pushPage(
                                const PricingSettingsPage(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSummaryPanel(summary),
                              const SizedBox(height: 16),
                              if (!AuthService.isAuthenticated) ...[
                                _buildCloudAccountCard(),
                                const SizedBox(height: 16),
                              ],
                              _buildSyncStatusCard(),
                              const SizedBox(height: 16),
                              if (checklistState.hasOutstandingSteps &&
                                  !checklistState.dismissed)
                                _buildOnboardingChecklistCard(checklistState),
                              if (checklistState.hasOutstandingSteps &&
                                  checklistState.dismissed)
                                _buildOnboardingResumeCard(),
                              if (checklistState.hasOutstandingSteps)
                                const SizedBox(height: 16),
                              if (checklistState.hasOutstandingSteps &&
                                  !checklistState.dismissed)
                                _buildOnboardingEmptyState(checklistState),
                              if (checklistState.hasOutstandingSteps &&
                                  !checklistState.dismissed)
                                const SizedBox(height: 20),
                              const Text(
                                'Actions rapides',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF476072),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildRowButtons(
                                "Clients",
                                Icons.people_alt_outlined,
                                "Analyse",
                                Icons.science_outlined,
                                onTap1: () => _pushPage(
                                  const ClientPickerPage(
                                    title: 'Clients',
                                    mode: ClientActionMode.view,
                                  ),
                                ),
                                onTap2: () =>
                                    _pushPage(const AnalysisEntryPage()),
                              ),
                              const SizedBox(height: 12),
                              _buildRowButtons(
                                "Historique",
                                Icons.history_outlined,
                                "Diagnostic",
                                Icons.description_outlined,
                                onTap1: () => _pushPage(
                                  const ClientPickerPage(
                                    title: 'Historique',
                                    mode: ClientActionMode.history,
                                  ),
                                ),
                                onTap2: () => _pushPage(
                                  const ClientPickerPage(
                                    title: 'Dernier diagnostic',
                                    mode: ClientActionMode.diagnostic,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildRowButtons(
                                "Planning",
                                Icons.event_note_outlined,
                                "Suivi",
                                Icons.trending_up_outlined,
                                onTap1: () => _pushPage(const PlanningPage()),
                                onTap2: () => _pushPage(
                                  const ClientPickerPage(
                                    title: 'Suivi intelligent',
                                    mode: ClientActionMode.follow,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel(ActivitySummary summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE5EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tableau de bord',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF184663),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Les bassins à surveiller et les actions à lancer aujourd’hui.',
            style: TextStyle(
              color: Color(0xFF4E6475),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryTile(
                  'Clients',
                  summary.totalClients.toString(),
                  const Color(0xFF0F6E7C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryTile(
                  'Suivis en retard',
                  summary.overdueVisits.toString(),
                  const Color(0xFFB42318),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _summaryTile(
                  'Urgences eau',
                  summary.urgentPools.toString(),
                  const Color(0xFFB54708),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryTile(
                  'Passages 7j',
                  summary.visitsThisWeek.toString(),
                  const Color(0xFF027A48),
                ),
              ),
            ],
          ),
          if (summary.firstVisits > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${summary.firstVisits} bassin${summary.firstVisits > 1 ? 's' : ''} attend${summary.firstVisits > 1 ? 'ent' : ''} une première analyse.',
              style: const TextStyle(
                color: Color(0xFF184663),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncStatusCard() {
    return ValueListenableBuilder<SyncQueueSnapshot>(
      valueListenable: SyncQueueService.current,
      builder: (context, snapshot, _) {
        final color = _syncStateColor(snapshot.state);
        final label = _syncStateLabel(snapshot.state);
        final nextRetry = snapshot.nextRetryAtIso.trim().isEmpty
            ? ''
            : formatDate(snapshot.nextRetryAtIso);
        return DashboardSyncStatusCard(
          snapshot: snapshot,
          color: color,
          statusLabel: label,
          nextRetryLabel: nextRetry,
          onRetry: snapshot.pendingCount > 0 ? _retrySyncNow : null,
          onOpenDetails: () => _pushPage(const CloudSyncPage()),
        );
      },
    );
  }

  Widget _buildCloudAccountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE5EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Compte cloud',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF184663),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Connectez-vous pour synchroniser vos données et vérifier votre abonnement.',
            style: TextStyle(
              color: Color(0xFF667085),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openCloudLogin,
            icon: const Icon(Icons.login),
            label: const Text('Se connecter'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mode local actif. Les données restent sur cet appareil tant que vous ne vous connectez pas.',
            style: TextStyle(
              color: Color(0xFF667085),
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  String _syncStateLabel(SyncQueueState state) {
    switch (state) {
      case SyncQueueState.idle:
        return 'Aucune synchronisation en cours';
      case SyncQueueState.pending:
        return 'Opérations en attente';
      case SyncQueueState.syncing:
        return 'Synchronisation en cours';
      case SyncQueueState.success:
        return 'Synchronisation réussie';
      case SyncQueueState.partialFailure:
        return 'Synchronisation partielle';
      case SyncQueueState.failed:
        return 'Synchronisation en échec';
    }
  }

  Color _syncStateColor(SyncQueueState state) {
    switch (state) {
      case SyncQueueState.idle:
        return const Color(0xFF667085);
      case SyncQueueState.pending:
        return const Color(0xFFB54708);
      case SyncQueueState.syncing:
        return const Color(0xFF0F6E7C);
      case SyncQueueState.success:
        return const Color(0xFF027A48);
      case SyncQueueState.partialFailure:
        return const Color(0xFFB54708);
      case SyncQueueState.failed:
        return const Color(0xFFB42318);
    }
  }

  Future<void> _retrySyncNow() async {
    if (!isFeatureEnabled(EntitlementFlag.cloudSync)) {
      showFeatureBlockedSnackBar(context, EntitlementFlag.cloudSync);
      return;
    }

    final snapshot = await SyncQueueService.retryNow(
      executor: executeQueuedSyncOperation,
      onSuccess: _applyQueuedSyncSuccess,
      onFailure: _applyQueuedSyncFailure,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          snapshot.lastMessage.isEmpty
              ? 'Nouvelle tentative lancée.'
              : snapshot.lastMessage,
        ),
      ),
    );
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475467),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingChecklistCard(OnboardingChecklistState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE5EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Checklist de démarrage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF184663),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Configurez HydrAzur Pro en moins de 5 minutes.',
                      style: TextStyle(
                        color: Color(0xFF4E6475),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _dismissChecklist,
                child: const Text('Passer'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${state.completedCount}/${state.totalCount} étapes terminées',
            style: const TextStyle(
              color: Color(0xFF0F6E7C),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (state.bonusCount > 0) ...[
            const SizedBox(height: 4),
            const Text(
              'Le PDF est proposé en bonus avec l’offre Pro.',
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...state.items.map(_buildChecklistItem),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(OnboardingChecklistItem item) {
    final color = item.completed
        ? const Color(0xFF027A48)
        : item.locked
            ? const Color(0xFFB54708)
            : const Color(0xFF184663);
    final icon = item.completed
        ? Icons.check_circle
        : item.locked
            ? Icons.lock_outline
            : Icons.radio_button_unchecked;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.completed ? null : () => _handleOnboardingStep(item.id),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: item.completed
                ? const Color(0xFFECFDF3)
                : item.locked
                    ? const Color(0xFFFFFAEB)
                    : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.completed
                  ? const Color(0xFFA6F4C5)
                  : item.locked
                      ? const Color(0xFFFEC84B)
                      : const Color(0xFFDCE5EC),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: const Color(0xFF184663),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        height: 1.25,
                      ),
                    ),
                    if (!item.countsTowardProgress) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF8FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Bonus Pro',
                          style: TextStyle(
                            color: Color(0xFF175CD3),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!item.completed)
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF98A2B3),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingResumeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE5EC)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Checklist de démarrage masquée. Reprenez-la quand vous le souhaitez.',
              style: TextStyle(
                color: Color(0xFF475467),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _resumeChecklist,
            child: const Text('Reprendre'),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingEmptyState(OnboardingChecklistState state) {
    final nextStep = state.nextIncomplete;
    if (nextStep == null) {
      return const SizedBox.shrink();
    }

    late final String title;
    late final String description;
    late final String ctaLabel;
    late final IconData icon;
    late final Color accent;

    switch (nextStep.id) {
      case OnboardingStepId.companyProfile:
        title = 'Complétez le profil entreprise';
        description =
            'Une fiche entreprise complète rend les PDF et les réglages directement exploitables.';
        ctaLabel = 'Compléter le profil';
        icon = Icons.apartment_outlined;
        accent = const Color(0xFF0F6E7C);
        break;
      case OnboardingStepId.firstClient:
        title = 'Créez le premier client';
        description =
            'Enregistrez un bassin réel ou de démonstration pour accéder au parcours terrain complet.';
        ctaLabel = 'Créer mon premier client';
        icon = Icons.person_add_alt_1_outlined;
        accent = const Color(0xFF184663);
        break;
      case OnboardingStepId.firstIntervention:
        title = 'Créez la première intervention';
        description =
            'Lancez une analyse sur votre client puis ouvrez la fiche intervention pour enregistrer le terrain.';
        ctaLabel = 'Créer ma première intervention';
        icon = Icons.assignment_outlined;
        accent = const Color(0xFFB54708);
        break;
      case OnboardingStepId.firstPdf:
        title = nextStep.locked
            ? 'Le premier PDF est disponible en Pro'
            : 'Générez le premier PDF';
        description = nextStep.locked
            ? 'L’export PDF est disponible avec l’offre Pro. Vous pouvez continuer à utiliser l’app, puis l’activer quand vous le souhaitez.'
            : 'Un export PDF vous donne tout de suite une valeur concrète à montrer à votre client ou à votre équipe.';
        ctaLabel =
            nextStep.locked ? 'Voir les offres' : 'Générer mon premier PDF';
        icon = nextStep.locked
            ? Icons.workspace_premium_outlined
            : Icons.picture_as_pdf_outlined;
        accent =
            nextStep.locked ? const Color(0xFFB54708) : const Color(0xFF027A48);
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE5EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF184663),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF667085),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _handleOnboardingStep(nextStep.id),
            icon: Icon(icon),
            label: Text(ctaLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildRowButtons(
    String text1,
    IconData icon1,
    String text2,
    IconData icon2, {
    required VoidCallback onTap1,
    required VoidCallback onTap2,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildButton(
            text1,
            icon1,
            onTap: onTap1,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildButton(
            text2,
            icon2,
            onTap: onTap2,
          ),
        ),
      ],
    );
  }

  Widget _buildButton(
    String text,
    IconData icon, {
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFDCE5EC),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F6E7C).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: const Color(0xFF184663),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF184663),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnalysisEntryPage extends StatelessWidget {
  const AnalysisEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE4E7EC)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choisir un mode d’analyse',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF12324A),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Saisie manuelle pour les mesures d’eau ou diagnostic photo, particulièrement utile sur une suspicion d’algues moutardes.',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _analysisTile(
            context: context,
            title: 'Saisie manuelle',
            subtitle: 'Mesures complètes, calculs et diagnostic technique',
            icon: Icons.science_outlined,
            filled: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClientPickerPage(
                    title: 'Nouvelle analyse',
                    mode: ClientActionMode.analyse,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _analysisTile(
            context: context,
            title: 'Diagnostic photo',
            subtitle:
                'Lecture visuelle assistée, utile en cas de suspicion d’algues moutardes',
            icon: Icons.photo_camera_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClientPickerPage(
                    title: 'Diagnostic photo',
                    mode: ClientActionMode.photoDiagnosis,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _analysisTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final bg = filled ? const Color(0xFF0F6E7C) : Colors.white;
    final fg = filled ? Colors.white : const Color(0xFF12324A);
    final sub =
        filled ? Colors.white.withValues(alpha: 0.86) : const Color(0xFF667085);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: filled ? null : Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: filled
                      ? Colors.white.withValues(alpha: 0.16)
                      : const Color(0xFF0F6E7C).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: fg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: fg,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: sub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: fg.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardSyncStatusCard extends StatelessWidget {
  final SyncQueueSnapshot snapshot;
  final Color color;
  final String statusLabel;
  final String nextRetryLabel;
  final VoidCallback? onRetry;
  final VoidCallback onOpenDetails;

  const DashboardSyncStatusCard({
    super.key,
    required this.snapshot,
    required this.color,
    required this.statusLabel,
    required this.nextRetryLabel,
    required this.onOpenDetails,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final statusText =
        '$statusLabel${snapshot.pendingCount > 0 ? ' • ${snapshot.pendingCount} opération(s) en attente' : ''}';
    final detailMessage = snapshot.lastMessage.trim().isEmpty
        ? ''
        : userVisibleSyncMessage(snapshot.lastMessage);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 390;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDCE5EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.sync, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Synchronisation',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF184663),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusText,
                          maxLines: isCompact ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (detailMessage.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  detailMessage,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    height: 1.25,
                  ),
                ),
              ],
              if (nextRetryLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Prochaine tentative : $nextRetryLabel',
                  style: const TextStyle(color: Color(0xFF667085)),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: [
                  if (onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('Réessayer'),
                    ),
                  TextButton(
                    onPressed: onOpenDetails,
                    child: const Text('Voir le détail'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  Future<void> _openPlanEditor(Client client) async {
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) => VisitPlanPage(
          client: client,
          existingPlan: VisitPlanningService.planForClient(
            clientId: client.id,
            plans: AppStore.visitPlans,
          ),
        ),
      ),
    );
    if (result is VisitPlan) {
      AppStore.visitPlans = VisitPlanningService.upsertPlan(
        existing: AppStore.visitPlans,
        plan: result,
      );
      await AppStore.saveVisitPlans();
      if (!mounted) return;
      setState(() {});
    } else if (result == 'delete') {
      AppStore.visitPlans = VisitPlanningService.removePlanForClient(
        existing: AppStore.visitPlans,
        clientId: client.id,
      );
      await AppStore.saveVisitPlans();
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _markVisitDone(VisitPlanningEntry entry) async {
    AppStore.visitPlans = VisitPlanningService.advancePlanForClient(
      existing: AppStore.visitPlans,
      clientId: entry.client.id,
    );
    await AppStore.saveVisitPlans();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Prochain passage recalculé pour ${entry.client.name}.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = VisitPlanningService.buildDashboard(
      clients: AppStore.activeClients,
      plans: AppStore.visitPlans,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning des suivis'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PlanningSummaryCard(
            overdueCount: dashboard.overdue.length,
            todayCount: dashboard.today.length,
            weekCount: dashboard.thisWeek.length,
          ),
          const SizedBox(height: 12),
          _PlanningSection(
            title: 'Suivis en retard',
            subtitle: 'Les bassins à rappeler ou à programmer en priorité.',
            color: const Color(0xFFB42318),
            entries: dashboard.overdue,
            onPlanTap: _openPlanEditor,
            onDoneTap: _markVisitDone,
          ),
          _PlanningSection(
            title: 'Aujourd’hui',
            subtitle: 'Les passages à traiter dans la journée.',
            color: const Color(0xFF0F6E7C),
            entries: dashboard.today,
            onPlanTap: _openPlanEditor,
            onDoneTap: _markVisitDone,
          ),
          _PlanningSection(
            title: 'Passages sous 7 jours',
            subtitle: 'Le planning de la semaine à organiser.',
            color: const Color(0xFF027A48),
            entries: dashboard.thisWeek,
            onPlanTap: _openPlanEditor,
            onDoneTap: _markVisitDone,
          ),
          _PlanningSection(
            title: 'Premières visites',
            subtitle: 'Clients créés sans première analyse enregistrée.',
            color: const Color(0xFF0F6E7C),
            entries: dashboard.firstVisits,
            onPlanTap: _openPlanEditor,
            onDoneTap: _markVisitDone,
          ),
        ],
      ),
    );
  }
}

class _PlanningSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<VisitPlanningEntry> entries;
  final Future<void> Function(Client client) onPlanTap;
  final Future<void> Function(VisitPlanningEntry entry) onDoneTap;

  const _PlanningSection({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.entries,
    required this.onPlanTap,
    required this.onDoneTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${entries.length}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF667085)),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Text(
              'Aucun client dans cette catégorie.',
              style: TextStyle(color: Color(0xFF667085)),
            )
          else
            ...entries.map(
              (entry) => _PlanningClientTile(
                entry: entry,
                color: color,
                onPlanTap: onPlanTap,
                onDoneTap: onDoneTap,
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanningClientTile extends StatelessWidget {
  final VisitPlanningEntry entry;
  final Color color;
  final Future<void> Function(Client client) onPlanTap;
  final Future<void> Function(VisitPlanningEntry entry) onDoneTap;

  const _PlanningClientTile({
    required this.entry,
    required this.color,
    required this.onPlanTap,
    required this.onDoneTap,
  });

  @override
  Widget build(BuildContext context) {
    final client = entry.client;
    final latestScore = client.latestAnalysis?.score;
    final latest = client.latestAnalysis;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  client.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              if (latestScore != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$latestScore/10',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              '${client.volume.toStringAsFixed(0)} m3',
              if (client.treatment.isNotEmpty) client.treatment,
              if (client.address.isNotEmpty) client.address,
            ].join(' • '),
            style: const TextStyle(color: Color(0xFF667085)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            nextVisitLabel(client),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (entry.note.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              entry.note,
              style: const TextStyle(color: Color(0xFF475467)),
            ),
          ],
          if (latest != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _planningPill(
                  Icons.water_drop_outlined,
                  'pH ${latest.ph.toStringAsFixed(1)}',
                ),
                _planningPill(
                  Icons.science_outlined,
                  'Cl ${latest.chlore.toStringAsFixed(1)}',
                ),
                _planningPill(
                  Icons.balance_outlined,
                  'LSI ${latest.lsi.toStringAsFixed(2)}',
                ),
                _planningPill(
                  Icons.event_repeat_outlined,
                  '${entry.frequencyDays} j',
                ),
                if (entry.reminderEnabled)
                  _planningPill(
                    Icons.notifications_active_outlined,
                    'Rappel local',
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClientDetailPage(client: client),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Fiche'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onPlanTap(client),
                  icon: const Icon(Icons.event_repeat_outlined),
                  label: const Text('Planifier'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AnalysisFormPage(client: client),
                      ),
                    );
                  },
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Analyse'),
                ),
              ),
              if (entry.hasPlan) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onDoneTap(entry),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Passage fait'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanningSummaryCard extends StatelessWidget {
  final int overdueCount;
  final int todayCount;
  final int weekCount;

  const _PlanningSummaryCard({
    required this.overdueCount,
    required this.todayCount,
    required this.weekCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vue rapide',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF12324A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Les priorités terrain de la journée et de la semaine.',
            style: TextStyle(
              color: Color(0xFF667085),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _planningMetric(
                  value: '$overdueCount',
                  label: 'En retard',
                  color: const Color(0xFFB42318),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _planningMetric(
                  value: '$todayCount',
                  label: 'Aujourd’hui',
                  color: const Color(0xFF0F6E7C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _planningMetric(
                  value: '$weekCount',
                  label: '7 jours',
                  color: const Color(0xFF027A48),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _planningMetric({
  required String value,
  required String label,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475467),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _planningPill(IconData icon, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFE4E7EC)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF344054)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF344054),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class PricingSettingsPage extends StatefulWidget {
  const PricingSettingsPage({super.key});

  @override
  State<PricingSettingsPage> createState() => _PricingSettingsPageState();
}

class _PricingSettingsPageState extends State<PricingSettingsPage> {
  late bool _showBudgetEstimates;
  late String _selectedPlanId;
  bool _refreshingSubscription = false;
  late final TextEditingController _mainOeuvreController;
  late final TextEditingController _companyNameController;
  late final TextEditingController _companyPhoneController;
  late final TextEditingController _companyEmailController;
  late final TextEditingController _companyAddressController;
  late final TextEditingController _companyWebsiteController;
  late final TextEditingController _companyCountryCodeController;
  late final TextEditingController _companyLocaleCodeController;
  late final TextEditingController _companyCurrencyCodeController;
  late final TextEditingController _businessRegistrationLabelController;
  late final TextEditingController _businessRegistrationValueController;
  late final TextEditingController _taxRegistrationValueController;
  late final TextEditingController _technicianController;
  late final TextEditingController _legalMentionController;
  final Map<String, TextEditingController> _minControllers = {};
  final Map<String, TextEditingController> _maxControllers = {};

  bool get _showAdvancedAdminOptions =>
      kDebugMode ||
      TeamService.canManageTeam(AuthService.currentSession) ||
      AppEnvironment.current != DeploymentEnvironment.prod;

  @override
  void initState() {
    super.initState();
    final settings = AppStore.pricingSettings;
    _showBudgetEstimates = settings.showBudgetEstimates;
    _selectedPlanId = AppStore.subscription.planId;
    _mainOeuvreController = TextEditingController(
      text: settings.defaultMainOeuvre.toStringAsFixed(0),
    );
    final company = AppStore.companyProfile;
    _companyNameController = TextEditingController(text: company.companyName);
    _companyPhoneController = TextEditingController(text: company.phone);
    _companyEmailController = TextEditingController(text: company.email);
    _companyAddressController = TextEditingController(text: company.address);
    _companyWebsiteController = TextEditingController(text: company.website);
    _companyCountryCodeController =
        TextEditingController(text: company.countryCode);
    _companyLocaleCodeController =
        TextEditingController(text: company.localeCode);
    _companyCurrencyCodeController =
        TextEditingController(text: company.currencyCode);
    _businessRegistrationLabelController =
        TextEditingController(text: company.businessRegistrationLabel);
    _businessRegistrationValueController =
        TextEditingController(text: company.businessRegistrationValue);
    _taxRegistrationValueController =
        TextEditingController(text: company.taxRegistrationValue);
    _technicianController =
        TextEditingController(text: company.technicianDefaultName);
    _legalMentionController = TextEditingController(text: company.legalMention);

    for (final item in pricingCatalog) {
      final price = settings.priceFor(item.code);
      _minControllers[item.code] = TextEditingController(
        text: price.minPrice.toStringAsFixed(price.minPrice < 1 ? 2 : 0),
      );
      _maxControllers[item.code] = TextEditingController(
        text: price.maxPrice.toStringAsFixed(price.maxPrice < 1 ? 2 : 0),
      );
    }
  }

  @override
  void dispose() {
    _mainOeuvreController.dispose();
    _companyNameController.dispose();
    _companyPhoneController.dispose();
    _companyEmailController.dispose();
    _companyAddressController.dispose();
    _companyWebsiteController.dispose();
    _companyCountryCodeController.dispose();
    _companyLocaleCodeController.dispose();
    _companyCurrencyCodeController.dispose();
    _businessRegistrationLabelController.dispose();
    _businessRegistrationValueController.dispose();
    _taxRegistrationValueController.dispose();
    _technicianController.dispose();
    _legalMentionController.dispose();
    for (final controller in _minControllers.values) {
      controller.dispose();
    }
    for (final controller in _maxControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _parsePrice(String value, double fallback) {
    return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
  }

  void _resetDefaults() {
    final defaults = PricingSettings.defaults();
    setState(() {
      _showBudgetEstimates = defaults.showBudgetEstimates;
      _mainOeuvreController.text =
          defaults.defaultMainOeuvre.toStringAsFixed(0);
      final company = CompanyProfile.defaults();
      _companyNameController.text = company.companyName;
      _companyPhoneController.text = company.phone;
      _companyEmailController.text = company.email;
      _companyAddressController.text = company.address;
      _companyWebsiteController.text = company.website;
      _companyCountryCodeController.text = company.countryCode;
      _companyLocaleCodeController.text = company.localeCode;
      _companyCurrencyCodeController.text = company.currencyCode;
      _businessRegistrationLabelController.text =
          company.businessRegistrationLabel;
      _businessRegistrationValueController.text =
          company.businessRegistrationValue;
      _taxRegistrationValueController.text = company.taxRegistrationValue;
      _technicianController.text = company.technicianDefaultName;
      _legalMentionController.text = company.legalMention;
      for (final item in pricingCatalog) {
        final price = defaults.priceFor(item.code);
        _minControllers[item.code]!.text =
            price.minPrice.toStringAsFixed(price.minPrice < 1 ? 2 : 0);
        _maxControllers[item.code]!.text =
            price.maxPrice.toStringAsFixed(price.maxPrice < 1 ? 2 : 0);
      }
    });
  }

  Future<void> _refreshSubscriptionFromBackend() async {
    if (!AuthService.isAuthenticated) {
      return;
    }
    setState(() => _refreshingSubscription = true);
    try {
      final refreshed = await refreshBillingFromV2();
      if (refreshed) {
        _selectedPlanId = AppStore.subscription.planId;
      }
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
        setState(() => _refreshingSubscription = false);
      }
    }
  }

  Future<void> _openCloudLogin() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(
          resolveAuthenticatedPage: resolveAuthenticatedEntryPage,
        ),
      ),
    );
    if (mounted && result != null) {
      setState(() {
        _selectedPlanId = AppStore.subscription.planId;
      });
    }
  }

  Future<void> _logoutCloudAccount() async {
    await AuthService.logout();
    await clearServerSubscriptionState();
    AppStore.cloudSyncSettings = AppStore.cloudSyncSettings.copyWith(
      syncMode: CloudSyncMode.legacy,
      lastSyncStatus: 'Mode local actif.',
    );
    await AppStore.saveCloudSyncSettings();
    if (!mounted) return;
    setState(() {
      _selectedPlanId = AppStore.subscription.planId;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Connexion fermée. La synchronisation cloud et l’abonnement Pro ne sont plus vérifiés.',
        ),
      ),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final customPricing = <String, ProductPricing>{};

    for (final item in pricingCatalog) {
      final defaultPrice = defaultPricingFor(item.code);
      double min = _parsePrice(
        _minControllers[item.code]!.text,
        defaultPrice.minPrice,
      );
      double max = _parsePrice(
        _maxControllers[item.code]!.text,
        defaultPrice.maxPrice,
      );

      if (max < min) {
        final temp = min;
        min = max;
        max = temp;
      }

      customPricing[item.code] = ProductPricing(minPrice: min, maxPrice: max);
    }

    AppStore.pricingSettings = PricingSettings(
      showBudgetEstimates: _showBudgetEstimates,
      defaultMainOeuvre: _parsePrice(
        _mainOeuvreController.text,
        AppStore.pricingSettings.defaultMainOeuvre,
      ),
      customPricing: customPricing,
    );
    AppStore.companyProfile = CompanyProfile(
      companyName: _companyNameController.text.trim().isEmpty
          ? CompanyProfile.defaults().companyName
          : _companyNameController.text.trim(),
      phone: _companyPhoneController.text.trim(),
      email: _companyEmailController.text.trim(),
      address: _companyAddressController.text.trim(),
      website: _companyWebsiteController.text.trim(),
      countryCode: _companyCountryCodeController.text.trim().isEmpty
          ? CompanyProfile.defaults().countryCode
          : _companyCountryCodeController.text.trim(),
      localeCode: _companyLocaleCodeController.text.trim().isEmpty
          ? CompanyProfile.defaults().localeCode
          : _companyLocaleCodeController.text.trim(),
      currencyCode: _companyCurrencyCodeController.text.trim().isEmpty
          ? CompanyProfile.defaults().currencyCode
          : _companyCurrencyCodeController.text.trim(),
      businessRegistrationLabel:
          _businessRegistrationLabelController.text.trim(),
      businessRegistrationValue:
          _businessRegistrationValueController.text.trim(),
      taxRegistrationValue: _taxRegistrationValueController.text.trim(),
      technicianDefaultName: _technicianController.text.trim(),
      legalMention: _legalMentionController.text.trim().isEmpty
          ? CompanyProfile.defaults().legalMention
          : _legalMentionController.text.trim(),
    );
    AppStore.workspaceSettings = AppStore.workspaceSettings.copyWith(
      countryCode: _companyCountryCodeController.text.trim().isEmpty
          ? WorkspaceSettings.defaults().countryCode
          : _companyCountryCodeController.text.trim(),
      localeCode: _companyLocaleCodeController.text.trim().isEmpty
          ? WorkspaceSettings.defaults().localeCode
          : _companyLocaleCodeController.text.trim(),
      currencyCode: _companyCurrencyCodeController.text.trim().isEmpty
          ? WorkspaceSettings.defaults().currencyCode
          : _companyCurrencyCodeController.text.trim(),
    );
    if (!AuthService.isAuthenticated) {
      AppStore.subscription = AppStore.subscription.copyWith(
        planId: _selectedPlanId,
        status: SubscriptionStatus.active,
        updatedAtIso: DateTime.now().toIso8601String(),
        startedAtIso: AppStore.subscription.startedAtIso.isEmpty
            ? DateTime.now().toIso8601String()
            : AppStore.subscription.startedAtIso,
      );
    }

    await AppStore.savePricingSettings();
    await AppStore.saveCompanyProfile();
    await AppStore.saveWorkspaceSettings();
    await AppStore.saveSubscription();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.pricingSaved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pricingSettingsTitle),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _save,
            tooltip: l10n.save,
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.companyIdentityTitle,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _companyNameController,
                    decoration: InputDecoration(
                      labelText: l10n.companyNameLabel,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _technicianController,
                    decoration: InputDecoration(
                      labelText: l10n.defaultTechnicianLabel,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _companyPhoneController,
                    decoration: InputDecoration(
                      labelText: l10n.phoneLabel,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _companyEmailController,
                    decoration: InputDecoration(
                      labelText: l10n.emailLabel,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _companyAddressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.addressLabel,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _companyWebsiteController,
                    decoration: InputDecoration(
                      labelText: l10n.websiteLabel,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 430;
                      if (isCompact) {
                        return Column(
                          children: [
                            TextField(
                              controller: _companyCountryCodeController,
                              decoration: InputDecoration(
                                labelText: l10n.countryLabel,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _companyLocaleCodeController,
                              decoration: InputDecoration(
                                labelText: l10n.localeLabel,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _companyCurrencyCodeController,
                              decoration: InputDecoration(
                                labelText: l10n.currencyLabel,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _companyCountryCodeController,
                              decoration: InputDecoration(
                                labelText: l10n.countryLabel,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _companyLocaleCodeController,
                              decoration: InputDecoration(
                                labelText: l10n.localeLabel,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _companyCurrencyCodeController,
                              decoration: InputDecoration(
                                labelText: l10n.currencyLabel,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _businessRegistrationLabelController,
                    decoration: InputDecoration(
                      labelText: l10n.businessRegistrationLabelField,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _businessRegistrationValueController,
                    decoration: InputDecoration(
                      labelText: l10n.businessRegistrationValueLabel,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _taxRegistrationValueController,
                    decoration: InputDecoration(
                      labelText: l10n.taxRegistrationValueLabel,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _legalMentionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.documentMentionLabel,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Exploitation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD0D5DD)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Compte cloud',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AuthService.isAuthenticated
                              ? AuthService.currentSession?.email ??
                                  'Compte connecté'
                              : 'Non connecté',
                          style: const TextStyle(
                            color: Color(0xFF475467),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AuthService.isAuthenticated
                              ? 'Votre abonnement et vos droits Pro sont vérifiés avec votre espace cloud.'
                              : 'Connectez-vous pour synchroniser vos données et vérifier votre abonnement.',
                          style: const TextStyle(
                            color: Color(0xFF475467),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            OutlinedButton.icon(
                              onPressed: AuthService.isAuthenticated
                                  ? _logoutCloudAccount
                                  : _openCloudLogin,
                              icon: Icon(
                                AuthService.isAuthenticated
                                    ? Icons.logout_outlined
                                    : Icons.login,
                              ),
                              label: Text(
                                AuthService.isAuthenticated
                                    ? 'Se déconnecter'
                                    : 'Se connecter',
                              ),
                            ),
                            if (AuthService.isAuthenticated)
                              OutlinedButton.icon(
                                onPressed: _refreshingSubscription
                                    ? null
                                    : _refreshSubscriptionFromBackend,
                                icon: const Icon(Icons.sync),
                                label: Text(
                                  _refreshingSubscription
                                      ? 'Actualisation…'
                                      : 'Actualiser l’abonnement',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD0D5DD)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'État de l’abonnement',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Plan actuel : ${visibleSubscriptionPlanLabel(AppStore.subscription)}',
                          style: const TextStyle(
                            color: Color(0xFF475467),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subscriptionUserOfferMessage(AppStore.subscription),
                          style: const TextStyle(
                            color: Color(0xFF475467),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subscriptionLifecycleMessage(
                            AppStore.subscription,
                            Plan.fromId(
                              'pro',
                              catalogOverride: AppStore.availablePlans,
                            ),
                          ),
                          style: const TextStyle(
                            color: Color(0xFF0F6E7C),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const SubscriptionStatusPage(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.receipt_long_outlined),
                              label: const Text('Voir le détail'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                if (!AuthService.isAuthenticated) {
                                  _openCloudLogin();
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PricingPage(
                                      subscription: AppStore.subscription,
                                      availablePlans: AppStore.availablePlans,
                                    ),
                                  ),
                                );
                              },
                              icon:
                                  const Icon(Icons.workspace_premium_outlined),
                              label: Text(
                                AuthService.isAuthenticated
                                    ? 'Voir les offres'
                                    : 'Se connecter',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_showAdvancedAdminOptions) ...[
                    const SizedBox(height: 12),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Options avancées'),
                      subtitle: const Text(
                        'Réservé aux réglages d’administration.',
                      ),
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedPlanId,
                          decoration: const InputDecoration(
                            labelText: 'Plan d’administration',
                            border: OutlineInputBorder(),
                          ),
                          items: AppStore.availablePlans
                              .map(
                                (plan) => DropdownMenuItem(
                                  value: plan.id,
                                  child: Text(planDisplayLabel(plan)),
                                ),
                              )
                              .toList(),
                          onChanged: AuthService.isAuthenticated
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() => _selectedPlanId = value);
                                },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.groups_2_outlined),
                    title: const Text('Équipe'),
                    subtitle: Text(
                      !AuthService.isAuthenticated
                          ? 'Connectez-vous pour vérifier vos droits et gérer votre équipe.'
                          : FeatureGate.isEnabled(
                              AppStore.subscription
                                  .copyWith(planId: _selectedPlanId),
                              EntitlementFlag.teamMembers,
                            )
                              ? _teamSummaryLabel(AppStore.teamMembers)
                              : FeatureGate.blockedMessage(
                                  AppStore.subscription.copyWith(
                                    planId: _selectedPlanId,
                                  ),
                                  EntitlementFlag.teamMembers,
                                ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      final subscription = AppStore.subscription.copyWith(
                        planId: _selectedPlanId,
                      );
                      if (!FeatureGate.isEnabled(
                        subscription,
                        EntitlementFlag.teamMembers,
                      )) {
                        showFeatureBlockedSnackBar(
                          context,
                          EntitlementFlag.teamMembers,
                          subscription: subscription,
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TeamMembersPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.backup_outlined),
                    title: const Text('Sauvegardes locales'),
                    subtitle: const Text(
                      'Créer une sauvegarde locale et restaurer un état précédent',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BackupPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.manage_accounts_outlined),
                    title: const Text('Compte et données'),
                    subtitle: const Text(
                      'Exporter les données, consulter la confidentialité et supprimer les données locales',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AccountDataPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_sync_outlined),
                    title: const Text('Synchronisation cloud'),
                    subtitle: Text(
                      !AuthService.isAuthenticated
                          ? 'Connectez-vous pour synchroniser vos données et vérifier votre abonnement.'
                          : FeatureGate.isEnabled(
                              AppStore.subscription
                                  .copyWith(planId: _selectedPlanId),
                              EntitlementFlag.cloudSync,
                            )
                              ? 'Connectez-vous puis synchronisez vos données en toute simplicité.'
                              : FeatureGate.blockedMessage(
                                  AppStore.subscription.copyWith(
                                    planId: _selectedPlanId,
                                  ),
                                  EntitlementFlag.cloudSync,
                                ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      final subscription = AppStore.subscription.copyWith(
                        planId: _selectedPlanId,
                      );
                      if (!FeatureGate.isEnabled(
                        subscription,
                        EntitlementFlag.cloudSync,
                      )) {
                        showFeatureBlockedSnackBar(
                          context,
                          EntitlementFlag.cloudSync,
                          subscription: subscription,
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CloudSyncPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('Aide et support'),
                    subtitle: const Text(
                      'Guide utilisateur, assistance et export de diagnostic',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SupportPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: _showBudgetEstimates,
                  title: Text(l10n.showBudgetEstimatesTitle),
                  subtitle: Text(l10n.showBudgetEstimatesSubtitle),
                  onChanged: (value) {
                    setState(() {
                      _showBudgetEstimates = value;
                    });
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(l10n.defaultLaborTitle),
                  subtitle: Text(l10n.defaultLaborSubtitle),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextField(
                    controller: _mainOeuvreController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.defaultLaborFieldLabel(
                        AppStore.workspaceSettings.currencyCode,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.productPricingTitle,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    l10n.productPricingSubtitle,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...pricingCatalog.map((item) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.defaultLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(l10n.unitLabel(item.unitLabel)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minControllers[item.code],
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: l10n.minPriceLabel,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maxControllers[item.code],
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: l10n.maxPriceLabel,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetDefaults,
                  child: Text(l10n.reset),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: Text(l10n.save),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class TeamMembersPage extends StatefulWidget {
  const TeamMembersPage({super.key});

  @override
  State<TeamMembersPage> createState() => _TeamMembersPageState();
}

class _TeamMembersPageState extends State<TeamMembersPage> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (AuthService.isAuthenticated) {
      unawaited(_refreshRemoteTeam());
    }
  }

  Future<void> _refreshRemoteTeam() async {
    if (!AuthService.isAuthenticated) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await refreshTeamFromV2();
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _addMember() async {
    if (!isFeatureEnabled(EntitlementFlag.teamMembers)) {
      showFeatureBlockedSnackBar(context, EntitlementFlag.teamMembers);
      return;
    }
    final canInviteRemotely = !AuthService.isAuthenticated ||
        TeamService.canManageTeam(AuthService.currentSession);
    if (!canInviteRemotely) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Seuls les admins et managers peuvent inviter un membre.'),
        ),
      );
      return;
    }
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    var selectedRole = 'technician';

    final created = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Inviter un membre'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                if (!AuthService.isAuthenticated)
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                  ),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Rôle'),
                  items: const [
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('Admin'),
                    ),
                    DropdownMenuItem(
                      value: 'manager',
                      child: Text('Manager'),
                    ),
                    DropdownMenuItem(
                      value: 'technician',
                      child: Text('Technician'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      selectedRole = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                if (AuthService.isAuthenticated && email.isEmpty) {
                  return;
                }
                if (!AuthService.isAuthenticated && name.isEmpty) {
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  {
                    'name': name,
                    'phone': phoneCtrl.text.trim(),
                    'email': email,
                    'role': selectedRole,
                  },
                );
              },
              child: const Text('Inviter'),
            ),
          ],
        ),
      ),
    );

    if (created == null) return;
    try {
      if (AuthService.isAuthenticated) {
        await TeamService.inviteMember(
          email: created['email'] ?? '',
          fullName: created['name'] ?? '',
          role: created['role'] ?? 'technician',
        );
        await _refreshRemoteTeam();
      } else {
        AppStore.teamMembers.add(
          TeamMember(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: created['name'] ?? '',
            phone: created['phone'] ?? '',
            email: created['email'] ?? '',
            role: _roleLabel(created['role'] ?? 'technician'),
            active: true,
          ),
        );
        await AppStore.saveTeamMembers();
      }
      if (!mounted) return;
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  String _roleLabel(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'manager':
        return 'Manager';
      case 'technician':
      default:
        return 'Technician';
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = AppStore.teamMembers;
    final canManageTeamMembers = isFeatureEnabled(EntitlementFlag.teamMembers);
    final canInviteRemotely =
        TeamService.canManageTeam(AuthService.currentSession);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Équipe'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
        actions: [
          if (AuthService.isAuthenticated)
            IconButton(
              onPressed: _loading ? null : _refreshRemoteTeam,
              icon: const Icon(Icons.sync),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: canManageTeamMembers
            ? _addMember
            : () => showFeatureBlockedSnackBar(
                  context,
                  EntitlementFlag.teamMembers,
                ),
        backgroundColor: const Color(0xFF0F6E7C),
        label: Text(
          AuthService.isAuthenticated ? 'Inviter' : 'Ajouter',
        ),
        icon: const Icon(Icons.person_add_alt_1),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : members.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      canManageTeamMembers
                          ? AuthService.isAuthenticated
                              ? (canInviteRemotely
                                  ? 'Aucun membre ou invitation pour le moment.'
                                  : 'Aucun autre membre visible pour le moment.')
                              : 'Aucun membre enregistré'
                          : FeatureGate.blockedMessage(
                              AppStore.subscription,
                              EntitlementFlag.teamMembers,
                            ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final item = members[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE4E7EC)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                const Color(0xFF0F6E7C).withValues(alpha: 0.12),
                            foregroundColor: const Color(0xFF0F6E7C),
                            child: Text(item.name.isEmpty
                                ? '?'
                                : item.name[0].toUpperCase()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  [
                                    item.role,
                                    if (item.email.isNotEmpty) item.email,
                                    if (item.phone.isNotEmpty) item.phone,
                                  ].join(' • '),
                                  style:
                                      const TextStyle(color: Color(0xFF667085)),
                                ),
                                if (item.isPending)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF4E5),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'Invitation en attente',
                                        style: TextStyle(
                                          color: Color(0xFFB54708),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!AuthService.isAuthenticated)
                            IconButton(
                              onPressed: canManageTeamMembers
                                  ? () async {
                                      AppStore.teamMembers.removeAt(index);
                                      await AppStore.saveTeamMembers();
                                      if (!mounted) return;
                                      setState(() {});
                                    }
                                  : null,
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                    );
                  },
                ),
      bottomNavigationBar: _error == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              ),
            ),
    );
  }
}

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  List<BackupEntry> _backups = const [];

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    final backups = await BackupService.listBackups();
    if (!mounted) return;
    setState(() {
      _backups = backups;
    });
  }

  Future<void> _createBackup() async {
    await BackupService.createBackup(AppStore.exportPayload());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sauvegarde locale créée.')),
    );
    await _loadBackups();
  }

  Future<void> _restoreBackup(BackupEntry entry) async {
    final payload = await BackupService.readBackup(entry.path);
    await AppStore.importPayload(payload);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sauvegarde restaurée dans l’application.')),
    );
    await _loadBackups();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sauvegardes locales'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _createBackup,
            icon: const Icon(Icons.backup_outlined),
            label: const Text('Créer une sauvegarde'),
          ),
          const SizedBox(height: 16),
          if (_backups.isEmpty)
            const Text('Aucune sauvegarde disponible.')
          else
            ..._backups.map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.fileName)),
                    TextButton(
                      onPressed: () => _restoreBackup(entry),
                      child: const Text('Restaurer'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CloudSyncPage extends StatefulWidget {
  const CloudSyncPage({super.key});

  @override
  State<CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends State<CloudSyncPage> {
  late bool _enabled;
  late bool _autoPrepare;
  late CloudSyncMode _syncMode;
  late final TextEditingController _endpointController;
  late final TextEditingController _apiKeyController;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final settings = AppStore.cloudSyncSettings;
    _enabled = settings.enabled;
    _autoPrepare = settings.autoPrepare;
    _syncMode = settings.syncMode;
    _endpointController = TextEditingController(text: settings.endpoint);
    _apiKeyController = TextEditingController();
    _loadApiKey();
    unawaited(processPendingSyncQueue());
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final apiKey = await SecureStorageService.readCloudSyncApiKey();
    if (!mounted) return;
    _apiKeyController.text = apiKey;
  }

  bool get _requiresV2Auth => _syncMode == CloudSyncMode.v2;

  Future<void> _openLogin() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const LoginPage(
          resolveAuthenticatedPage: resolveAuthenticatedEntryPage,
        ),
      ),
    );
    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    await clearServerSubscriptionState();
    AppStore.cloudSyncSettings = AppStore.cloudSyncSettings.copyWith(
      syncMode: CloudSyncMode.legacy,
      lastSyncStatus: 'Mode local actif.',
    );
    await AppStore.saveCloudSyncSettings();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginPage(
          resolveAuthenticatedPage: resolveAuthenticatedEntryPage,
        ),
      ),
      (route) => false,
    );
  }

  Future<bool> _ensureV2Session() async {
    if (!_requiresV2Auth) {
      return true;
    }
    if (AuthService.isAuthenticated) {
      return true;
    }
    await _openLogin();
    return AuthService.isAuthenticated;
  }

  Future<void> _persistApiKey() async {
    if (_requiresV2Auth) {
      return;
    }
    await SecureStorageService.writeCloudSyncApiKey(_apiKeyController.text);
  }

  Future<void> _save() async {
    if (!isFeatureEnabled(EntitlementFlag.cloudSync)) {
      showFeatureBlockedSnackBar(context, EntitlementFlag.cloudSync);
      return;
    }
    await _persistApiKey();
    AppStore.cloudSyncSettings = AppStore.cloudSyncSettings.copyWith(
      enabled: _enabled,
      autoPrepare: _autoPrepare,
      syncMode: _syncMode,
      endpoint: _endpointController.text.trim(),
    );
    await AppStore.saveCloudSyncSettings();
    if (_requiresV2Auth && !AuthService.isAuthenticated && mounted) {
      await _openLogin();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Réglages enregistrés.')),
    );
  }

  Future<void> _preparePayload() async {
    if (!isFeatureEnabled(EntitlementFlag.cloudSync)) {
      showFeatureBlockedSnackBar(context, EntitlementFlag.cloudSync);
      return;
    }
    final path =
        await BackupService.createSyncPayload(AppStore.exportPayload());
    await _persistApiKey();
    AppStore.cloudSyncSettings = AppStore.cloudSyncSettings.copyWith(
      enabled: _enabled,
      autoPrepare: _autoPrepare,
      syncMode: _syncMode,
      endpoint: _endpointController.text.trim(),
      lastPreparedAtIso: DateTime.now().toIso8601String(),
      lastSyncStatus: 'Préparation terminée.',
    );
    await AppStore.saveCloudSyncSettings();
    unawaited(
      AppLogger.event(
        'sync_prepare',
        category: 'sync',
        data: {
          'mode': _syncMode.name,
          'endpoint': _endpointController.text.trim(),
          'path': path,
        },
      ),
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Préparation terminée : $path')),
    );
  }

  Future<void> _pushToCloud() async {
    final l10n = AppLocalizations.of(context)!;
    if (!isFeatureEnabled(EntitlementFlag.cloudSync)) {
      showFeatureBlockedSnackBar(context, EntitlementFlag.cloudSync);
      return;
    }
    final endpoint = _endpointController.text.trim();
    if (endpoint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cloudEndpointRequired)),
      );
      return;
    }
    if (!await _ensureV2Session()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connexion requise.')),
      );
      return;
    }

    setState(() => _busy = true);
    if (_autoPrepare) {
      await BackupService.createSyncPayload(AppStore.exportPayload());
    }
    await _persistApiKey();
    final currentSettings = AppStore.cloudSyncSettings;
    AppStore.cloudSyncSettings = AppStore.cloudSyncSettings.copyWith(
      enabled: _enabled,
      autoPrepare: _autoPrepare,
      syncMode: _syncMode,
      endpoint: endpoint,
      lastPreparedAtIso: _autoPrepare
          ? DateTime.now().toIso8601String()
          : currentSettings.lastPreparedAtIso,
      lastSyncStatus: 'Synchronisation en attente.',
    );
    await AppStore.saveCloudSyncSettings();
    await SyncQueueService.enqueuePush(
      endpoint: endpoint,
      syncMode: _syncMode,
    );
    final snapshot = await processPendingSyncQueue();

    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          snapshot.lastMessage.isEmpty
              ? 'Synchronisation ajoutée à la file.'
              : userVisibleSyncMessage(snapshot.lastMessage),
        ),
      ),
    );
  }

  Future<void> _pullFromCloud() async {
    final l10n = AppLocalizations.of(context)!;
    if (!isFeatureEnabled(EntitlementFlag.cloudSync)) {
      showFeatureBlockedSnackBar(context, EntitlementFlag.cloudSync);
      return;
    }
    final endpoint = _endpointController.text.trim();
    if (endpoint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cloudEndpointRequired)),
      );
      return;
    }
    if (!await _ensureV2Session()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connexion requise.')),
      );
      return;
    }

    setState(() => _busy = true);
    await _persistApiKey();
    final currentSettings = AppStore.cloudSyncSettings;
    AppStore.cloudSyncSettings = currentSettings.copyWith(
      enabled: _enabled,
      autoPrepare: _autoPrepare,
      syncMode: _syncMode,
      endpoint: endpoint,
      lastSyncStatus: 'Synchronisation en attente.',
    );
    await AppStore.saveCloudSyncSettings();
    await SyncQueueService.enqueuePull(
      endpoint: endpoint,
      syncMode: _syncMode,
      sinceIso:
          _syncMode == CloudSyncMode.v2 ? currentSettings.lastPulledAtIso : '',
    );
    final snapshot = await processPendingSyncQueue();

    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          snapshot.lastMessage.isEmpty
              ? 'Récupération ajoutée à la file.'
              : userVisibleSyncMessage(snapshot.lastMessage),
        ),
      ),
    );
  }

  Future<void> _retryNow() async {
    setState(() => _busy = true);
    final snapshot = await SyncQueueService.retryNow(
      executor: executeQueuedSyncOperation,
      onSuccess: _applyQueuedSyncSuccess,
      onFailure: _applyQueuedSyncFailure,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          snapshot.lastMessage.isEmpty
              ? 'Nouvelle tentative lancée.'
              : userVisibleSyncMessage(snapshot.lastMessage),
        ),
      ),
    );
  }

  Future<void> _syncNow() async {
    final endpoint = _endpointController.text.trim();
    if (!isFeatureEnabled(EntitlementFlag.cloudSync)) {
      showFeatureBlockedSnackBar(context, EntitlementFlag.cloudSync);
      return;
    }
    if (endpoint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La synchronisation n’est pas encore configurée. Ouvrez les options avancées si nécessaire.',
          ),
        ),
      );
      return;
    }
    if (!await _ensureV2Session()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Connectez-vous pour synchroniser vos données.')),
      );
      return;
    }

    setState(() => _busy = true);
    await _persistApiKey();
    final currentSettings = AppStore.cloudSyncSettings;
    AppStore.cloudSyncSettings = currentSettings.copyWith(
      enabled: _enabled,
      autoPrepare: _autoPrepare,
      syncMode: _syncMode,
      endpoint: endpoint,
      lastSyncStatus: 'Synchronisation en cours.',
    );
    await AppStore.saveCloudSyncSettings();
    await SyncQueueService.enqueuePush(endpoint: endpoint, syncMode: _syncMode);
    await SyncQueueService.enqueuePull(
      endpoint: endpoint,
      syncMode: _syncMode,
      sinceIso:
          _syncMode == CloudSyncMode.v2 ? currentSettings.lastPulledAtIso : '',
    );
    final snapshot = await processPendingSyncQueue();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          snapshot.lastMessage.isEmpty
              ? 'Synchronisation terminée.'
              : userVisibleSyncMessage(snapshot.lastMessage),
        ),
      ),
    );
  }

  String _lastSyncLabel(CloudSyncSettings settings) {
    final candidates = <DateTime>[];
    for (final raw in [
      settings.lastPushedAtIso,
      settings.lastPulledAtIso,
      settings.lastPreparedAtIso,
    ]) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        candidates.add(parsed);
      }
    }
    if (candidates.isEmpty) {
      return 'Aucune synchronisation récente';
    }
    candidates.sort();
    return formatDate(candidates.last.toIso8601String());
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppStore.cloudSyncSettings;
    final canUseCloudSync = isFeatureEnabled(EntitlementFlag.cloudSync);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Synchronisation cloud'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
        actions: _requiresV2Auth
            ? [
                IconButton(
                  onPressed: _busy ? null : _logout,
                  tooltip: 'Se déconnecter',
                  icon: const Icon(Icons.logout),
                ),
              ]
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ValueListenableBuilder<SyncQueueSnapshot>(
            valueListenable: SyncQueueService.current,
            builder: (context, snapshot, _) {
              final color = _queueStateColor(snapshot.state);
              final stateLabel = _queueStateLabel(snapshot.state);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD0D5DD)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sync, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Statut : $stateLabel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        if (snapshot.pendingCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${snapshot.pendingCount} en attente',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (snapshot.lastMessage.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        userVisibleSyncMessage(snapshot.lastMessage),
                        style: const TextStyle(color: Color(0xFF667085)),
                      ),
                    ],
                    if (snapshot.nextRetryAtIso.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Prochaine tentative : ${formatDate(snapshot.nextRetryAtIso)}',
                        style: const TextStyle(color: Color(0xFF667085)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ||
                              !canUseCloudSync ||
                              snapshot.pendingCount == 0
                          ? null
                          : _retryNow,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer maintenant'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD0D5DD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dernière synchronisation',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF184663),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _lastSyncLabel(settings),
                  style: const TextStyle(
                    color: Color(0xFF475467),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (settings.lastSyncStatus.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    settings.lastSyncStatus,
                    style: const TextStyle(color: Color(0xFF667085)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_requiresV2Auth)
            ValueListenableBuilder(
              valueListenable: AuthService.sessionNotifier,
              builder: (context, session, _) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD0D5DD)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session == null ? 'Se connecter' : 'Compte connecté',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        session == null
                            ? 'Connectez-vous pour synchroniser vos données dans le cloud.'
                            : session.email,
                        style: const TextStyle(color: Color(0xFF667085)),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : (session == null ? _openLogin : _logout),
                          icon: Icon(
                            session == null
                                ? Icons.login
                                : Icons.logout_outlined,
                          ),
                          label: Text(
                            session == null ? 'Se connecter' : 'Se déconnecter',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (_requiresV2Auth) const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy || !canUseCloudSync ? null : _syncNow,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync),
            label: Text(_busy ? 'Synchronisation…' : 'Synchroniser maintenant'),
          ),
          const SizedBox(height: 12),
          if (!canUseCloudSync) ...[
            Text(
              FeatureGate.blockedMessage(
                AppStore.subscription,
                EntitlementFlag.cloudSync,
              ),
              style: const TextStyle(color: Color(0xFFB42318)),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => showFeatureBlockedSnackBar(
                  context,
                  EntitlementFlag.cloudSync,
                ),
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Voir les offres'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Options avancées'),
            subtitle: const Text(
              'Réservé aux réglages internes et aux cas de support.',
            ),
            children: [
              SwitchListTile(
                value: _enabled,
                onChanged: canUseCloudSync
                    ? (value) => setState(() => _enabled = value)
                    : null,
                title: const Text('Activer la synchronisation cloud'),
              ),
              SwitchListTile(
                value: _autoPrepare,
                onChanged: canUseCloudSync
                    ? (value) => setState(() => _autoPrepare = value)
                    : null,
                title: const Text('Préparer automatiquement les données'),
              ),
              DropdownButtonFormField<CloudSyncMode>(
                initialValue: _syncMode,
                decoration: const InputDecoration(
                  labelText: 'Mode de synchronisation',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: CloudSyncMode.legacy,
                    child: Text('Compatibilité'),
                  ),
                  DropdownMenuItem(
                    value: CloudSyncMode.v2,
                    child: Text('Compte connecté'),
                  ),
                ],
                onChanged: (value) {
                  if (!canUseCloudSync) return;
                  if (value == null) return;
                  setState(() => _syncMode = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _endpointController,
                enabled: canUseCloudSync,
                decoration: const InputDecoration(
                  labelText: 'Adresse du service',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (!_requiresV2Auth)
                TextField(
                  controller: _apiKeyController,
                  enabled: canUseCloudSync,
                  decoration: const InputDecoration(
                    labelText: 'Clé d’accès',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy || !canUseCloudSync ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Enregistrer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _busy || !canUseCloudSync ? null : _preparePayload,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Préparer'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _busy || !canUseCloudSync ? null : _pullFromCloud,
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('Récupérer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          _busy || !canUseCloudSync ? null : _pushToCloud,
                      icon: const Icon(Icons.sync),
                      label: Text(_busy ? 'En cours…' : 'Envoyer'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Utilisez ces réglages seulement si votre organisation vous a fourni une configuration spécifique.',
                style: TextStyle(color: Color(0xFF667085)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _queueStateLabel(SyncQueueState state) {
    switch (state) {
      case SyncQueueState.idle:
        return 'Aucune synchronisation en cours';
      case SyncQueueState.pending:
        return 'Opérations en attente';
      case SyncQueueState.syncing:
        return 'Synchronisation en cours';
      case SyncQueueState.success:
        return 'Synchronisation réussie';
      case SyncQueueState.partialFailure:
        return 'Synchronisation partielle';
      case SyncQueueState.failed:
        return 'Synchronisation en échec';
    }
  }

  Color _queueStateColor(SyncQueueState state) {
    switch (state) {
      case SyncQueueState.idle:
        return const Color(0xFF667085);
      case SyncQueueState.pending:
        return const Color(0xFFB54708);
      case SyncQueueState.syncing:
        return const Color(0xFF0F6E7C);
      case SyncQueueState.success:
        return const Color(0xFF027A48);
      case SyncQueueState.partialFailure:
        return const Color(0xFFB54708);
      case SyncQueueState.failed:
        return const Color(0xFFB42318);
    }
  }
}

class ClientMenuPage extends StatelessWidget {
  const ClientMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final canAddClient = FeatureGate.canAddClient(
      AppStore.subscription,
      AppStore.activeClients.length,
    );
    final clientLimit = AppStore.subscription.plan.clientLimit;
    final items = [
      _ClientMenuItemData(
        icon: Icons.groups_2_outlined,
        label: 'Voir les clients',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClientPickerPage(
                title: 'Liste clients',
                mode: ClientActionMode.view,
              ),
            ),
          );
        },
      ),
      _ClientMenuItemData(
        icon: Icons.person_add_alt_1,
        label: 'Ajouter un client',
        disabled: !canAddClient,
        subtitle: canAddClient
            ? null
            : 'Limite atteinte${clientLimit == null ? '' : ' ($clientLimit clients)'}',
        onTap: () {
          if (!canAddClient) {
            showFeatureBlockedSnackBar(
              context,
              EntitlementFlag.unlimitedClients,
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClientFormPage(),
            ),
          );
        },
      ),
      _ClientMenuItemData(
        icon: Icons.edit,
        label: 'Modifier un client',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClientPickerPage(
                title: 'Modifier un client',
                mode: ClientActionMode.edit,
              ),
            ),
          );
        },
      ),
      _ClientMenuItemData(
        icon: Icons.delete_outline,
        label: 'Supprimer un client',
        danger: true,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClientPickerPage(
                title: 'Supprimer un client',
                mode: ClientActionMode.delete,
              ),
            ),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          final disabled = item.disabled;
          final fg = disabled
              ? const Color(0xFF98A2B3)
              : item.danger
                  ? const Color(0xFFB42318)
                  : const Color(0xFF0F6E7C);
          final bg = disabled
              ? const Color(0xFFF8FAFC)
              : item.danger
                  ? const Color(0xFFFFF1F2)
                  : Colors.white;
          final border = disabled
              ? const Color(0xFFE4E7EC)
              : item.danger
                  ? const Color(0xFFFECACA)
                  : const Color(0xFFE5E7EB);

          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: item.onTap,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Icon(item.icon, color: fg, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            color: fg,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle!,
                            style: TextStyle(
                              color: disabled
                                  ? const Color(0xFF98A2B3)
                                  : const Color(0xFF667085),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: fg,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ClientMenuItemData {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool disabled;
  final bool danger;
  final VoidCallback onTap;

  _ClientMenuItemData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.disabled = false,
    this.danger = false,
  });
}

class ClientPickerPage extends StatefulWidget {
  final String title;
  final ClientActionMode mode;

  const ClientPickerPage({
    super.key,
    required this.title,
    required this.mode,
  });

  @override
  State<ClientPickerPage> createState() => _ClientPickerPageState();
}

class _ClientPickerPageState extends State<ClientPickerPage> {
  static const int _pageSize = 40;
  final TextEditingController _searchController = TextEditingController();
  ClientListFilter _filter = ClientListFilter.all;
  int _visibleClientCount = _pageSize;

  bool get _showQuickFilters =>
      widget.mode == ClientActionMode.view ||
      widget.mode == ClientActionMode.analyse ||
      widget.mode == ClientActionMode.photoDiagnosis;

  String get _searchHint {
    switch (widget.mode) {
      case ClientActionMode.analyse:
        return 'Rechercher le bassin à analyser...';
      case ClientActionMode.photoDiagnosis:
        return 'Rechercher le bassin à lire en photo...';
      case ClientActionMode.history:
        return 'Rechercher un historique client...';
      case ClientActionMode.diagnostic:
        return 'Rechercher un diagnostic client...';
      case ClientActionMode.follow:
        return 'Rechercher un bassin à suivre...';
      case ClientActionMode.edit:
        return 'Rechercher un client à modifier...';
      case ClientActionMode.delete:
        return 'Rechercher un client à supprimer...';
      case ClientActionMode.planning:
        return 'Rechercher un client du planning...';
      case ClientActionMode.view:
        return 'Rechercher un client, une adresse, un traitement...';
    }
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> refresh() async {
    await AppStore.save();
    if (mounted) setState(() {});
  }

  void _resetVisibleClients() {
    _visibleClientCount = _pageSize;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Client> _filteredClients(List<Client> source) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = source.where((client) {
      if (client.isDeleted) {
        return false;
      }
      final matchesQuery = query.isEmpty ||
          client.name.toLowerCase().contains(query) ||
          client.address.toLowerCase().contains(query) ||
          client.phone.toLowerCase().contains(query) ||
          client.treatment.toLowerCase().contains(query) ||
          client.bassinType.toLowerCase().contains(query);

      if (!matchesQuery) {
        return false;
      }

      switch (_filter) {
        case ClientListFilter.all:
          return true;
        case ClientListFilter.due:
          final next = nextVisitDateForClient(client);
          if (next == null) return false;
          final today = DateTime.now();
          final startOfToday = DateTime(today.year, today.month, today.day);
          final startOfNext = DateTime(next.year, next.month, next.day);
          return startOfNext.isBefore(startOfToday);
        case ClientListFilter.urgent:
          return (client.latestAnalysis?.score ?? 10) < 5;
        case ClientListFilter.newClients:
          return client.requiresFirstVisit;
      }
    }).toList();

    filtered.sort((a, b) {
      final priorityA = a.requiresFirstVisit
          ? 0
          : (nextVisitDateForClient(a) != null &&
                  DateTime(
                    nextVisitDateForClient(a)!.year,
                    nextVisitDateForClient(a)!.month,
                    nextVisitDateForClient(a)!.day,
                  ).isBefore(
                    DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    ),
                  ))
              ? 1
              : 2;
      final priorityB = b.requiresFirstVisit
          ? 0
          : (nextVisitDateForClient(b) != null &&
                  DateTime(
                    nextVisitDateForClient(b)!.year,
                    nextVisitDateForClient(b)!.month,
                    nextVisitDateForClient(b)!.day,
                  ).isBefore(
                    DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    ),
                  ))
              ? 1
              : 2;
      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
  }

  Future<void> handleTap(Client client) async {
    switch (widget.mode) {
      case ClientActionMode.view:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ClientDetailPage(client: client)),
        );
        break;

      case ClientActionMode.edit:
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ClientFormPage(existing: client),
          ),
        );
        if (result == true) await refresh();
        break;

      case ClientActionMode.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Supprimer ce client ?'),
            content: Text(client.name),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        );
        if (ok == true) {
          final deletedAtIso = SyncMergeService.nowIso();
          client
            ..deletedAtIso = deletedAtIso
            ..updatedAtIso = deletedAtIso
            ..version = SyncMergeService.nextVersion(client.version)
            ..interventions = client.interventions
                .map(
                  (item) => item.copyWith(
                    deletedAtIso: deletedAtIso,
                    updatedAtIso: deletedAtIso,
                    version: SyncMergeService.nextVersion(item.version),
                    attachments: item.attachments
                        .map(
                          (attachment) => attachment.copyWith(
                            deletedAtIso: deletedAtIso,
                            updatedAtIso: deletedAtIso,
                            version: SyncMergeService.nextVersion(
                                attachment.version),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList()
            ..financialDocuments = client.financialDocuments
                .map(
                  (item) => item.copyWith(
                    deletedAtIso: deletedAtIso,
                    updatedAtIso: deletedAtIso,
                    version: SyncMergeService.nextVersion(item.version),
                  ),
                )
                .toList();
          await AppStore.save();
          await refresh();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Client supprime')),
            );
          }
        }
        break;

      case ClientActionMode.analyse:
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisFormPage(client: client),
          ),
        );
        if (result == true) await refresh();
        break;

      case ClientActionMode.photoDiagnosis:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoDiagnosisPage(
              clientName: client.name,
              lastAnalysisDateLabel: client.latestAnalysis == null
                  ? null
                  : formatDate(client.latestAnalysis!.dateIso),
              initialPh: client.latestAnalysis?.ph,
              initialFreeChlorine: client.latestAnalysis?.chlore,
              initialStabilizer: client.latestAnalysis?.stabilisant,
              initialTemperature: client.latestAnalysis?.temperature,
            ),
          ),
        );
        break;

      case ClientActionMode.history:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HistoryPage(client: client),
          ),
        );
        break;

      case ClientActionMode.diagnostic:
        if (client.analyses.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucune analyse disponible pour ce client'),
            ),
          );
          break;
        }

        final analyse = client.analyses.last;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DiagnosticPagePro(
              clientName: client.name,
              dateLabel: formatDate(analyse.dateIso),
              ph: analyse.ph,
              chlore: analyse.chlore,
              tac: analyse.tac,
              th: analyse.th,
              stabilisant: analyse.stabilisant,
              temperature: analyse.temperature,
              lsi: analyse.lsi,
              stabilityScore: analyse.stabilityScore,
              observation: analyse.observation,
              volumeM3: client.volume,
              sel: analyse.tds,
              treatmentType: client.treatment.toLowerCase().contains('brome')
                  ? 'brome'
                  : client.treatment.toLowerCase().contains('sel')
                      ? 'sel'
                      : client.treatment.toLowerCase().contains('ox')
                          ? 'oxygene'
                          : 'chlore',
              pricingSettings: AppStore.pricingSettings,
              companyProfile: AppStore.companyProfile,
              subscription: AppStore.subscription,
              existingDocuments: AppStore.activeClients
                  .expand((item) => item.financialDocuments)
                  .toList(),
              teamMembers: AppStore.teamMembers,
              onSaveIntervention: (record) =>
                  saveInterventionForClient(client, record),
              onSaveFinancialDocument: (document) =>
                  saveFinancialDocumentForClient(client, document),
            ),
          ),
        );
        break;

      case ClientActionMode.follow:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FollowPage(client: client),
          ),
        );
        break;
      case ClientActionMode.planning:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientDetailPage(client: client),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clients = _filteredClients(AppStore.activeClients);
    final visibleClients = clients.take(_visibleClientCount).toList();
    final hasMoreClients = visibleClients.length < clients.length;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: widget.mode == ClientActionMode.view
          ? FloatingActionButton.extended(
              onPressed: () async {
                final canAddClient = FeatureGate.canAddClient(
                  AppStore.subscription,
                  AppStore.activeClients.length,
                );
                if (!canAddClient) {
                  showFeatureBlockedSnackBar(
                    context,
                    EntitlementFlag.unlimitedClients,
                  );
                  return;
                }
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClientFormPage(),
                  ),
                );
                if (result == true) {
                  await refresh();
                }
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Ajouter un client'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(_resetVisibleClients),
                  decoration: InputDecoration(
                    hintText: _searchHint,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_showQuickFilters) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('Tous', ClientListFilter.all),
                        const SizedBox(width: 8),
                        _filterChip('Suivis en retard', ClientListFilter.due),
                        const SizedBox(width: 8),
                        _filterChip('Urgents', ClientListFilter.urgent),
                        const SizedBox(width: 8),
                        _filterChip('À démarrer', ClientListFilter.newClients),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: clients.isEmpty
                ? const Center(
                    child: Text('Aucun client correspondant'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (_, i) {
                      if (hasMoreClients && i == visibleClients.length) {
                        final remaining =
                            clients.length - visibleClients.length;
                        return OutlinedButton.icon(
                          onPressed: () => setState(() {
                            _visibleClientCount += _pageSize;
                          }),
                          icon: const Icon(Icons.expand_more),
                          label: Text(
                            'Charger ${remaining > _pageSize ? _pageSize : remaining} client${remaining > 1 ? 's' : ''} de plus',
                          ),
                        );
                      }
                      final c = visibleClients[i];
                      final statusColor = nextVisitColor(c);
                      final latestScore = c.latestAnalysis?.score;
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => handleTap(c),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color:
                                          statusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      latestScore?.toString() ?? 'N/A',
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 17,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            '${c.volume.toStringAsFixed(0)} m3',
                                            if (c.treatment.isNotEmpty)
                                              c.treatment,
                                            if (c.bassinType.isNotEmpty)
                                              c.bassinType,
                                          ].join(' • '),
                                          style: const TextStyle(
                                            color: Color(0xFF667085),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _statusChip(
                                    nextVisitLabel(c),
                                    statusColor,
                                  ),
                                  _statusChip(
                                    '${c.analyses.length} analyse${c.analyses.length > 1 ? 's' : ''}',
                                    const Color(0xFF0F6E7C),
                                  ),
                                  if (c.filtration.isNotEmpty)
                                    _statusChip(
                                      c.filtration,
                                      const Color(0xFF475467),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: hasMoreClients
                        ? visibleClients.length + 1
                        : visibleClients.length,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, ClientListFilter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _filter = value;
        _resetVisibleClients();
      }),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF344054),
        fontWeight: FontWeight.w600,
      ),
      selectedColor: const Color(0xFF0F6E7C),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? const Color(0xFF0F6E7C) : const Color(0xFFE5E7EB),
        ),
      ),
    );
  }
}

class ClientFormPage extends StatefulWidget {
  final Client? existing;

  const ClientFormPage({super.key, this.existing});

  @override
  State<ClientFormPage> createState() => _ClientFormPageState();
}

class _ClientFormPageState extends State<ClientFormPage> {
  late final TextEditingController nameCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController addressCtrl;
  late final TextEditingController volumeCtrl;
  late final TextEditingController treatmentCtrl;
  late final TextEditingController bassinTypeCtrl;
  late final TextEditingController revetementCtrl;
  late final TextEditingController filtrationCtrl;
  late final TextEditingController equipementsCtrl;
  late final TextEditingController visitFrequencyCtrl;
  late final TextEditingController notesCtrl;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    nameCtrl = TextEditingController(text: c?.name ?? '');
    phoneCtrl = TextEditingController(text: c?.phone ?? '');
    emailCtrl = TextEditingController(text: c?.email ?? '');
    addressCtrl = TextEditingController(text: c?.address ?? '');
    volumeCtrl =
        TextEditingController(text: c == null ? '' : c.volume.toString());
    treatmentCtrl = TextEditingController(text: c?.treatment ?? '');
    bassinTypeCtrl = TextEditingController(text: c?.bassinType ?? '');
    revetementCtrl = TextEditingController(text: c?.revetement ?? '');
    filtrationCtrl = TextEditingController(text: c?.filtration ?? '');
    equipementsCtrl = TextEditingController(text: c?.equipements ?? '');
    visitFrequencyCtrl = TextEditingController(
      text: (c?.visitFrequencyDays ?? 14).toString(),
    );
    notesCtrl = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    addressCtrl.dispose();
    volumeCtrl.dispose();
    treatmentCtrl.dispose();
    bassinTypeCtrl.dispose();
    revetementCtrl.dispose();
    filtrationCtrl.dispose();
    equipementsCtrl.dispose();
    visitFrequencyCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> saveClient() async {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    if (widget.existing == null &&
        !FeatureGate.canAddClient(
          AppStore.subscription,
          AppStore.activeClients.length,
        )) {
      showFeatureBlockedSnackBar(context, EntitlementFlag.unlimitedClients);
      return;
    }

    final volume = double.tryParse(volumeCtrl.text.replaceAll(',', '.')) ?? 0;
    final visitFrequencyDays =
        int.tryParse(visitFrequencyCtrl.text.trim())?.clamp(7, 90) ?? 14;

    final nowIso = SyncMergeService.nowIso();
    if (widget.existing == null) {
      final client = Client(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        phone: phoneCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        address: addressCtrl.text.trim(),
        volume: volume,
        treatment: treatmentCtrl.text.trim(),
        bassinType: bassinTypeCtrl.text.trim(),
        revetement: revetementCtrl.text.trim(),
        filtration: filtrationCtrl.text.trim(),
        equipements: equipementsCtrl.text.trim(),
        visitFrequencyDays: visitFrequencyDays,
        createdAtIso: nowIso,
        updatedAtIso: nowIso,
        version: 1,
        deletedAtIso: '',
        notes: notesCtrl.text.trim(),
        analyses: [],
        interventions: [],
        financialDocuments: [],
      );
      AppStore.clients.add(client);
      unawaited(
        AppLogger.event(
          'client_created',
          category: 'business',
          data: {
            'clientId': client.id,
            'clientName': client.name,
          },
        ),
      );
    } else {
      widget.existing!
        ..name = name
        ..phone = phoneCtrl.text.trim()
        ..email = emailCtrl.text.trim()
        ..address = addressCtrl.text.trim()
        ..volume = volume
        ..treatment = treatmentCtrl.text.trim()
        ..bassinType = bassinTypeCtrl.text.trim()
        ..revetement = revetementCtrl.text.trim()
        ..filtration = filtrationCtrl.text.trim()
        ..equipements = equipementsCtrl.text.trim()
        ..visitFrequencyDays = visitFrequencyDays
        ..notes = notesCtrl.text.trim()
        ..updatedAtIso = nowIso
        ..version = SyncMergeService.nextVersion(widget.existing!.version)
        ..deletedAtIso = '';
    }

    await AppStore.save();
    if (mounted) Navigator.pop(context, true);
  }

  Widget field(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget sectionCard(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF184663),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Modifier le client' : 'Ajouter un client'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          sectionCard(
            'Informations client',
            [
              field('Nom', nameCtrl),
              field('Téléphone', phoneCtrl, keyboard: TextInputType.phone),
              field(
                'Email',
                emailCtrl,
                keyboard: TextInputType.emailAddress,
              ),
              field('Adresse', addressCtrl, maxLines: 2),
            ],
          ),
          sectionCard(
            'Bassin',
            [
              field(
                'Volume du bassin (m3)',
                volumeCtrl,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
              field('Traitement', treatmentCtrl),
              field('Type de bassin', bassinTypeCtrl),
              field('Revêtement', revetementCtrl),
              field('Filtration', filtrationCtrl),
              field('Équipements', equipementsCtrl, maxLines: 2),
            ],
          ),
          sectionCard(
            'Suivi',
            [
              field(
                'Fréquence de suivi (jours)',
                visitFrequencyCtrl,
                keyboard: TextInputType.number,
              ),
              field('Notes', notesCtrl, maxLines: 4),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F6E7C),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: saveClient,
            child: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
          ),
        ],
      ),
    );
  }
}

class ClientDetailPage extends StatelessWidget {
  final Client client;

  const ClientDetailPage({super.key, required this.client});

  Future<void> _launch(
      BuildContext context, Uri uri, String errorMessage) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = client.latestAnalysis;
    final statusColor = nextVisitColor(client);
    final photos = collectClientPhotos(client);
    final latestScore = latest?.score.toDouble();
    final latestStatus = latest?.status ?? 'Aucun suivi récent';
    final currentVisitPlan = VisitPlanningService.planForClient(
      clientId: client.id,
      plans: AppStore.visitPlans,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(client.name),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClientFormPage(existing: client),
                  ),
                );
                if (context.mounted) {
                  (context as Element).markNeedsBuild();
                }
                return;
              }
              if (value == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Supprimer ce client ?'),
                    content: Text(client.name),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Annuler'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Supprimer'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) {
                  return;
                }
                final deletedAtIso = SyncMergeService.nowIso();
                client
                  ..deletedAtIso = deletedAtIso
                  ..updatedAtIso = deletedAtIso
                  ..version = SyncMergeService.nextVersion(client.version)
                  ..interventions = client.interventions
                      .map(
                        (item) => item.copyWith(
                          deletedAtIso: deletedAtIso,
                          updatedAtIso: deletedAtIso,
                          version: SyncMergeService.nextVersion(item.version),
                          attachments: item.attachments
                              .map(
                                (attachment) => attachment.copyWith(
                                  deletedAtIso: deletedAtIso,
                                  updatedAtIso: deletedAtIso,
                                  version: SyncMergeService.nextVersion(
                                    attachment.version,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      )
                      .toList()
                  ..financialDocuments = client.financialDocuments
                      .map(
                        (item) => item.copyWith(
                          deletedAtIso: deletedAtIso,
                          updatedAtIso: deletedAtIso,
                          version: SyncMergeService.nextVersion(item.version),
                        ),
                      )
                      .toList();
                await AppStore.save();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Client supprimé')),
                  );
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'edit',
                child: Text('Modifier'),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text('Supprimer'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _heroCard(
            client: client,
            latestScore: latestScore,
            latestStatus: latestStatus,
            statusColor: statusColor,
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Actions terrain',
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.10,
                children: [
                  _actionTile(
                    icon: Icons.science_outlined,
                    label: 'Nouvelle analyse',
                    subtitle: 'Relevé et diagnostic',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AnalysisFormPage(client: client),
                        ),
                      );
                    },
                    filled: true,
                  ),
                  _actionTile(
                    icon: Icons.history,
                    label: 'Historique',
                    subtitle: 'Analyses et scores',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HistoryPage(client: client),
                        ),
                      );
                    },
                  ),
                  _actionTile(
                    icon: Icons.assignment_outlined,
                    label: 'Interventions',
                    subtitle: 'Bons signés et photos',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              InterventionHistoryPage(client: client),
                        ),
                      );
                    },
                  ),
                  _actionTile(
                    icon: Icons.receipt_long_outlined,
                    label: 'Documents',
                    subtitle: 'Devis et factures',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FinancialDocumentsPage(client: client),
                        ),
                      );
                    },
                  ),
                  _actionTile(
                    icon: Icons.event_repeat_outlined,
                    label: 'Passages',
                    subtitle: 'Planifier les visites récurrentes',
                    onTap: () async {
                      final result = await Navigator.push<Object?>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VisitPlanPage(
                            client: client,
                            existingPlan: currentVisitPlan,
                          ),
                        ),
                      );
                      if (result is VisitPlan) {
                        AppStore.visitPlans = VisitPlanningService.upsertPlan(
                          existing: AppStore.visitPlans,
                          plan: result,
                        );
                        await AppStore.saveVisitPlans();
                        if (context.mounted) {
                          (context as Element).markNeedsBuild();
                        }
                      } else if (result == 'delete') {
                        AppStore.visitPlans =
                            VisitPlanningService.removePlanForClient(
                          existing: AppStore.visitPlans,
                          clientId: client.id,
                        );
                        await AppStore.saveVisitPlans();
                        if (context.mounted) {
                          (context as Element).markNeedsBuild();
                        }
                      }
                    },
                  ),
                ],
              ),
              if (client.phone.isNotEmpty ||
                  client.email.isNotEmpty ||
                  client.address.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (client.phone.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _launch(
                          context,
                          Uri(scheme: 'tel', path: client.phone),
                          'Impossible de lancer l’appel.',
                        ),
                        icon: const Icon(Icons.call_outlined),
                        label: const Text('Appeler'),
                      ),
                    if (client.email.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _launch(
                          context,
                          Uri(
                            scheme: 'mailto',
                            path: client.email,
                            query:
                                'subject=Suivi bassin ${Uri.encodeComponent(client.name)}',
                          ),
                          'Impossible d’ouvrir l’email.',
                        ),
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Email'),
                      ),
                    if (client.address.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _launch(
                          context,
                          Uri.parse(
                            'https://maps.apple.com/?q=${Uri.encodeComponent(client.address)}',
                          ),
                          'Impossible d’ouvrir l’adresse.',
                        ),
                        icon: const Icon(Icons.location_on_outlined),
                        label: const Text('Adresse'),
                      ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Coordonnées et bassin',
            children: [
              _line('Téléphone', client.phone.isEmpty ? '-' : client.phone),
              _line('Email', client.email.isEmpty ? '-' : client.email),
              _line('Adresse', client.address.isEmpty ? '-' : client.address),
              _line('Volume', '${client.volume.toStringAsFixed(1)} m3'),
              _line(
                'Traitement',
                client.treatment.isEmpty ? '-' : client.treatment,
              ),
              _line(
                'Type de bassin',
                client.bassinType.isEmpty ? '-' : client.bassinType,
              ),
              _line(
                'Revêtement',
                client.revetement.isEmpty ? '-' : client.revetement,
              ),
              _line(
                'Filtration',
                client.filtration.isEmpty ? '-' : client.filtration,
              ),
              _line(
                'Équipements',
                client.equipements.isEmpty ? '-' : client.equipements,
              ),
              _line('Cycle de suivi', '${client.visitFrequencyDays} jours'),
              _line(
                'Prochain passage',
                nextVisitDateForClient(client) == null
                    ? '-'
                    : formatShortDate(nextVisitDateForClient(client)!),
              ),
              _line(
                'Note de planning',
                currentVisitPlan == null || currentVisitPlan.note.trim().isEmpty
                    ? '-'
                    : currentVisitPlan.note,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Pilotage entretien',
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_available, color: statusColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        nextVisitLabel(client),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (latest != null) ...[
                const SizedBox(height: 12),
                _line('Dernière analyse', formatDate(latest.dateIso)),
                _line('Score', '${latest.score}/10 - ${latest.status}'),
                _line('LSI', latest.lsi.toStringAsFixed(2)),
                _line(
                  'Observation',
                  latest.observation.trim().isEmpty
                      ? '-'
                      : latest.observation.trim(),
                ),
              ] else
                const Text('Aucune analyse enregistrée pour ce bassin.'),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Notes',
            children: [
              Text(
                client.notes.isEmpty ? 'Aucune note' : client.notes,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoCard(
              title: 'Galerie interventions',
              children: [
                Text(
                  '${photos.length} photo${photos.length > 1 ? 's' : ''} enregistrée${photos.length > 1 ? 's' : ''} sur ce bassin.',
                  style: const TextStyle(color: Color(0xFF475467)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length > 5 ? 5 : photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, index) {
                      final item = photos[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PhotoViewerPage(
                                title:
                                    '${client.name} • ${item.intervention.dateLabel}',
                                path: item.path,
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: OptimizedFileImage(
                            path: item.path,
                            width: 96,
                            height: 96,
                            cacheWidth: 192,
                            cacheHeight: 192,
                            errorWidget: Container(
                              width: 96,
                              height: 96,
                              color: const Color(0xFFF2F4F7),
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClientPhotoGalleryPage(client: client),
                      ),
                    );
                  },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Voir toute la galerie'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Widget _heroCard({
    required Client client,
    required double? latestScore,
    required String latestStatus,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF12324A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nextVisitLabel(client),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _pill(
                          Icons.opacity_outlined,
                          client.treatment.isEmpty
                              ? 'Traitement à préciser'
                              : client.treatment,
                        ),
                        _pill(
                          Icons.pool_outlined,
                          '${client.volume.toStringAsFixed(1)} m3',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.18),
                    width: 4,
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      latestScore == null
                          ? '--'
                          : latestScore.toStringAsFixed(1),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '/10',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            latestStatus,
            style: const TextStyle(
              color: Color(0xFF475467),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  value: '${client.analyses.length}',
                  label: 'Analyses',
                  color: const Color(0xFF0F6E7C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  value: '${client.interventions.length}',
                  label: 'Interv.',
                  color: const Color(0xFFB54708),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  value: '${client.financialDocuments.length}',
                  label: 'Docs',
                  color: const Color(0xFF027A48),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _line(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF344054),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Color(0xFF101828)),
          ),
        ],
      ),
    );
  }

  static Widget _pill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF344054)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _metricBox({
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF475467),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _actionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final bg = filled ? const Color(0xFF0F6E7C) : Colors.white;
    final fg = filled ? Colors.white : const Color(0xFF12324A);
    final sub =
        filled ? Colors.white.withValues(alpha: 0.86) : const Color(0xFF667085);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: filled ? null : Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(icon, color: fg),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: sub,
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClientPhotoGalleryPage extends StatelessWidget {
  final Client client;

  const ClientPhotoGalleryPage({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final photos = collectClientPhotos(client);

    return Scaffold(
      appBar: AppBar(
        title: Text('Galerie - ${client.name}'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: photos.isEmpty
          ? const Center(child: Text('Aucune photo enregistrée'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              itemCount: photos.length,
              itemBuilder: (_, index) {
                final item = photos[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PhotoViewerPage(
                          title:
                              '${client.name} • ${item.intervention.dateLabel}',
                          path: item.path,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4E7EC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: OptimizedFileImage(
                              path: item.path,
                              width: double.infinity,
                              cacheWidth: 640,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.intervention.dateLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.intervention.technicianName,
                                style: const TextStyle(
                                  color: Color(0xFF667085),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class PhotoViewerPage extends StatelessWidget {
  final String title;
  final String path;

  const PhotoViewerPage({
    super.key,
    required this.title,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Impossible de charger cette photo.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnalysisFormPage extends StatefulWidget {
  final Client client;

  const AnalysisFormPage({super.key, required this.client});

  @override
  State<AnalysisFormPage> createState() => _AnalysisFormPageState();
}

class _AnalysisFormPageState extends State<AnalysisFormPage> {
  final phCtrl = TextEditingController();
  final chloreCtrl = TextEditingController();
  final tacCtrl = TextEditingController();
  final thCtrl = TextEditingController();
  final stabilisantCtrl = TextEditingController();
  final temperatureCtrl = TextEditingController(text: '25');
  final observationCtrl = TextEditingController();
  final mainOeuvreCtrl = TextEditingController(
    text: AppStore.pricingSettings.defaultMainOeuvre.toStringAsFixed(0),
  );
  final tdsCtrl = TextEditingController();

  bool strongSun = true;
  bool heavyBatherLoad = false;
  double waterTempC = 25;
  late String treatmentType;

  @override
  void dispose() {
    phCtrl.dispose();
    chloreCtrl.dispose();
    tacCtrl.dispose();
    thCtrl.dispose();
    stabilisantCtrl.dispose();
    temperatureCtrl.dispose();
    observationCtrl.dispose();
    mainOeuvreCtrl.dispose();
    tdsCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    final t = widget.client.treatment.toLowerCase();

    if (t.contains('brome')) {
      treatmentType = 'brome';
    } else if (t.contains('sel')) {
      treatmentType = 'sel';
    } else if (t.contains('ox')) {
      treatmentType = 'oxygene';
    } else {
      treatmentType = 'chlore';
    }
  }

  Future<void> saveAnalysis() async {
    final parsedPh = double.tryParse(phCtrl.text.replaceAll(',', '.'));
    final parsedChlore = double.tryParse(chloreCtrl.text.replaceAll(',', '.'));
    final parsedTac = double.tryParse(tacCtrl.text.replaceAll(',', '.'));
    final parsedTh = double.tryParse(thCtrl.text.replaceAll(',', '.'));
    final parsedStabilisant =
        double.tryParse(stabilisantCtrl.text.replaceAll(',', '.'));
    final parsedTemperature =
        double.tryParse(temperatureCtrl.text.replaceAll(',', '.'));

    if ([
      parsedPh,
      parsedChlore,
      parsedTac,
      parsedTh,
      parsedStabilisant,
      parsedTemperature,
    ].contains(null)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Veuillez remplir correctement tous les champs numériques.'),
        ),
      );
      return;
    }

    final double ph = parsedPh!;
    final double chlore = parsedChlore!;
    final double tac = parsedTac!;
    final double th = parsedTh!;
    final double stabilisant = parsedStabilisant!;
    final double temperature = parsedTemperature!;

    final double tds = treatmentType == 'sel'
        ? double.tryParse(tdsCtrl.text.replaceAll(',', '.')) ?? 0
        : 0;

    final double baseLsi = calculateLSI(
      ph: ph,
      temperature: temperature,
      th: th,
      tac: tac,
      stabilisant: stabilisant,
    );

    final double tdsCorrection = (tds - 1000) / 10000;
    final double lsi = baseLsi - tdsCorrection;

    final double premiumScore = calculatePremiumScore(
      ph: ph,
      chlore: chlore,
      tac: tac,
      th: th,
      stabilisant: stabilisant,
      lsi: lsi,
    );

    double adjustedPremiumScore = premiumScore;
    String extraObservation = "";

// ☀️ Soleil fort
    if (strongSun) {
      if (chlore < 2) {
        adjustedPremiumScore -= 10;
        extraObservation +=
            "\n• Ensoleillement fort : risque de destruction rapide du chlore.";
      }

      if (stabilisant < 40) {
        adjustedPremiumScore -= 5;
        extraObservation +=
            "\n• Stabilisant insuffisant pour forte exposition UV.";
      }
    }

// 👥 Forte fréquentation
    if (heavyBatherLoad) {
      if (chlore < 2) {
        adjustedPremiumScore -= 10;
        extraObservation +=
            "\n• Forte fréquentation : désinfection insuffisante.";
      }
    }

    final analysis = WaterAnalysis(
      dateIso: DateTime.now().toIso8601String(),
      ph: ph,
      chlore: chlore,
      tac: tac,
      th: th,
      stabilisant: stabilisant,
      temperature: temperature,
      tds: tds,
      lsi: lsi,
      stabilityScore: adjustedPremiumScore,
      eauSalee: treatmentType == 'sel',
      liner: true,
      observation: observationCtrl.text.trim() + extraObservation,
      mainOeuvre:
          double.tryParse(mainOeuvreCtrl.text.replaceAll(',', '.')) ?? 0,
    );

    widget.client.analyses.add(analysis);
    AppStore.visitPlans = VisitPlanningService.advancePlanForClient(
      existing: AppStore.visitPlans,
      clientId: widget.client.id,
      completedAt: DateTime.tryParse(analysis.dateIso)?.toLocal(),
    );
    await AppStore.save();
    await AppStore.saveVisitPlans();

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiagnosticPagePro(
          clientName: widget.client.name,
          dateLabel: formatDate(analysis.dateIso),
          ph: analysis.ph,
          chlore: analysis.chlore,
          tac: analysis.tac,
          th: analysis.th,
          stabilisant: analysis.stabilisant,
          temperature: analysis.temperature,
          lsi: analysis.lsi,
          stabilityScore: analysis.stabilityScore,
          observation: analysis.observation,
          volumeM3: widget.client.volume,
          sel: analysis.tds,
          treatmentType: treatmentType,
          pricingSettings: AppStore.pricingSettings,
          companyProfile: AppStore.companyProfile,
          subscription: AppStore.subscription,
          existingDocuments: AppStore.activeClients
              .expand((item) => item.financialDocuments)
              .toList(),
          teamMembers: AppStore.teamMembers,
          onSaveIntervention: (record) =>
              saveInterventionForClient(widget.client, record),
          onSaveFinancialDocument: (document) =>
              saveFinancialDocumentForClient(widget.client, document),
        ),
      ),
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Widget field(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: maxLines == 1
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.multiline,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analyse - ${widget.client.name}'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field('pH', phCtrl),
          field('Chlore', chloreCtrl),
          field('TAC', tacCtrl),
          field('TH', thCtrl),
          field('Stabilisant', stabilisantCtrl),
          field('Température (°C)', temperatureCtrl),
          field('Observation', observationCtrl, maxLines: 4),
          const SizedBox(height: 8),
          SwitchListTile(
            value: strongSun,
            onChanged: (v) => setState(() => strongSun = v),
            title: const Text('Fort ensoleillement'),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: heavyBatherLoad,
            onChanged: (v) => setState(() => heavyBatherLoad = v),
            title: const Text('Forte fréquentation'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: treatmentType,
            decoration: InputDecoration(
              labelText: 'Type de traitement',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'chlore', child: Text('Chlore')),
              DropdownMenuItem(value: 'brome', child: Text('Brome')),
              DropdownMenuItem(value: 'sel', child: Text('Sel')),
              DropdownMenuItem(value: 'oxygene', child: Text('Oxygène actif')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => treatmentType = v);
              }
            },
          ),
          if (treatmentType == 'sel')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: tdsCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'TDS / Taux de sel (ppm)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F6E7C),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: saveAnalysis,
            child: const Text('Enregistrer l’analyse'),
          ),
        ],
      ),
    );
  }
}

class DiagnosticPage extends StatelessWidget {
  final Client client;

  const DiagnosticPage({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final a = client.latestAnalysis;

    if (a == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Diagnostic'),
          backgroundColor: const Color(0xFF0F6E7C),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Aucune analyse pour ce client')),
      );
    }

    final diag = buildDiagnosis(client, a);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
        actions: isFeatureEnabled(EntitlementFlag.pdfExport)
            ? [
                IconButton(
                  onPressed: () async {
                    final bytes = await buildInterventionPdf(client, a);
                    if (context.mounted) {
                      await Printing.layoutPdf(
                        onLayout: (format) async => bytes,
                        name: 'fiche_${client.name}.pdf',
                      );
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                ),
              ]
            : [
                IconButton(
                  onPressed: () => showFeatureBlockedSnackBar(
                    context,
                    EntitlementFlag.pdfExport,
                  ),
                  icon: const Icon(Icons.lock_outline),
                ),
              ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(
            title: client.name,
            children: [
              Text(
                formatDate(a.dateIso),
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Text(
                'Score eau : ${a.score}/10',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(a.status, style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Mesures',
            children: [
              _row('pH', a.ph.toString()),
              _row('Chlore', a.chlore.toString()),
              _row('TAC', a.tac.toString()),
              _row('TH', a.th.toString()),
              _row('Stabilisant', a.stabilisant.toString()),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Actions conseillees',
            children: diag
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('• $e'),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Observation',
            children: [
              Text(
                  a.observation.isEmpty ? 'Aucune observation' : a.observation),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label :',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  final Client client;

  const HistoryPage({super.key, required this.client});

  List<String> _historyActions(
    WaterAnalysis? previous,
    WaterAnalysis current,
  ) {
    final actions = <String>[];
    if (previous != null) {
      if (current.score < previous.score) {
        actions.add('Score en baisse, prévoir un contrôle rapproché.');
      } else if (current.score > previous.score) {
        actions.add('Équilibre en amélioration, maintenir le protocole.');
      }
    }

    if (current.ph > 7.6) {
      actions.add('pH à surveiller, ajuster vers la zone 7.2 – 7.4.');
    }
    if (current.chlore < 1.5) {
      actions.add('Désinfectant bas, vérifier production et fréquentation.');
    }
    if (current.lsi > 0.3) {
      actions.add('Risque d’entartrage, contrôler cellule et filtration.');
    } else if (current.lsi < -0.3) {
      actions.add('Eau agressive, confirmer pH, TAC et état du bassin.');
    }

    if (actions.isEmpty) {
      actions.add('Tendance stable, conserver le rythme de suivi prévu.');
    }
    return actions.take(2).toList();
  }

  Color _scoreColor(int score) {
    if (score >= 8) return const Color(0xFF027A48);
    if (score >= 5) return const Color(0xFFB54708);
    return const Color(0xFFB42318);
  }

  @override
  Widget build(BuildContext context) {
    final analyses = client.analyses.reversed.toList();
    final latest = analyses.isEmpty ? null : analyses.first;
    final previous = analyses.length > 1 ? analyses[1] : null;
    final bestScore = analyses.isEmpty
        ? null
        : analyses.map((item) => item.score).reduce(max);
    final averageScore = analyses.isEmpty
        ? null
        : analyses.map((item) => item.score).reduce((a, b) => a + b) /
            analyses.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Historique - ${client.name}'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: analyses.isEmpty
          ? const Center(child: Text('Aucune analyse'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: analyses.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return _HistorySummaryCard(
                    totalCount: analyses.length,
                    latestScore: latest!.score,
                    bestScore: bestScore!,
                    averageScore: averageScore!,
                    trendLabel: previous == null
                        ? 'Première analyse enregistrée'
                        : latest.score > previous.score
                            ? 'Tendance en amélioration'
                            : latest.score < previous.score
                                ? 'Tendance à surveiller'
                                : 'Tendance stable',
                    trendColor: previous == null
                        ? const Color(0xFF0F6E7C)
                        : latest.score > previous.score
                            ? const Color(0xFF027A48)
                            : latest.score < previous.score
                                ? const Color(0xFFB42318)
                                : const Color(0xFF667085),
                  );
                }
                final historyIndex = i - 1;
                final a = analyses[historyIndex];
                final previousAnalysis = historyIndex + 1 < analyses.length
                    ? analyses[historyIndex + 1]
                    : null;
                final scoreColor = _scoreColor(a.score);
                final followUpDate = DateTime.tryParse(a.dateIso)
                    ?.toLocal()
                    .add(Duration(days: client.visitFrequencyDays));
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DiagnosticPagePro(
                          clientName: client.name,
                          dateLabel: formatDate(a.dateIso),
                          ph: a.ph,
                          chlore: a.chlore,
                          tac: a.tac,
                          th: a.th,
                          stabilisant: a.stabilisant,
                          temperature: a.temperature,
                          lsi: a.lsi,
                          stabilityScore: a.stabilityScore,
                          observation: a.observation,
                          volumeM3: client.volume,
                          sel: a.tds,
                          treatmentType: client.treatment
                                  .toLowerCase()
                                  .contains('brome')
                              ? 'brome'
                              : client.treatment.toLowerCase().contains('sel')
                                  ? 'sel'
                                  : client.treatment
                                          .toLowerCase()
                                          .contains('ox')
                                      ? 'oxygene'
                                      : 'chlore',
                          pricingSettings: AppStore.pricingSettings,
                          companyProfile: AppStore.companyProfile,
                          subscription: AppStore.subscription,
                          existingDocuments: AppStore.activeClients
                              .expand((item) => item.financialDocuments)
                              .toList(),
                          teamMembers: AppStore.teamMembers,
                          onSaveIntervention: (record) =>
                              saveInterventionForClient(client, record),
                          onSaveFinancialDocument: (document) =>
                              saveFinancialDocumentForClient(client, document),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                formatDate(a.dateIso),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: scoreColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${a.score}/10',
                                style: TextStyle(
                                  color: scoreColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _historyPill(
                              Icons.water_drop_outlined,
                              'pH ${a.ph.toStringAsFixed(1)}',
                            ),
                            _historyPill(
                              Icons.science_outlined,
                              'Cl ${a.chlore.toStringAsFixed(1)}',
                            ),
                            _historyPill(
                              Icons.monitor_heart_outlined,
                              'TAC ${a.tac.toStringAsFixed(0)}',
                            ),
                            _historyPill(
                              Icons.balance_outlined,
                              'LSI ${a.lsi.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          a.status,
                          style: TextStyle(
                            color: scoreColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (followUpDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Contrôle conseillé le ${formatShortDate(followUpDate)}',
                              style: const TextStyle(color: Color(0xFF667085)),
                            ),
                          ),
                        if (a.observation.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              a.observation,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF475467)),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE4E7EC)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'À retenir',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF344054),
                                ),
                              ),
                              const SizedBox(height: 6),
                              ..._historyActions(previousAnalysis, a).map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '• $item',
                                    style: const TextStyle(
                                      color: Color(0xFF475467),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _HistorySummaryCard extends StatelessWidget {
  final int totalCount;
  final int latestScore;
  final int bestScore;
  final double averageScore;
  final String trendLabel;
  final Color trendColor;

  const _HistorySummaryCard({
    required this.totalCount,
    required this.latestScore,
    required this.bestScore,
    required this.averageScore,
    required this.trendLabel,
    required this.trendColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vue historique',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF12324A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            trendLabel,
            style: TextStyle(
              color: trendColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _historyMetric(
                  value: '$totalCount',
                  label: 'Analyses',
                  color: const Color(0xFF0F6E7C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _historyMetric(
                  value: '$latestScore/10',
                  label: 'Dernière',
                  color: const Color(0xFFB54708),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _historyMetric(
                  value: '$bestScore/10',
                  label: 'Meilleure',
                  color: const Color(0xFF027A48),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _historyMetric(
                  value: averageScore.toStringAsFixed(1),
                  label: 'Moyenne',
                  color: const Color(0xFF7A5AF8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _historyMetric({
  required String value,
  required String label,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475467),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _historyPill(IconData icon, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFE4E7EC)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF344054)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF344054),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class InterventionHistoryPage extends StatelessWidget {
  final Client client;

  const InterventionHistoryPage({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final interventions = client.interventions
        .where((item) => !item.isDeleted)
        .toList()
        .reversed
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Interventions - ${client.name}'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: interventions.isEmpty
          ? const Center(child: Text('Aucune intervention enregistrée'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: interventions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final item = interventions[i];
                final color = item.interventionCompleted
                    ? const Color(0xFF027A48)
                    : const Color(0xFFB54708);

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    if (!isFeatureEnabled(EntitlementFlag.pdfExport)) {
                      showFeatureBlockedSnackBar(
                        context,
                        EntitlementFlag.pdfExport,
                      );
                      return;
                    }
                    final photoBytes = <Uint8List>[];
                    for (final attachment in item.attachments
                        .where((entry) => entry.hasLocalPath)
                        .take(PdfService.maxEmbeddedPhotos)) {
                      final bytes = await LocalStorageService.readBinary(
                        attachment.localPath,
                      );
                      if (bytes != null) {
                        photoBytes.add(Uint8List.fromList(bytes));
                      }
                    }
                    final pdf = await PdfService.generateInterventionTicketPdf(
                      companyProfile: AppStore.companyProfile,
                      ticket: item.toTicketData(client.name),
                      signatureBytes: item.signatureBytes,
                      photoBytes: photoBytes,
                    );
                    if (context.mounted) {
                      await Printing.layoutPdf(
                        onLayout: (_) async => pdf,
                        name: 'intervention_${client.name}_${item.id}.pdf',
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.dateLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                item.interventionCompleted
                                    ? 'Réalisée'
                                    : 'À finaliser',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(item.technicianName),
                        const SizedBox(height: 6),
                        Text(
                          item.interventionSummary.isEmpty
                              ? 'Aucun détail saisi'
                              : item.interventionSummary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _historyChip(
                              item.estimateApproved
                                  ? 'Chiffrage validé'
                                  : 'Chiffrage à valider',
                              item.estimateApproved
                                  ? const Color(0xFF027A48)
                                  : const Color(0xFFB54708),
                            ),
                            _historyChip(
                              item.followUpRequired
                                  ? 'Suivi requis'
                                  : 'Pas de suivi',
                              item.followUpRequired
                                  ? const Color(0xFF0F6E7C)
                                  : const Color(0xFF667085),
                            ),
                            if (item.attachments
                                .any((entry) => entry.hasLocalPath))
                              _historyChip(
                                '${item.photoPaths.length} photo${item.photoPaths.length > 1 ? 's' : ''}',
                                const Color(0xFF475467),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                await createAndPresentPublicShareLink(
                                  context,
                                  resourceType:
                                      PublicShareResourceType.intervention,
                                  resourceId: item.id,
                                );
                              },
                              icon: const Icon(Icons.link_outlined),
                              label: const Text('Lien client'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _historyChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class FinancialDocumentsPage extends StatefulWidget {
  final Client client;

  const FinancialDocumentsPage({super.key, required this.client});

  @override
  State<FinancialDocumentsPage> createState() => _FinancialDocumentsPageState();
}

class _FinancialDocumentsPageState extends State<FinancialDocumentsPage> {
  List<FinancialDocument> get _documents => widget.client.financialDocuments
      .where((item) => !item.isDeleted)
      .toList()
      .reversed
      .toList();

  String _buildDocumentNumber(FinancialDocumentType type) {
    return DocumentNumberService.buildNextNumber(
      type: type,
      existingDocuments: AppStore.activeClients.expand(
        (client) => client.financialDocuments,
      ),
    );
  }

  String _todayLabel() {
    return FormattingService.formatDate(
      DateTime.now(),
      AppStore.workspaceSettings,
    );
  }

  Future<void> _previewDocument(FinancialDocument item) async {
    if (!isFeatureEnabled(EntitlementFlag.pdfExport)) {
      showFeatureBlockedSnackBar(context, EntitlementFlag.pdfExport);
      return;
    }
    final pdf = await PdfService.generateFinancialDocumentPdf(
      companyProfile: AppStore.companyProfile,
      document: item,
    );
    if (!mounted) return;
    await Printing.layoutPdf(
      onLayout: (_) async => pdf,
      name:
          '${item.type == FinancialDocumentType.quote ? 'devis' : 'facture'}_${widget.client.name}_${item.id}.pdf',
    );
  }

  Future<void> _shareDocument(FinancialDocument item) async {
    if (!isFeatureEnabled(EntitlementFlag.pdfExport)) {
      showFeatureBlockedSnackBar(context, EntitlementFlag.pdfExport);
      return;
    }
    final pdf = await PdfService.generateFinancialDocumentPdf(
      companyProfile: AppStore.companyProfile,
      document: item,
    );
    await DocumentShareService.sharePdf(
      bytes: pdf,
      filename: DocumentShareService.safePdfFilename(
        '${item.type == FinancialDocumentType.quote ? 'devis' : 'facture'}_${widget.client.name}_${item.documentNumber.isEmpty ? item.id : item.documentNumber}',
      ),
    );
  }

  Future<void> _setStatus(
    FinancialDocument item,
    FinancialDocumentStatus status,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await updateFinancialDocumentForClient(
      widget.client,
      item.copyWith(status: status),
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(l10n.financialDocumentUpdated(_documentStatusLabel(status))),
      ),
    );
  }

  Future<void> _convertQuoteToInvoice(FinancialDocument item) async {
    final l10n = AppLocalizations.of(context)!;
    final invoice = FinancialDocument(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      documentNumber: _buildDocumentNumber(FinancialDocumentType.invoice),
      createdAtIso: DateTime.now().toIso8601String(),
      type: FinancialDocumentType.invoice,
      status: FinancialDocumentStatus.sent,
      vatRate: item.vatRate,
      depositAmount: item.depositAmount,
      title: _invoiceTitleFromQuote(item.title, l10n),
      dateLabel: _todayLabel(),
      dueDateLabel: l10n.invoiceDueDefault,
      clientName: item.clientName,
      technicianName: item.technicianName,
      paymentMethodLabel: item.paymentMethodLabel,
      notes: item.notes,
      items: item.items,
    );
    await saveFinancialDocumentForClient(widget.client, invoice);
    await updateFinancialDocumentForClient(
      widget.client,
      item.copyWith(status: FinancialDocumentStatus.approved),
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.invoiceCreatedFromQuote)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final documents = _documents;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.financialDocumentsTitle(widget.client.name)),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: documents.isEmpty
          ? Center(child: Text(l10n.noFinancialDocuments))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: documents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final item = documents[index];
                final color = item.type == FinancialDocumentType.quote
                    ? const Color(0xFF0F6E7C)
                    : const Color(0xFF027A48);
                final statusColor = _documentStatusColor(item.status);

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: isFeatureEnabled(EntitlementFlag.pdfExport)
                      ? () => _previewDocument(item)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.documentNumber.isEmpty
                                        ? l10n.numberToAssign
                                        : item.documentNumber,
                                    style: const TextStyle(
                                      color: Color(0xFF667085),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                item.type == FinancialDocumentType.quote
                                    ? l10n.quoteLabel
                                    : l10n.invoiceLabel,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _documentStatusLabel(item.status),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (item.dueDateLabel.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.dueDateLabel,
                                  style: const TextStyle(
                                    color: Color(0xFF667085),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(item.dateLabel),
                        const SizedBox(height: 6),
                        Text(
                          l10n.lineCountSummary(
                            item.items.length,
                            FormattingService.formatCurrency(
                              item.total,
                              AppStore.workspaceSettings,
                            ),
                          ),
                          style: const TextStyle(color: Color(0xFF475467)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.subtotalTaxSummary(
                            FormattingService.formatCurrency(
                              item.subtotalHt,
                              AppStore.workspaceSettings,
                            ),
                            item.taxLabel,
                            item.vatRate.toStringAsFixed(
                              item.vatRate % 1 == 0 ? 0 : 1,
                            ),
                          ),
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.depositAmount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            l10n.depositDueSummary(
                              FormattingService.formatCurrency(
                                item.depositAmount,
                                AppStore.workspaceSettings,
                              ),
                              FormattingService.formatCurrency(
                                item.amountDue,
                                AppStore.workspaceSettings,
                              ),
                            ),
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _previewDocument(item),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: Text(l10n.pdf),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _shareDocument(item),
                              icon: const Icon(Icons.share_outlined),
                              label: Text(l10n.share),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => createAndPresentPublicShareLink(
                                context,
                                resourceType:
                                    PublicShareResourceType.financialDocument,
                                resourceId: item.id,
                              ),
                              icon: const Icon(Icons.link_outlined),
                              label: const Text('Lien client'),
                            ),
                            if (item.type == FinancialDocumentType.quote &&
                                item.status != FinancialDocumentStatus.sent)
                              OutlinedButton.icon(
                                onPressed: () => _setStatus(
                                  item,
                                  FinancialDocumentStatus.sent,
                                ),
                                icon: const Icon(Icons.send_outlined),
                                label: Text(l10n.send),
                              ),
                            if (item.type == FinancialDocumentType.quote &&
                                item.status != FinancialDocumentStatus.approved)
                              FilledButton.icon(
                                onPressed: () => _setStatus(
                                  item,
                                  FinancialDocumentStatus.approved,
                                ),
                                icon: const Icon(Icons.check_circle_outline),
                                label: Text(l10n.accept),
                              ),
                            if (item.type == FinancialDocumentType.quote)
                              OutlinedButton.icon(
                                onPressed: () => _convertQuoteToInvoice(item),
                                icon: const Icon(Icons.receipt_long_outlined),
                                label: Text(l10n.createInvoiceAction),
                              ),
                            if (item.type == FinancialDocumentType.invoice &&
                                item.status != FinancialDocumentStatus.paid)
                              FilledButton.icon(
                                onPressed: () => _setStatus(
                                  item,
                                  FinancialDocumentStatus.paid,
                                ),
                                icon: const Icon(Icons.paid_outlined),
                                label: Text(l10n.markPaid),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _documentStatusColor(FinancialDocumentStatus status) {
    switch (status) {
      case FinancialDocumentStatus.draft:
        return const Color(0xFF667085);
      case FinancialDocumentStatus.sent:
        return const Color(0xFFB54708);
      case FinancialDocumentStatus.approved:
        return const Color(0xFF0F6E7C);
      case FinancialDocumentStatus.paid:
        return const Color(0xFF027A48);
    }
  }

  String _documentStatusLabel(FinancialDocumentStatus status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case FinancialDocumentStatus.draft:
        return l10n.draftStatus;
      case FinancialDocumentStatus.sent:
        return l10n.sentStatus;
      case FinancialDocumentStatus.approved:
        return l10n.approvedStatus;
      case FinancialDocumentStatus.paid:
        return l10n.paidStatus;
    }
  }

  String _invoiceTitleFromQuote(String title, AppLocalizations l10n) {
    if (title == l10n.financialDocumentDefaultQuoteTitle ||
        title == 'Devis intervention piscine' ||
        title == 'Pool service quote') {
      return l10n.financialDocumentDefaultInvoiceTitle;
    }
    if (title.contains(l10n.quoteLabel)) {
      return title.replaceFirst(l10n.quoteLabel, l10n.invoiceLabel);
    }
    if (title.contains('Devis')) {
      return title.replaceFirst('Devis', l10n.invoiceLabel);
    }
    if (title.contains('Quote')) {
      return title.replaceFirst('Quote', l10n.invoiceLabel);
    }
    return title;
  }
}

class FollowPage extends StatelessWidget {
  final Client client;

  const FollowPage({super.key, required this.client});

  String trend(double oldValue, double newValue) {
    if (newValue > oldValue) return 'en hausse';
    if (newValue < oldValue) return 'en baisse';
    return 'stable';
  }

  List<String> nextActions(WaterAnalysis previous, WaterAnalysis current) {
    final actions = <String>[];

    if (current.score < previous.score) {
      actions.add(
          'La qualité de l’eau se dégrade: prévoir un contrôle rapproché.');
    } else if (current.score > previous.score) {
      actions.add('L’équilibre s’améliore: maintenir le protocole actuel.');
    }

    if (current.ph > 7.6 && current.ph >= previous.ph) {
      actions
          .add('Le pH reste haut: vérifier la régulation ou l’injection pH-.');
    }
    if (current.chlore < 1.5) {
      actions.add(
          'Le désinfectant reste bas: contrôler la production et la fréquentation.');
    }
    if (current.lsi > 0.3) {
      actions.add(
          'Le risque d’entartrage persiste: surveiller cellule, ligne d’eau et filtration.');
    } else if (current.lsi < -0.3) {
      actions.add(
          'L’eau reste agressive: confirmer pH, TAC et état des équipements.');
    }

    if (actions.isEmpty) {
      actions.add('Tendance stable: conserver le rythme de suivi prévu.');
    }

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final analyses = client.analyses;

    return Scaffold(
      appBar: AppBar(
        title: Text('Suivi - ${client.name}'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: analyses.length < 2
          ? const Center(child: Text('Pas assez d’analyses pour un suivi'))
          : Builder(
              builder: (_) {
                final oldA = analyses[analyses.length - 2];
                final newA = analyses.last;
                final actions = nextActions(oldA, newA);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _InfoCard(
                      title: 'Evolution',
                      children: [
                        _line(
                          'pH',
                          '${oldA.ph} -> ${newA.ph} (${trend(oldA.ph, newA.ph)})',
                        ),
                        _line(
                          'Chlore',
                          '${oldA.chlore} -> ${newA.chlore} (${trend(oldA.chlore, newA.chlore)})',
                        ),
                        _line(
                          'TAC',
                          '${oldA.tac} -> ${newA.tac} (${trend(oldA.tac, newA.tac)})',
                        ),
                        _line(
                          'TH',
                          '${oldA.th} -> ${newA.th} (${trend(oldA.th, newA.th)})',
                        ),
                        _line(
                          'Stabilisant',
                          '${oldA.stabilisant} -> ${newA.stabilisant} (${trend(oldA.stabilisant, newA.stabilisant)})',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: 'Scores',
                      children: [
                        Text('Ancien score : ${oldA.score}/10'),
                        const SizedBox(height: 6),
                        Text('Nouveau score : ${newA.score}/10'),
                        const SizedBox(height: 6),
                        Text(
                            'Prochain passage conseillé : ${nextVisitLabel(client)}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: 'Actions terrain recommandées',
                      children: actions
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('• $item'),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                );
              },
            ),
    );
  }

  static Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label :',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
