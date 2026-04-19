import 'package:intl/intl.dart';

import '../models/workspace_settings.dart';

class FormattingService {
  static String formatDateTimeFromIso(
    String iso,
    WorkspaceSettings settings,
  ) {
    final value = DateTime.tryParse(iso);
    if (value == null) return iso;

    return _formatWithLocale(
      settings: settings,
      build: (locale) =>
          DateFormat.yMd(locale).add_Hm().format(value.toLocal()),
      fallback: () => _fallbackDateTime(value.toLocal()),
    );
  }

  static String formatDateFromIso(
    String iso,
    WorkspaceSettings settings,
  ) {
    final value = DateTime.tryParse(iso);
    if (value == null) return iso;
    return formatDate(value, settings);
  }

  static String formatDate(
    DateTime value,
    WorkspaceSettings settings,
  ) {
    final localValue = value.toLocal();
    return _formatWithLocale(
      settings: settings,
      build: (locale) => DateFormat.yMd(locale).format(localValue),
      fallback: () => _fallbackDate(localValue),
    );
  }

  static String formatCurrency(
    num value,
    WorkspaceSettings settings,
  ) {
    return _formatWithLocale(
      settings: settings,
      build: (locale) => NumberFormat.currency(
        locale: locale,
        name: settings.currencyCode,
      ).format(value),
      fallback: () => '${value.toStringAsFixed(2)} ${settings.currencyCode}',
    );
  }

  static String _formatWithLocale({
    required WorkspaceSettings settings,
    required String Function(String? locale) build,
    required String Function() fallback,
  }) {
    final locale = _normalizeLocale(settings.localeCode);

    try {
      return build(locale);
    } catch (_) {
      try {
        return build(null);
      } catch (_) {
        return fallback();
      }
    }
  }

  static String _normalizeLocale(String localeCode) {
    return localeCode.replaceAll('-', '_').trim();
  }

  static String _fallbackDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  static String _fallbackDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }
}
