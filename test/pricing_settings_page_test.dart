import 'package:ac_piscine_pro/l10n/app_localizations.dart';
import 'package:ac_piscine_pro/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpSettingsPage(WidgetTester tester, double width) async {
    AppStore.resetInMemory();

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: Size(width, 844)),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: const PricingSettingsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('settings page stays readable at iPhone widths', (tester) async {
    await pumpSettingsPage(tester, 390);
    expect(find.text('Entreprise'), findsOneWidget);
    expect(find.text('Options avancées'), findsNothing);
    expect(tester.takeException(), isNull);

    await pumpSettingsPage(tester, 375);
    expect(find.text('Entreprise'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
