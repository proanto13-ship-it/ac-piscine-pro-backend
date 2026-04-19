// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'HydrAzur Pro';

  @override
  String get save => 'Enregistrer';

  @override
  String get preview => 'Prévisualiser';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get pdf => 'PDF';

  @override
  String get share => 'Partager';

  @override
  String get send => 'Envoyer';

  @override
  String get accept => 'Accepter';

  @override
  String get quoteLabel => 'Devis';

  @override
  String get invoiceLabel => 'Facture';

  @override
  String get draftStatus => 'Brouillon';

  @override
  String get sentStatus => 'Envoyé';

  @override
  String get approvedStatus => 'Accepté';

  @override
  String get paidStatus => 'Payé';

  @override
  String get pricingSettingsTitle => 'Entreprise';

  @override
  String get companyIdentityTitle => 'Identité entreprise';

  @override
  String get companyNameLabel => 'Nom de l’entreprise';

  @override
  String get defaultTechnicianLabel => 'Technicien par défaut';

  @override
  String get phoneLabel => 'Téléphone';

  @override
  String get emailLabel => 'Email';

  @override
  String get addressLabel => 'Adresse';

  @override
  String get websiteLabel => 'Site web';

  @override
  String get countryLabel => 'Pays';

  @override
  String get localeLabel => 'Langue / région';

  @override
  String get currencyLabel => 'Devise';

  @override
  String get businessRegistrationLabelField => 'Libellé d’immatriculation';

  @override
  String get businessRegistrationValueLabel => 'Numéro d’immatriculation';

  @override
  String get taxRegistrationValueLabel => 'Identifiant fiscal';

  @override
  String get documentMentionLabel => 'Mention sur les documents';

  @override
  String get cloudPreparationTitle => 'Synchronisation cloud';

  @override
  String get cloudPreparationSubtitle => 'Connectez-vous puis synchronisez vos données.';

  @override
  String get showBudgetEstimatesTitle => 'Budget estimatif';

  @override
  String get showBudgetEstimatesSubtitle => 'Affiche le chiffrage des produits et le total dans le diagnostic et le PDF.';

  @override
  String get defaultLaborTitle => 'Main-d’œuvre par défaut';

  @override
  String get defaultLaborSubtitle => 'Montant utilisé dans le chiffrage du diagnostic.';

  @override
  String defaultLaborFieldLabel(String currencyCode) {
    return 'Main-d’œuvre ($currencyCode)';
  }

  @override
  String get productPricingTitle => 'Tarifs produits';

  @override
  String get productPricingSubtitle => 'Renseignez vos tarifs minimum et maximum. Vous pouvez saisir le même montant dans les deux champs pour définir un prix fixe.';

  @override
  String get pricingSaved => 'Réglages enregistrés.';

  @override
  String unitLabel(String unit) {
    return 'Unité : $unit';
  }

  @override
  String get minPriceLabel => 'Prix mini';

  @override
  String get maxPriceLabel => 'Prix maxi';

  @override
  String get cloudSettingsSaved => 'Réglages cloud enregistrés.';

  @override
  String cloudPayloadPrepared(String path) {
    return 'Payload de synchro préparé: $path';
  }

  @override
  String get cloudEndpointRequired => 'Renseigne un endpoint cloud.';

  @override
  String get cloudSyncTitle => 'Synchronisation cloud';

  @override
  String get enableCloudSync => 'Activer la synchro cloud';

  @override
  String get autoPreparePayloads => 'Préparer automatiquement les payloads';

  @override
  String get syncModeLabel => 'Mode de synchro';

  @override
  String get syncModeLegacy => 'Legacy';

  @override
  String get syncModeV2 => 'V2';

  @override
  String get apiEndpointLabel => 'Endpoint API';

  @override
  String get apiKeyTokenLabel => 'Clé API / token';

  @override
  String lastPreparedLabel(String date) {
    return 'Dernier payload préparé : $date';
  }

  @override
  String lastPushLabel(String date) {
    return 'Dernier envoi : $date';
  }

  @override
  String lastPullLabel(String date) {
    return 'Dernière récupération : $date';
  }

  @override
  String statusWithValue(String status) {
    return 'Statut : $status';
  }

  @override
  String get prepare => 'Préparer';

  @override
  String get pull => 'Récupérer';

  @override
  String get sending => 'En cours...';

  @override
  String get cloudSyncHelp => 'L’endpoint doit accepter un POST JSON pour l’envoi et retourner un JSON pour la récupération. Un payload direct ou un objet avec une clé \"payload\" sont supportés.';

  @override
  String financialDocumentUpdated(String status) {
    return 'Document mis à jour : $status.';
  }

  @override
  String get invoiceCreatedFromQuote => 'Facture créée à partir du devis enregistré.';

  @override
  String financialDocumentsTitle(String clientName) {
    return 'Documents - $clientName';
  }

  @override
  String get noFinancialDocuments => 'Aucun devis ni aucune facture enregistrés';

  @override
  String get numberToAssign => 'Numéro à attribuer';

  @override
  String lineCountSummary(int count, String total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes',
      one: '$count ligne',
    );
    return '$_temp0 • $total TTC';
  }

  @override
  String subtotalTaxSummary(String subtotal, String taxLabel, String taxRate) {
    return 'HT $subtotal • $taxLabel $taxRate';
  }

  @override
  String depositDueSummary(String deposit, String due) {
    return 'Acompte $deposit • Reste $due';
  }

  @override
  String get createInvoiceAction => 'Créer la facture';

  @override
  String get markPaid => 'Marquer comme payé';

  @override
  String get financialDocumentDefaultQuoteTitle => 'Devis intervention piscine';

  @override
  String get financialDocumentDefaultInvoiceTitle => 'Facture intervention piscine';

  @override
  String get quoteValidityDefault => 'Valable 30 jours';

  @override
  String get invoiceDueDefault => 'Paiement à réception';

  @override
  String get quoteDepositPaymentDefault => 'Acompte à validation';

  @override
  String get invoicePaymentMethodDefault => 'Virement ou CB';

  @override
  String get financialDocumentSavedQuote => 'Devis enregistré dans le dossier client.';

  @override
  String get financialDocumentSavedInvoice => 'Facture enregistrée dans le dossier client.';

  @override
  String get createQuoteTitle => 'Créer un devis';

  @override
  String get createInvoiceTitle => 'Créer une facture';

  @override
  String get documentSectionTitle => 'Document';

  @override
  String get numberLabel => 'Numéro';

  @override
  String get teamTechnicianLabel => 'Technicien de l’équipe';

  @override
  String get titleLabel => 'Titre';

  @override
  String get technicianLabel => 'Technicien';

  @override
  String get statusLabel => 'Statut';

  @override
  String get quoteValidityLabel => 'Validité du devis';

  @override
  String get paymentDueLabel => 'Échéance de paiement';

  @override
  String get taxRateFieldLabel => 'TVA (%)';

  @override
  String get defaultTaxLabel => 'TVA';

  @override
  String get depositPaidFieldLabel => 'Acompte / déjà payé';

  @override
  String get quotePaymentTermsLabel => 'Modalité de règlement';

  @override
  String get invoicePaymentTermsLabel => 'Mode de règlement';

  @override
  String get billableLinesTitle => 'Lignes facturables';

  @override
  String get totalExcludingTax => 'Total HT';

  @override
  String get depositLabel => 'Acompte';

  @override
  String get totalIncludingTax => 'Total TTC';

  @override
  String get remainingEstimate => 'Reste à prévoir';

  @override
  String get netToPay => 'Net à payer';

  @override
  String get notesTitle => 'Notes';

  @override
  String get mentionsRemarksLabel => 'Mentions / remarques';
}
