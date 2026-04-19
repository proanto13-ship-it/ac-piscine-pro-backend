import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'HydrAzur Pro'**
  String get appTitle;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @pdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get pdf;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get accept;

  /// No description provided for @quoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get quoteLabel;

  /// No description provided for @invoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoiceLabel;

  /// No description provided for @draftStatus.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draftStatus;

  /// No description provided for @sentStatus.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sentStatus;

  /// No description provided for @approvedStatus.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approvedStatus;

  /// No description provided for @paidStatus.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paidStatus;

  /// No description provided for @pricingSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get pricingSettingsTitle;

  /// No description provided for @companyIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'Company identity'**
  String get companyIdentityTitle;

  /// No description provided for @companyNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Company name'**
  String get companyNameLabel;

  /// No description provided for @defaultTechnicianLabel.
  ///
  /// In en, this message translates to:
  /// **'Default technician'**
  String get defaultTechnicianLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @addressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressLabel;

  /// No description provided for @websiteLabel.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get websiteLabel;

  /// No description provided for @countryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get countryLabel;

  /// No description provided for @localeLabel.
  ///
  /// In en, this message translates to:
  /// **'Language / region'**
  String get localeLabel;

  /// No description provided for @currencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currencyLabel;

  /// No description provided for @businessRegistrationLabelField.
  ///
  /// In en, this message translates to:
  /// **'Registration label'**
  String get businessRegistrationLabelField;

  /// No description provided for @businessRegistrationValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Registration number'**
  String get businessRegistrationValueLabel;

  /// No description provided for @taxRegistrationValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax registration'**
  String get taxRegistrationValueLabel;

  /// No description provided for @documentMentionLabel.
  ///
  /// In en, this message translates to:
  /// **'Note on documents'**
  String get documentMentionLabel;

  /// No description provided for @cloudPreparationTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get cloudPreparationTitle;

  /// No description provided for @cloudPreparationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in, then keep your data in sync.'**
  String get cloudPreparationSubtitle;

  /// No description provided for @showBudgetEstimatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Estimated budget'**
  String get showBudgetEstimatesTitle;

  /// No description provided for @showBudgetEstimatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shows product pricing and the total in diagnostics and PDFs.'**
  String get showBudgetEstimatesSubtitle;

  /// No description provided for @defaultLaborTitle.
  ///
  /// In en, this message translates to:
  /// **'Default labor'**
  String get defaultLaborTitle;

  /// No description provided for @defaultLaborSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Amount used in the diagnostic estimate.'**
  String get defaultLaborSubtitle;

  /// No description provided for @defaultLaborFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Labor ({currencyCode})'**
  String defaultLaborFieldLabel(String currencyCode);

  /// No description provided for @productPricingTitle.
  ///
  /// In en, this message translates to:
  /// **'Product pricing'**
  String get productPricingTitle;

  /// No description provided for @productPricingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your minimum and maximum prices. You can use the same value in both fields to define a fixed price.'**
  String get productPricingSubtitle;

  /// No description provided for @pricingSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved.'**
  String get pricingSaved;

  /// No description provided for @unitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit: {unit}'**
  String unitLabel(String unit);

  /// No description provided for @minPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Min price'**
  String get minPriceLabel;

  /// No description provided for @maxPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Max price'**
  String get maxPriceLabel;

  /// No description provided for @cloudSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Cloud settings saved.'**
  String get cloudSettingsSaved;

  /// No description provided for @cloudPayloadPrepared.
  ///
  /// In en, this message translates to:
  /// **'Sync payload prepared: {path}'**
  String cloudPayloadPrepared(String path);

  /// No description provided for @cloudEndpointRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a cloud endpoint.'**
  String get cloudEndpointRequired;

  /// No description provided for @cloudSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get cloudSyncTitle;

  /// No description provided for @enableCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Enable cloud sync'**
  String get enableCloudSync;

  /// No description provided for @autoPreparePayloads.
  ///
  /// In en, this message translates to:
  /// **'Automatically prepare payloads'**
  String get autoPreparePayloads;

  /// No description provided for @syncModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Sync mode'**
  String get syncModeLabel;

  /// No description provided for @syncModeLegacy.
  ///
  /// In en, this message translates to:
  /// **'Legacy'**
  String get syncModeLegacy;

  /// No description provided for @syncModeV2.
  ///
  /// In en, this message translates to:
  /// **'V2'**
  String get syncModeV2;

  /// No description provided for @apiEndpointLabel.
  ///
  /// In en, this message translates to:
  /// **'API endpoint'**
  String get apiEndpointLabel;

  /// No description provided for @apiKeyTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'API key / token'**
  String get apiKeyTokenLabel;

  /// No description provided for @lastPreparedLabel.
  ///
  /// In en, this message translates to:
  /// **'Last payload prepared: {date}'**
  String lastPreparedLabel(String date);

  /// No description provided for @lastPushLabel.
  ///
  /// In en, this message translates to:
  /// **'Last push: {date}'**
  String lastPushLabel(String date);

  /// No description provided for @lastPullLabel.
  ///
  /// In en, this message translates to:
  /// **'Last pull: {date}'**
  String lastPullLabel(String date);

  /// No description provided for @statusWithValue.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String statusWithValue(String status);

  /// No description provided for @prepare.
  ///
  /// In en, this message translates to:
  /// **'Prepare'**
  String get prepare;

  /// No description provided for @pull.
  ///
  /// In en, this message translates to:
  /// **'Pull'**
  String get pull;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sending;

  /// No description provided for @cloudSyncHelp.
  ///
  /// In en, this message translates to:
  /// **'The endpoint must accept a JSON POST for upload and return JSON for download. A direct payload or an object with a \"payload\" key are both supported.'**
  String get cloudSyncHelp;

  /// No description provided for @financialDocumentUpdated.
  ///
  /// In en, this message translates to:
  /// **'Document updated: {status}.'**
  String financialDocumentUpdated(String status);

  /// No description provided for @invoiceCreatedFromQuote.
  ///
  /// In en, this message translates to:
  /// **'Invoice created from the saved quote.'**
  String get invoiceCreatedFromQuote;

  /// No description provided for @financialDocumentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents - {clientName}'**
  String financialDocumentsTitle(String clientName);

  /// No description provided for @noFinancialDocuments.
  ///
  /// In en, this message translates to:
  /// **'No quotes or invoices saved yet'**
  String get noFinancialDocuments;

  /// No description provided for @numberToAssign.
  ///
  /// In en, this message translates to:
  /// **'Number to assign'**
  String get numberToAssign;

  /// No description provided for @lineCountSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} line} other{{count} lines}} • {total} incl. tax'**
  String lineCountSummary(int count, String total);

  /// No description provided for @subtotalTaxSummary.
  ///
  /// In en, this message translates to:
  /// **'Excl. tax {subtotal} • {taxLabel} {taxRate}'**
  String subtotalTaxSummary(String subtotal, String taxLabel, String taxRate);

  /// No description provided for @depositDueSummary.
  ///
  /// In en, this message translates to:
  /// **'Deposit {deposit} • Due {due}'**
  String depositDueSummary(String deposit, String due);

  /// No description provided for @createInvoiceAction.
  ///
  /// In en, this message translates to:
  /// **'Create invoice'**
  String get createInvoiceAction;

  /// No description provided for @markPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get markPaid;

  /// No description provided for @financialDocumentDefaultQuoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Pool service quote'**
  String get financialDocumentDefaultQuoteTitle;

  /// No description provided for @financialDocumentDefaultInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Pool service invoice'**
  String get financialDocumentDefaultInvoiceTitle;

  /// No description provided for @quoteValidityDefault.
  ///
  /// In en, this message translates to:
  /// **'Valid for 30 days'**
  String get quoteValidityDefault;

  /// No description provided for @invoiceDueDefault.
  ///
  /// In en, this message translates to:
  /// **'Payment due on receipt'**
  String get invoiceDueDefault;

  /// No description provided for @quoteDepositPaymentDefault.
  ///
  /// In en, this message translates to:
  /// **'Deposit on approval'**
  String get quoteDepositPaymentDefault;

  /// No description provided for @invoicePaymentMethodDefault.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer or card'**
  String get invoicePaymentMethodDefault;

  /// No description provided for @financialDocumentSavedQuote.
  ///
  /// In en, this message translates to:
  /// **'Quote saved in the client file.'**
  String get financialDocumentSavedQuote;

  /// No description provided for @financialDocumentSavedInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice saved in the client file.'**
  String get financialDocumentSavedInvoice;

  /// No description provided for @createQuoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Create quote'**
  String get createQuoteTitle;

  /// No description provided for @createInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Create invoice'**
  String get createInvoiceTitle;

  /// No description provided for @documentSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get documentSectionTitle;

  /// No description provided for @numberLabel.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get numberLabel;

  /// No description provided for @teamTechnicianLabel.
  ///
  /// In en, this message translates to:
  /// **'Team technician'**
  String get teamTechnicianLabel;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @technicianLabel.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get technicianLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @quoteValidityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quote validity'**
  String get quoteValidityLabel;

  /// No description provided for @paymentDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment due'**
  String get paymentDueLabel;

  /// No description provided for @taxRateFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax (%)'**
  String get taxRateFieldLabel;

  /// No description provided for @defaultTaxLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get defaultTaxLabel;

  /// No description provided for @depositPaidFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Deposit / already paid'**
  String get depositPaidFieldLabel;

  /// No description provided for @quotePaymentTermsLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment terms'**
  String get quotePaymentTermsLabel;

  /// No description provided for @invoicePaymentTermsLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get invoicePaymentTermsLabel;

  /// No description provided for @billableLinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Billable lines'**
  String get billableLinesTitle;

  /// No description provided for @totalExcludingTax.
  ///
  /// In en, this message translates to:
  /// **'Total excl. tax'**
  String get totalExcludingTax;

  /// No description provided for @depositLabel.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get depositLabel;

  /// No description provided for @totalIncludingTax.
  ///
  /// In en, this message translates to:
  /// **'Total incl. tax'**
  String get totalIncludingTax;

  /// No description provided for @remainingEstimate.
  ///
  /// In en, this message translates to:
  /// **'Remaining estimate'**
  String get remainingEstimate;

  /// No description provided for @netToPay.
  ///
  /// In en, this message translates to:
  /// **'Net due'**
  String get netToPay;

  /// No description provided for @notesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesTitle;

  /// No description provided for @mentionsRemarksLabel.
  ///
  /// In en, this message translates to:
  /// **'Mentions / remarks'**
  String get mentionsRemarksLabel;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'fr': return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
