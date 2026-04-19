import 'package:flutter/material.dart';

import '../main.dart';
import 'launch_document_page.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/demo_data_service.dart';

class AccountDataPage extends StatefulWidget {
  const AccountDataPage({super.key});

  @override
  State<AccountDataPage> createState() => _AccountDataPageState();
}

class _AccountDataPageState extends State<AccountDataPage> {
  bool _busy = false;
  bool _isDemoMode = false;

  @override
  void initState() {
    super.initState();
    _refreshMode();
  }

  Future<void> _refreshMode() async {
    final isDemoMode = await DemoDataService.isDemoModeEnabled();
    if (!mounted) return;
    setState(() => _isDemoMode = isDemoMode);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _exportLocalJson() async {
    setState(() => _busy = true);
    try {
      await BackupService.createBackup(AppStore.exportPayload());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sauvegarde créée. Vous pouvez maintenant la partager ou la conserver.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _exportBackendData() async {
    setState(() => _busy = true);
    try {
      final payload = await AuthService.exportAccountData();
      if (payload == null) {
        throw const AuthException(
          'Aucune connexion active pour exporter les données cloud.',
        );
      }
      await BackupService.createBackup(
        {
          'kind': 'account_backend_export',
          'exportedAtIso': DateTime.now().toIso8601String(),
          'payload': payload,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Export cloud créé. Vous pouvez maintenant le conserver.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export cloud impossible pour le moment.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteLocalData() async {
    final confirmed = await _confirm(
      title: 'Réinitialiser les données locales',
      message:
          'Toutes les données locales, sauvegardes, médias et informations stockées sur cet appareil seront supprimés. Toute connexion locale sera aussi effacée.',
      confirmLabel: 'Réinitialiser',
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await AppStore.clearLocalData();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _loadDemoData() async {
    final confirmed = await _confirm(
      title: 'Charger les donnees demo',
      message:
          'Cette action efface d’abord les données locales actuelles, déconnecte la session en cours, puis charge un jeu d’exemples réalistes pour les démonstrations.',
      confirmLabel: 'Charger la demo',
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await AppStore.clearLocalData();
      final payload = await DemoDataService.buildDemoPayload();
      await AppStore.importPayload(payload);
      await DemoDataService.enableDemoMode();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chargement demo impossible: $error')),
      );
      setState(() => _busy = false);
    }
  }

  Future<void> _deleteBackendAccount() async {
    final confirmed = await _confirm(
      title: 'Supprimer le compte cloud',
      message:
          'Cette action supprime votre compte cloud. Si vous êtes le dernier utilisateur de l’organisation, les données serveur associées pourront aussi être effacées.',
      confirmLabel: 'Supprimer le compte',
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await AuthService.deleteAccount();
      await AppStore.clearLocalData();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suppression du compte impossible : $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthService.currentSession;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compte et données'),
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
                const Text(
                  'Confidentialité',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  session == null
                      ? 'Les données locales restent sur l’appareil. Sans connexion cloud, la suppression du compte à distance n’est pas disponible.'
                      : 'Les données locales restent sur l’appareil. Les données synchronisées sont rattachées à votre organisation ${session.organizationId}.',
                  style: const TextStyle(
                    color: Color(0xFF475467),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isDemoMode
                      ? 'Des données d’exemple sont actuellement chargées sur cet appareil. Elles restent séparées de vos données réelles.'
                      : 'Vos données locales restent distinctes des données d’exemple éventuelles.',
                  style: const TextStyle(
                    color: Color(0xFF475467),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Limites actuelles : export local au format standard uniquement, sans archive ZIP ni portail légal complet pour le moment.',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (DemoDataService.isAvailable) ...[
            FilledButton.icon(
              onPressed: _busy ? null : _loadDemoData,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Charger les donnees demo'),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: _busy ? null : _exportLocalJson,
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Exporter mes données locales'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy || session == null ? null : _exportBackendData,
            icon: const Icon(Icons.cloud_download_outlined),
            label: const Text('Exporter mes données cloud'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _deleteLocalData,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Réinitialiser mes données locales'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            onPressed: _busy || session == null ? null : _deleteBackendAccount,
            icon: const Icon(Icons.person_remove_outlined),
            label: const Text('Demander la suppression de mon compte'),
          ),
          if (session == null) ...[
            const SizedBox(height: 12),
            const Text(
              'Connectez-vous pour exporter vos données cloud ou demander la suppression du compte.',
              style: TextStyle(color: Color(0xFF667085)),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LaunchDocumentPage(
                          title: 'Politique de confidentialité',
                          assetPath: 'docs/launch/privacy.md',
                        ),
                      ),
                    );
                  },
            child: const Text('Confidentialité'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LaunchDocumentPage(
                          title: 'Conditions d’utilisation',
                          assetPath: 'docs/launch/terms.md',
                        ),
                      ),
                    );
                  },
            child: const Text('Conditions'),
          ),
        ],
      ),
    );
  }
}
