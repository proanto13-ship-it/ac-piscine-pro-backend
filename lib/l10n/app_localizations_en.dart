// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'HydrAzur Pro';

  @override
  String get save => 'Save';

  @override
  String get preview => 'Preview';

  @override
  String get reset => 'Reset';

  @override
  String get pdf => 'PDF';

  @override
  String get share => 'Share';

  @override
  String get send => 'Send';

  @override
  String get accept => 'Approve';

  @override
  String get quoteLabel => 'Quote';

  @override
  String get invoiceLabel => 'Invoice';

  @override
  String get draftStatus => 'Draft';

  @override
  String get sentStatus => 'Sent';

  @override
  String get approvedStatus => 'Approved';

  @override
  String get paidStatus => 'Paid';

  @override
  String get pricingSettingsTitle => 'Company';

  @override
  String get companyIdentityTitle => 'Company identity';

  @override
  String get companyNameLabel => 'Company name';

  @override
  String get defaultTechnicianLabel => 'Default technician';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get emailLabel => 'Email';

  @override
  String get addressLabel => 'Address';

  @override
  String get websiteLabel => 'Website';

  @override
  String get countryLabel => 'Country';

  @override
  String get localeLabel => 'Language / region';

  @override
  String get currencyLabel => 'Currency';

  @override
  String get businessRegistrationLabelField => 'Registration label';

  @override
  String get businessRegistrationValueLabel => 'Registration number';

  @override
  String get taxRegistrationValueLabel => 'Tax registration';

  @override
  String get documentMentionLabel => 'Note on documents';

  @override
  String get cloudPreparationTitle => 'Cloud sync';

  @override
  String get cloudPreparationSubtitle => 'Sign in, then keep your data in sync.';

  @override
  String get showBudgetEstimatesTitle => 'Estimated budget';

  @override
  String get showBudgetEstimatesSubtitle => 'Shows product pricing and the total in diagnostics and PDFs.';

  @override
  String get defaultLaborTitle => 'Default labor';

  @override
  String get defaultLaborSubtitle => 'Amount used in the diagnostic estimate.';

  @override
  String defaultLaborFieldLabel(String currencyCode) {
    return 'Labor ($currencyCode)';
  }

  @override
  String get productPricingTitle => 'Product pricing';

  @override
  String get productPricingSubtitle => 'Enter your minimum and maximum prices. You can use the same value in both fields to define a fixed price.';

  @override
  String get pricingSaved => 'Settings saved.';

  @override
  String unitLabel(String unit) {
    return 'Unit: $unit';
  }

  @override
  String get minPriceLabel => 'Min price';

  @override
  String get maxPriceLabel => 'Max price';

  @override
  String get cloudSettingsSaved => 'Cloud settings saved.';

  @override
  String cloudPayloadPrepared(String path) {
    return 'Sync payload prepared: $path';
  }

  @override
  String get cloudEndpointRequired => 'Please enter a cloud endpoint.';

  @override
  String get cloudSyncTitle => 'Cloud sync';

  @override
  String get enableCloudSync => 'Enable cloud sync';

  @override
  String get autoPreparePayloads => 'Automatically prepare payloads';

  @override
  String get syncModeLabel => 'Sync mode';

  @override
  String get syncModeLegacy => 'Legacy';

  @override
  String get syncModeV2 => 'V2';

  @override
  String get apiEndpointLabel => 'API endpoint';

  @override
  String get apiKeyTokenLabel => 'API key / token';

  @override
  String lastPreparedLabel(String date) {
    return 'Last payload prepared: $date';
  }

  @override
  String lastPushLabel(String date) {
    return 'Last push: $date';
  }

  @override
  String lastPullLabel(String date) {
    return 'Last pull: $date';
  }

  @override
  String statusWithValue(String status) {
    return 'Status: $status';
  }

  @override
  String get prepare => 'Prepare';

  @override
  String get pull => 'Pull';

  @override
  String get sending => 'Sending...';

  @override
  String get cloudSyncHelp => 'The endpoint must accept a JSON POST for upload and return JSON for download. A direct payload or an object with a \"payload\" key are both supported.';

  @override
  String financialDocumentUpdated(String status) {
    return 'Document updated: $status.';
  }

  @override
  String get invoiceCreatedFromQuote => 'Invoice created from the saved quote.';

  @override
  String financialDocumentsTitle(String clientName) {
    return 'Documents - $clientName';
  }

  @override
  String get noFinancialDocuments => 'No quotes or invoices saved yet';

  @override
  String get numberToAssign => 'Number to assign';

  @override
  String lineCountSummary(int count, String total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '$count line',
    );
    return '$_temp0 • $total incl. tax';
  }

  @override
  String subtotalTaxSummary(String subtotal, String taxLabel, String taxRate) {
    return 'Excl. tax $subtotal • $taxLabel $taxRate';
  }

  @override
  String depositDueSummary(String deposit, String due) {
    return 'Deposit $deposit • Due $due';
  }

  @override
  String get createInvoiceAction => 'Create invoice';

  @override
  String get markPaid => 'Mark as paid';

  @override
  String get financialDocumentDefaultQuoteTitle => 'Pool service quote';

  @override
  String get financialDocumentDefaultInvoiceTitle => 'Pool service invoice';

  @override
  String get quoteValidityDefault => 'Valid for 30 days';

  @override
  String get invoiceDueDefault => 'Payment due on receipt';

  @override
  String get quoteDepositPaymentDefault => 'Deposit on approval';

  @override
  String get invoicePaymentMethodDefault => 'Bank transfer or card';

  @override
  String get financialDocumentSavedQuote => 'Quote saved in the client file.';

  @override
  String get financialDocumentSavedInvoice => 'Invoice saved in the client file.';

  @override
  String get createQuoteTitle => 'Create quote';

  @override
  String get createInvoiceTitle => 'Create invoice';

  @override
  String get documentSectionTitle => 'Document';

  @override
  String get numberLabel => 'Number';

  @override
  String get teamTechnicianLabel => 'Team technician';

  @override
  String get titleLabel => 'Title';

  @override
  String get technicianLabel => 'Technician';

  @override
  String get statusLabel => 'Status';

  @override
  String get quoteValidityLabel => 'Quote validity';

  @override
  String get paymentDueLabel => 'Payment due';

  @override
  String get taxRateFieldLabel => 'Tax (%)';

  @override
  String get defaultTaxLabel => 'Tax';

  @override
  String get depositPaidFieldLabel => 'Deposit / already paid';

  @override
  String get quotePaymentTermsLabel => 'Payment terms';

  @override
  String get invoicePaymentTermsLabel => 'Payment method';

  @override
  String get billableLinesTitle => 'Billable lines';

  @override
  String get totalExcludingTax => 'Total excl. tax';

  @override
  String get depositLabel => 'Deposit';

  @override
  String get totalIncludingTax => 'Total incl. tax';

  @override
  String get remainingEstimate => 'Remaining estimate';

  @override
  String get netToPay => 'Net due';

  @override
  String get notesTitle => 'Notes';

  @override
  String get mentionsRemarksLabel => 'Mentions / remarks';
}
