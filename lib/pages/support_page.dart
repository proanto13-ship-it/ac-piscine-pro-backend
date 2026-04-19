import 'package:flutter/material.dart';

import '../main.dart';
import '../models/auth_session.dart';
import 'account_data_page.dart';
import 'launch_document_page.dart';
import '../services/auth_service.dart';
import '../services/onboarding_progress_service.dart';
import '../services/support_diagnostic_service.dart';
import '../user_guide_page.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  bool _busy = false;

  Future<void> _openExportDialog({
    required SupportRequestKind kind,
    required String title,
    required bool allowMessage,
  }) async {
    final messageController = TextEditingController();
    var format = SupportExportFormat.json;

    final shouldExport = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (allowMessage) ...[
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Contexte ou message',
                    hintText: 'Expliquez rapidement le souci ou votre retour.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<SupportExportFormat>(
                initialValue: format,
                decoration: const InputDecoration(
                  labelText: 'Format',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: SupportExportFormat.json,
                    child: Text('Standard'),
                  ),
                  DropdownMenuItem(
                    value: SupportExportFormat.zip,
                    child: Text('Archive ZIP'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => format = value);
                },
              ),
              const SizedBox(height: 10),
              const Text(
                'Le fichier contient uniquement des informations non sensibles : état de synchronisation, logs récents expurgés, version, build, plateforme et identifiants non sensibles.',
                style: TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Exporter'),
            ),
          ],
        ),
      ),
    );

    if (shouldExport != true) {
      messageController.dispose();
      return;
    }

    await _exportSupportPackage(
      kind: kind,
      format: format,
      userMessage: messageController.text.trim(),
    );
    messageController.dispose();
  }

  Future<void> _exportSupportPackage({
    required SupportRequestKind kind,
    required SupportExportFormat format,
    String? userMessage,
  }) async {
    setState(() => _busy = true);
    try {
      final session = AuthService.currentSession;
      final appInfo = await SupportDiagnosticService.loadAppInfo(
        endpoint: _resolvedEndpoint(session),
      );
      final recentLogs = await SupportDiagnosticService.loadRecentLogs();
      final payload = SupportDiagnosticService.buildPayload(
        kind: kind,
        appInfo: appInfo,
        cloudSyncSettings: AppStore.cloudSyncSettings,
        recentLogs: recentLogs,
        dataSummary: _dataSummary(session),
        session: session,
        userMessage: userMessage,
      );
      final path = await SupportDiagnosticService.exportPayload(
        payload: payload,
        kind: kind,
        format: format,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Diagnostic exporté : $path')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export du diagnostic impossible pour le moment.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Map<String, dynamic> _dataSummary(AuthSession? session) {
    final activeClients = AppStore.activeClients;
    final interventions = activeClients
        .expand(
            (client) => client.interventions.where((item) => !item.isDeleted))
        .toList();
    final financialDocuments = activeClients
        .expand(
          (client) =>
              client.financialDocuments.where((item) => !item.isDeleted),
        )
        .toList();
    final attachments = interventions
        .expand((item) => item.attachments.where((entry) => !entry.isDeleted))
        .toList();

    return {
      'clientsCount': activeClients.length,
      'interventionsCount': interventions.length,
      'financialDocumentsCount': financialDocuments.length,
      'attachmentsCount': attachments.length,
      'teamMembersCount': AppStore.teamMembers.length,
      'subscriptionPlanId': AppStore.subscription.planId,
      'subscriptionStatus': AppStore.subscription.status.name,
      'onboardingDismissed':
          OnboardingProgressService.current.value.isDismissed,
      'onboardingFirstPdfGenerated':
          OnboardingProgressService.current.value.hasGeneratedFirstPdf,
      'sessionAvailable': session != null,
    };
  }

  String _resolvedEndpoint(AuthSession? session) {
    if (session != null && session.endpoint.trim().isNotEmpty) {
      return session.endpoint;
    }
    return AppStore.cloudSyncSettings.endpoint;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aide et support'),
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
              border: Border.all(color: const Color(0xFFDCE5EC)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aide et support',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF184663),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Décrivez le contexte du problème, puis exportez un diagnostic exploitable sans inclure de secrets.',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _openExportDialog(
                      kind: SupportRequestKind.bugReport,
                      title: 'Signaler un bug',
                      allowMessage: true,
                    ),
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('Signaler un bug'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _openExportDialog(
                      kind: SupportRequestKind.feedback,
                      title: 'Envoyer un retour',
                      allowMessage: true,
                    ),
            icon: const Icon(Icons.feedback_outlined),
            label: const Text('Envoyer un retour'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _openExportDialog(
                      kind: SupportRequestKind.diagnostic,
                      title: 'Exporter un diagnostic',
                      allowMessage: false,
                    ),
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('Exporter un diagnostic'),
          ),
          const SizedBox(height: 16),
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
                const Text(
                  'Contenu minimal du diagnostic',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF184663),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Version, build, plateforme, environnement, état de synchronisation, logs récents nettoyés, résumé local et identifiants non sensibles d’organisation / utilisateur si disponibles.',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aucun secret, mot de passe, clé ou jeton ne doit être inclus.',
                  style: TextStyle(
                    color: Color(0xFFB42318),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserGuidePage(),
                      ),
                    );
                  },
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Ouvrir le guide utilisateur'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AccountDataPage(),
                      ),
                    );
                  },
            icon: const Icon(Icons.manage_accounts_outlined),
            label: const Text('Compte, données et suppression'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LaunchDocumentPage(
                          title: 'FAQ',
                          assetPath: 'docs/launch/faq.md',
                        ),
                      ),
                    );
                  },
            icon: const Icon(Icons.quiz_outlined),
            label: const Text('Ouvrir la FAQ'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LaunchDocumentPage(
                                title: 'Politique de confidentialité',
                                assetPath: 'docs/launch/privacy.md',
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: const Text('Confidentialité'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LaunchDocumentPage(
                                title: 'Conditions d’utilisation',
                                assetPath: 'docs/launch/terms.md',
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.gavel_outlined),
                  label: const Text('Conditions'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD0D5DD)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'À propos',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF184663),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'HydrAzur Pro est conçu et développé par Antonio Cefaliello.',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
