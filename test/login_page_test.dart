import 'package:ac_piscine_pro/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login button is disabled until email and password are filled',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(),
      ),
    );

    FilledButton button() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Se connecter'));

    expect(button().onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Email professionnel'),
      'demo-pro@hydrazur.test',
    );
    await tester.pump();
    expect(button().onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Mot de passe'),
      'demo1234',
    );
    await tester.pump();
    expect(button().onPressed, isNotNull);
  });

  testWidgets('shows a clear message when the server is not configured',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Email professionnel'),
      'demo-pro@hydrazur.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Mot de passe'),
      'demo1234',
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
    await tester.pump();

    expect(
      find.text('Serveur de connexion non configuré. Contactez le support.'),
      findsOneWidget,
    );
  });
}
