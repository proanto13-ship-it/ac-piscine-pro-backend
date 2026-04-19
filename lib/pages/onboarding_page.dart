import 'package:flutter/material.dart';

import '../main.dart';
import '../models/company_profile.dart';
import '../models/workspace_settings.dart';
import '../services/auth_service.dart';

class OnboardingPage extends StatefulWidget {
  final Future<Widget> Function()? completedPageResolver;

  const OnboardingPage({
    super.key,
    this.completedPageResolver,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final TextEditingController _companyNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _countryCodeController;
  late final TextEditingController _localeCodeController;
  late final TextEditingController _currencyCodeController;
  late final TextEditingController _businessRegistrationLabelController;
  late final TextEditingController _businessRegistrationValueController;
  late final TextEditingController _taxRegistrationValueController;
  late final TextEditingController _timeZoneIdController;
  late String _unitSystem;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    final company = AppStore.companyProfile;
    final workspace = AppStore.workspaceSettings;
    final session = AuthService.currentSession;

    _companyNameController = TextEditingController(
      text: _initialCompanyName(company),
    );
    _phoneController = TextEditingController(text: company.phone);
    _emailController = TextEditingController(
      text: company.email.trim().isNotEmpty
          ? company.email
          : (session?.email ?? ''),
    );
    _addressController = TextEditingController(text: company.address);
    _countryCodeController = TextEditingController(
      text: workspace.countryCode.isNotEmpty
          ? workspace.countryCode
          : company.countryCode,
    );
    _localeCodeController = TextEditingController(
      text: workspace.localeCode.isNotEmpty
          ? workspace.localeCode
          : company.localeCode,
    );
    _currencyCodeController = TextEditingController(
      text: workspace.currencyCode.isNotEmpty
          ? workspace.currencyCode
          : company.currencyCode,
    );
    _businessRegistrationLabelController = TextEditingController(
      text: company.businessRegistrationLabel.isNotEmpty
          ? company.businessRegistrationLabel
          : 'SIRET',
    );
    _businessRegistrationValueController = TextEditingController(
      text: company.businessRegistrationValue,
    );
    _taxRegistrationValueController = TextEditingController(
      text: company.taxRegistrationValue,
    );
    _timeZoneIdController = TextEditingController(text: workspace.timeZoneId);
    _unitSystem = workspace.unitSystem;
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _countryCodeController.dispose();
    _localeCodeController.dispose();
    _currencyCodeController.dispose();
    _businessRegistrationLabelController.dispose();
    _businessRegistrationValueController.dispose();
    _taxRegistrationValueController.dispose();
    _timeZoneIdController.dispose();
    super.dispose();
  }

  String _initialCompanyName(CompanyProfile profile) {
    final current = profile.companyName.trim();
    if (current.isEmpty || current == CompanyProfile.defaults().companyName) {
      return '';
    }
    return current;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _message = null;
    });

    final defaults = CompanyProfile.defaults();
    final workspaceDefaults = WorkspaceSettings.defaults();

    final companyProfile = AppStore.companyProfile.copyWith(
      companyName: _companyNameController.text.trim().isEmpty
          ? defaults.companyName
          : _companyNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      countryCode: _countryCodeController.text.trim().isEmpty
          ? defaults.countryCode
          : _countryCodeController.text.trim(),
      localeCode: _localeCodeController.text.trim().isEmpty
          ? defaults.localeCode
          : _localeCodeController.text.trim(),
      currencyCode: _currencyCodeController.text.trim().isEmpty
          ? defaults.currencyCode
          : _currencyCodeController.text.trim(),
      businessRegistrationLabel:
          _businessRegistrationLabelController.text.trim(),
      businessRegistrationValue:
          _businessRegistrationValueController.text.trim(),
      taxRegistrationValue: _taxRegistrationValueController.text.trim(),
    );

    final workspaceSettings = AppStore.workspaceSettings.copyWith(
      countryCode: _countryCodeController.text.trim().isEmpty
          ? workspaceDefaults.countryCode
          : _countryCodeController.text.trim(),
      localeCode: _localeCodeController.text.trim().isEmpty
          ? workspaceDefaults.localeCode
          : _localeCodeController.text.trim(),
      currencyCode: _currencyCodeController.text.trim().isEmpty
          ? workspaceDefaults.currencyCode
          : _currencyCodeController.text.trim(),
      timeZoneId: _timeZoneIdController.text.trim().isEmpty
          ? workspaceDefaults.timeZoneId
          : _timeZoneIdController.text.trim(),
      unitSystem: _unitSystem,
    );

    AppStore.companyProfile = companyProfile;
    AppStore.workspaceSettings = workspaceSettings;
    await AppStore.saveCompanyProfile();
    await AppStore.saveWorkspaceSettings();

    var savedRemotely = false;
    try {
      await AuthService.saveOrganizationProfile(
        payload: {
          'companyName': companyProfile.companyName,
          'name': companyProfile.companyName,
          'phone': companyProfile.phone,
          'email': companyProfile.email,
          'address': companyProfile.address,
          'countryCode': companyProfile.countryCode,
          'localeCode': companyProfile.localeCode,
          'currencyCode': companyProfile.currencyCode,
          'businessRegistrationLabel': companyProfile.businessRegistrationLabel,
          'businessRegistrationValue': companyProfile.businessRegistrationValue,
          'taxRegistrationValue': companyProfile.taxRegistrationValue,
          'workspaceSettings': workspaceSettings.toJson(),
          'companyProfile': companyProfile.toJson(),
        },
      );
      savedRemotely = true;
    } catch (_) {
      savedRemotely = false;
    }

    if (!mounted) return;

    final resolver = widget.completedPageResolver;
    if (resolver != null) {
      final nextPage = await resolver();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => nextPage),
        (route) => false,
      );
      return;
    }

    setState(() {
      _saving = false;
      _message = savedRemotely
          ? 'Organisation enregistrée sur l’appareil et dans le cloud.'
          : 'Organisation enregistrée localement.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration initiale'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Renseignez les informations minimales de votre organisation avant d’entrer dans l’application.',
            style: TextStyle(color: Color(0xFF475467)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _companyNameController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Nom de l’entreprise',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Téléphone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            enabled: !_saving,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            enabled: !_saving,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Adresse',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _countryCodeController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Pays',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _localeCodeController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Langue / région',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _currencyCodeController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Devise',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _businessRegistrationLabelController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Libellé d’immatriculation',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _businessRegistrationValueController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Numéro d’immatriculation',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _taxRegistrationValueController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Identifiant fiscal',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _timeZoneIdController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Fuseau horaire',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _unitSystem,
            decoration: const InputDecoration(
              labelText: 'Système d’unités',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'metric',
                child: Text('Métrique'),
              ),
              DropdownMenuItem(
                value: 'imperial',
                child: Text('Impérial'),
              ),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _unitSystem = value);
                  },
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              style: const TextStyle(color: Color(0xFF067647)),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(_saving ? 'Enregistrement…' : 'Continuer'),
          ),
        ],
      ),
    );
  }
}
