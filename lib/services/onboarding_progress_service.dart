import 'package:flutter/foundation.dart';

import '../models/onboarding_progress.dart';
import 'app_environment.dart';
import 'local_storage_service.dart';

class OnboardingProgressService {
  static String get _fileName =>
      AppEnvironment.storageName('onboarding_progress.json');

  static final ValueNotifier<OnboardingProgress> current =
      ValueNotifier(OnboardingProgress.defaults());

  static Future<OnboardingProgress> load() async {
    final stored = await LocalStorageService.readJsonMap(_fileName);
    final progress = stored == null
        ? OnboardingProgress.defaults()
        : OnboardingProgress.fromJson(stored);
    current.value = progress;
    return progress;
  }

  static Future<void> replace(OnboardingProgress progress) async {
    current.value = progress;
    await LocalStorageService.writeJson(_fileName, progress.toJson());
  }

  static Future<void> dismissChecklist() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await replace(current.value.copyWith(dismissedAtIso: nowIso));
  }

  static Future<void> resumeChecklist() async {
    await replace(current.value.copyWith(dismissedAtIso: ''));
  }

  static Future<void> markFirstPdfGenerated() async {
    if (current.value.hasGeneratedFirstPdf) {
      return;
    }
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await replace(current.value.copyWith(firstPdfGeneratedAtIso: nowIso));
  }

  static void resetInMemory() {
    current.value = OnboardingProgress.defaults();
  }
}
