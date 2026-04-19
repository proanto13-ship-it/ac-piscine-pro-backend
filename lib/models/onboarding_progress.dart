class OnboardingProgress {
  final String dismissedAtIso;
  final String firstPdfGeneratedAtIso;

  const OnboardingProgress({
    required this.dismissedAtIso,
    required this.firstPdfGeneratedAtIso,
  });

  factory OnboardingProgress.defaults() {
    return const OnboardingProgress(
      dismissedAtIso: '',
      firstPdfGeneratedAtIso: '',
    );
  }

  factory OnboardingProgress.fromJson(Map<String, dynamic> json) {
    final defaults = OnboardingProgress.defaults();
    return OnboardingProgress(
      dismissedAtIso:
          json['dismissedAtIso']?.toString() ?? defaults.dismissedAtIso,
      firstPdfGeneratedAtIso: json['firstPdfGeneratedAtIso']?.toString() ??
          defaults.firstPdfGeneratedAtIso,
    );
  }

  Map<String, dynamic> toJson() => {
        'dismissedAtIso': dismissedAtIso,
        'firstPdfGeneratedAtIso': firstPdfGeneratedAtIso,
      };

  OnboardingProgress copyWith({
    String? dismissedAtIso,
    String? firstPdfGeneratedAtIso,
  }) {
    return OnboardingProgress(
      dismissedAtIso: dismissedAtIso ?? this.dismissedAtIso,
      firstPdfGeneratedAtIso:
          firstPdfGeneratedAtIso ?? this.firstPdfGeneratedAtIso,
    );
  }

  bool get isDismissed => dismissedAtIso.trim().isNotEmpty;

  bool get hasGeneratedFirstPdf => firstPdfGeneratedAtIso.trim().isNotEmpty;
}
