import 'package:flutter/foundation.dart';

enum DeploymentEnvironment {
  dev,
  staging,
  prod,
}

class AppEnvironment {
  static const String _rawEnvironment =
      String.fromEnvironment('APP_ENV', defaultValue: '');
  static const String _rawApiBaseUrl =
      String.fromEnvironment('APP_API_BASE_URL', defaultValue: '');
  static const String _rawAppNameSuffix =
      String.fromEnvironment('APP_NAME_SUFFIX', defaultValue: '');
  static const String _rawEnableDemoMode =
      String.fromEnvironment('APP_ENABLE_DEMO_MODE', defaultValue: '');
  static const String _rawVerboseLogs =
      String.fromEnvironment('APP_ENABLE_VERBOSE_LOGS', defaultValue: '');
  static const String _rawEnableNativeBilling =
      String.fromEnvironment('APP_ENABLE_NATIVE_BILLING', defaultValue: '');
  static const String _rawIosProProductId = String.fromEnvironment(
      'APP_BILLING_IOS_PRO_PRODUCT_ID',
      defaultValue: '');
  static const String _rawAndroidProProductId = String.fromEnvironment(
      'APP_BILLING_ANDROID_PRO_PRODUCT_ID',
      defaultValue: '');

  static DeploymentEnvironment get current {
    switch (_rawEnvironment.trim().toLowerCase()) {
      case 'staging':
        return DeploymentEnvironment.staging;
      case 'prod':
      case 'production':
        return DeploymentEnvironment.prod;
      case 'dev':
        return DeploymentEnvironment.dev;
      default:
        return kReleaseMode
            ? DeploymentEnvironment.prod
            : DeploymentEnvironment.dev;
    }
  }

  static bool get isExplicitlyConfigured =>
      _rawEnvironment.trim().toLowerCase().isNotEmpty;

  static String get name => current.name;

  static String get storagePrefix {
    if (!isExplicitlyConfigured || current == DeploymentEnvironment.prod) {
      return '';
    }
    return '${current.name}_';
  }

  static String storageName(String baseName) {
    return storagePrefix.isEmpty ? baseName : '$storagePrefix$baseName';
  }

  static String folderName(String baseFolderName) {
    return storagePrefix.isEmpty
        ? baseFolderName
        : '$storagePrefix$baseFolderName';
  }

  static String get appNameSuffix {
    final explicitSuffix = _rawAppNameSuffix.trim();
    if (explicitSuffix.isNotEmpty) {
      return explicitSuffix;
    }
    if (!isExplicitlyConfigured) {
      return '';
    }
    switch (current) {
      case DeploymentEnvironment.dev:
        return ' DEV';
      case DeploymentEnvironment.staging:
        return ' STAGING';
      case DeploymentEnvironment.prod:
        return '';
    }
  }

  static String appDisplayName([String baseName = 'HydrAzur Pro']) {
    final suffix = appNameSuffix;
    if (suffix.isEmpty) {
      return baseName;
    }
    return '$baseName$suffix';
  }

  static String get defaultApiBaseUrl {
    final explicitUrl = _rawApiBaseUrl.trim();
    if (explicitUrl.isNotEmpty) {
      return explicitUrl;
    }
    if (isExplicitlyConfigured && current == DeploymentEnvironment.dev) {
      return 'http://127.0.0.1:8788/v2';
    }
    return '';
  }

  static bool get enableDemoMode {
    final override = _parseBool(_rawEnableDemoMode);
    if (override != null) {
      return override;
    }
    return current != DeploymentEnvironment.prod;
  }

  static bool get enableVerboseLogs {
    final override = _parseBool(_rawVerboseLogs);
    if (override != null) {
      return override;
    }
    return current != DeploymentEnvironment.prod;
  }

  static bool get enableNativeBilling {
    final override = _parseBool(_rawEnableNativeBilling);
    if (override != null) {
      return override;
    }
    return false;
  }

  static String get iosProProductId => _rawIosProProductId.trim();

  static String get androidProProductId => _rawAndroidProProductId.trim();

  static bool get hasNativeBillingProductIds =>
      iosProProductId.isNotEmpty || androidProProductId.isNotEmpty;

  static bool? _parseBool(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
      default:
        return null;
    }
  }
}
