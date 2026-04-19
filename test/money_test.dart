import 'package:flutter_test/flutter_test.dart';

import 'package:ac_piscine_pro/models/money.dart';

void main() {
  group('Money', () {
    test('convertit un montant major en minor units', () {
      final money = Money.fromMajor(12.34, 'EUR');

      expect(money.amountMinor, 1234);
      expect(money.currencyCode, 'EUR');
      expect(money.toMajor(), 12.34);
    });

    test('arrondit fromMajor au centime le plus proche', () {
      expect(Money.fromMajor(10.235, 'EUR').amountMinor, 1024);
      expect(Money.fromMajor(10.234, 'EUR').amountMinor, 1023);
      expect(Money.fromMajor(-10.235, 'EUR').amountMinor, -1024);
    });

    test('additionne deux montants de meme devise', () {
      final left = Money.fromMajor(10.25, 'EUR');
      final right = Money.fromMajor(2.10, 'EUR');

      expect(left + right, const Money(amountMinor: 1235, currencyCode: 'EUR'));
    });

    test('multiplie avec un arrondi controle', () {
      final money = Money.fromMajor(10.05, 'EUR');

      expect(money.multiply(1.5),
          const Money(amountMinor: 1508, currencyCode: 'EUR'));
      expect(money.multiply(0.333),
          const Money(amountMinor: 335, currencyCode: 'EUR'));
    });

    test('compare des montants de meme devise', () {
      const small = Money(amountMinor: 500, currencyCode: 'EUR');
      const large = Money(amountMinor: 750, currencyCode: 'EUR');

      expect(small.compareTo(large), lessThan(0));
      expect(small < large, isTrue);
      expect(small <= large, isTrue);
      expect(large > small, isTrue);
      expect(large >= small, isTrue);
    });

    test('refuse addition et comparaison entre devises differentes', () {
      const eur = Money(amountMinor: 100, currencyCode: 'EUR');
      const usd = Money(amountMinor: 100, currencyCode: 'USD');

      expect(() => eur + usd, throwsArgumentError);
      expect(() => eur.compareTo(usd), throwsArgumentError);
    });
  });
}
