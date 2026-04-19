import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/cloud_sync_settings.dart';
import '../services/app_environment.dart';
import '../services/app_logger.dart';
import '../services/auth_service.dart';
import 'launch_document_page.dart';
import 'support_page.dart';

class LoginPage extends StatefulWidget {
  final WidgetBuilder? authenticatedPageBuilder;
  final Future<Widget> Function()? resolveAuthenticatedPage;

  const LoginPage({
    super.key,
    this.authenticatedPageBuilder,
    this.resolveAuthenticatedPage,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _endpointController;
  final TextEditingController _organizationController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController(
      text: AppStore.cloudSyncSettings.endpoint.trim().isNotEmpty
          ? AppStore.cloudSyncSettings.endpoint
          : AppEnvironment.defaultApiBaseUrl,
    );
    _organizationController.text =
        AuthService.currentSession?.organizationId.trim() ?? '';
    _emailController.addListener(_handleFormChanged);
    _passwordController.addListener(_handleFormChanged);
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleFormChanged);
    _passwordController.removeListener(_handleFormChanged);
    _endpointController.dispose();
    _organizationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleFormChanged() {
    if (mounted) {
      setState(() {
        _error = null;
      });
    }
  }

  bool get _canSubmit =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  String get _resolvedEndpoint {
    final explicitEndpoint = _endpointController.text.trim();
    if (explicitEndpoint.isNotEmpty) {
      return explicitEndpoint;
    }
    return AppEnvironment.defaultApiBaseUrl;
  }

  Future<void> _continueLocally() async {
    await AuthService.logout();
    await clearServerSubscriptionState();
    AppStore.cloudSyncSettings = AppStore.cloudSyncSettings.copyWith(
      syncMode: CloudSyncMode.legacy,
      lastSyncStatus: 'Mode local actif.',
    );
    await AppStore.saveCloudSyncSettings();
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(false);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> _openForgotPasswordHelp() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mot de passe oublié ?'),
        content: const Text(
          'Pour le moment, la récupération du mot de passe est gérée par notre équipe support. Ouvrez le support pour obtenir de l’aide.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fermer'),
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
            child: const Text('Ouvrir le support'),
          ),
        ],
      ),
    );
  }

  String _friendlyLoginErrorMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('route inconnue') ||
        normalized.contains('http 404') ||
        normalized.contains('not found')) {
      return 'Le service de connexion n’est pas disponible sur ce serveur. Contactez le support.';
    }
    if (normalized.contains('serveur invalide') ||
        normalized.contains('adresse du serveur invalide') ||
        normalized.contains('endpoint v2 invalide')) {
      return 'Adresse du serveur invalide.';
    }
    if (normalized.contains('organization') ||
        normalized.contains('organisation')) {
      return 'La configuration de votre espace n’est pas complète. Ouvrez la configuration avancée si nécessaire.';
    }
    if (normalized.contains('401') ||
        normalized.contains('invalid') ||
        normalized.contains('incorrect') ||
        normalized.contains('mot de passe') ||
        normalized.contains('identifiant')) {
      return 'Vos identifiants sont incorrects. Vérifiez votre email et votre mot de passe.';
    }
    if (normalized.contains('socket') ||
        normalized.contains('connection') ||
        normalized.contains('network') ||
        normalized.contains('timed out') ||
        normalized.contains('endpoint')) {
      return 'Impossible de joindre le service pour le moment. Vérifiez votre connexion puis réessayez.';
    }
    return 'Connexion impossible pour le moment. Réessayez dans un instant.';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final endpoint = _resolvedEndpoint;
    if (endpoint.isEmpty) {
      setState(() {
        _error = 'Serveur de connexion non configuré. Contactez le support.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final session = await AuthService.login(
        endpoint: endpoint,
        organizationId: _organizationController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      AppStore.cloudSyncSettings = AppStore.cloudSyncSettings.copyWith(
        syncMode: CloudSyncMode.v2,
        endpoint: session.endpoint,
        lastSyncStatus: 'Connexion active.',
      );
      await AppStore.saveCloudSyncSettings();
      unawaited(
        AppLogger.event(
          'login_success',
          category: 'auth',
          data: {
            'organizationId': session.organizationId,
            'email': session.email,
            'endpoint': session.endpoint,
          },
        ),
      );
      try {
        await refreshBillingFromV2();
      } catch (_) {
        // Non bloquant: on garde le fallback local.
      }
      try {
        await hydrateOrganizationSetupFromV2IfPossible();
      } catch (_) {
        // Non bloquant: on garde le fallback local.
      }
      try {
        await refreshTeamFromV2();
      } catch (_) {
        // Non bloquant: on garde le fallback local.
      }

      if (!mounted) return;
      final resolvedBuilder = widget.resolveAuthenticatedPage;
      if (resolvedBuilder != null) {
        final nextPage = await resolvedBuilder();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => nextPage),
          (route) => false,
        );
        return;
      }
      final builder = widget.authenticatedPageBuilder;
      if (builder != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: builder),
          (route) => false,
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } on AuthException catch (error) {
      unawaited(
        AppLogger.warning(
          'login_failed',
          category: 'auth',
          data: {
            'organizationId': _organizationController.text.trim(),
            'email': _emailController.text.trim(),
            'endpoint': _endpointController.text.trim(),
            'message': error.message,
          },
        ),
      );
      if (!mounted) return;
      setState(() => _error = _friendlyLoginErrorMessage(error.message));
    } catch (error) {
      unawaited(
        AppLogger.error(
          'login_unexpected_error',
          category: 'auth',
          error: error,
          data: {
            'organizationId': _organizationController.text.trim(),
            'email': _emailController.text.trim(),
          },
        ),
      );
      if (!mounted) return;
      setState(
        () => _error =
            'Connexion impossible pour le moment. Réessayez dans un instant.',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSession = AuthService.currentSession;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Se connecter'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Retrouvez vos clients, interventions, rapports et droits Pro sur tous vos appareils.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF475467),
                ),
              ),
              if (currentSession != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Connexion enregistrée sur cet iPhone : ${currentSession.email}',
                  style: const TextStyle(color: Color(0xFF667085)),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email professionnel',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _openForgotPasswordHelp,
                  child:
                      const Text('Mot de passe oublié ? Contactez le support.'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _busy || !_canSubmit ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login),
                label: Text(_busy ? 'Connexion en cours…' : 'Se connecter'),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
                title: const Text('Configuration avancée'),
                subtitle: const Text(
                  'À utiliser seulement si votre organisation vous a transmis des réglages spécifiques.',
                ),
                children: [
                  TextField(
                    controller: _endpointController,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Adresse du service',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _organizationController,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Identifiant de votre organisation',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Pas encore de compte ? Contactez-nous pour activer votre espace.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF667085),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
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
                      'Informations utiles',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF184663),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Vous pouvez continuer sans compte. Les données restent sur cet appareil. La synchronisation cloud et l’abonnement Pro nécessitent une connexion.',
                      style: TextStyle(
                        color: Color(0xFF667085),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _continueLocally,
                      icon: const Icon(Icons.phone_iphone_outlined),
                      label: const Text('Continuer en local'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SupportPage(),
                                ),
                              );
                            },
                      icon: const Icon(Icons.support_agent_outlined),
                      label: const Text('Aide et support'),
                    ),
                    const SizedBox(height: 12),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
