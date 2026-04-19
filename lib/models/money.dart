class Money implements Comparable<Money> {
  static const int _minorUnitsPerMajor = 100;

  final int amountMinor;
  final String currencyCode;

  const Money({
    required this.amountMinor,
    required this.currencyCode,
  });

  factory Money.fromMajor(double value, String currencyCode) {
    return Money(
      amountMinor: (value * _minorUnitsPerMajor).round(),
      currencyCode: currencyCode,
    );
  }

  double toMajor() {
    return amountMinor / _minorUnitsPerMajor;
  }

  Money operator +(Money other) {
    _ensureSameCurrency(other);
    return Money(
      amountMinor: amountMinor + other.amountMinor,
      currencyCode: currencyCode,
    );
  }

  Money multiply(num factor) {
    return Money(
      amountMinor: (amountMinor * factor).round(),
      currencyCode: currencyCode,
    );
  }

  @override
  int compareTo(Money other) {
    _ensureSameCurrency(other);
    return amountMinor.compareTo(other.amountMinor);
  }

  bool operator <(Money other) => compareTo(other) < 0;

  bool operator <=(Money other) => compareTo(other) <= 0;

  bool operator >(Money other) => compareTo(other) > 0;

  bool operator >=(Money other) => compareTo(other) >= 0;

  void _ensureSameCurrency(Money other) {
    if (currencyCode != other.currencyCode) {
      throw ArgumentError(
        'Currency mismatch: $currencyCode != ${other.currencyCode}',
      );
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Money &&
        other.amountMinor == amountMinor &&
        other.currencyCode == currencyCode;
  }

  @override
  int get hashCode => Object.hash(amountMinor, currencyCode);
}
