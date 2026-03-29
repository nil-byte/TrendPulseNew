import 'package:flutter/foundation.dart';

enum ApiBaseUrlValidationError { invalidUrl, unsupportedAndroidHttp }

abstract final class ApiBaseUrlResolver {
  static const Set<String> _supportedAndroidCleartextHosts = {
    'localhost',
    '127.0.0.1',
    '10.0.2.2',
  };

  /// Keep configured URLs explicit instead of inferring emulator behavior.
  ///
  /// `localhost` can be valid on desktop, web, and Android devices using
  /// `adb reverse`, so Android-wide silent rewriting is unsafe.
  static String resolve(String baseUrl) => baseUrl.trim();

  static ApiBaseUrlValidationError? validateBaseUrl(
    String rawUrl, {
    TargetPlatform? targetPlatform,
    bool isWeb = kIsWeb,
  }) {
    final trimmedUrl = rawUrl.trim();
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return ApiBaseUrlValidationError.invalidUrl;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return ApiBaseUrlValidationError.invalidUrl;
    }

    final effectivePlatform = targetPlatform ?? defaultTargetPlatform;
    if (!isWeb &&
        effectivePlatform == TargetPlatform.android &&
        scheme == 'http' &&
        !_supportedAndroidCleartextHosts.contains(uri.host.toLowerCase())) {
      return ApiBaseUrlValidationError.unsupportedAndroidHttp;
    }

    return null;
  }

  static String sanitizeBaseUrlForStorage(
    String? baseUrl, {
    TargetPlatform? targetPlatform,
    bool isWeb = kIsWeb,
  }) {
    final trimmedBaseUrl = baseUrl?.trim() ?? '';
    if (trimmedBaseUrl.isEmpty) {
      return '';
    }
    if (validateBaseUrl(
          trimmedBaseUrl,
          targetPlatform: targetPlatform,
          isWeb: isWeb,
        ) !=
        null) {
      return '';
    }
    return trimmedBaseUrl;
  }

  static String normalizeStoredBaseUrl(
    String? baseUrl, {
    required String fallbackBaseUrl,
    TargetPlatform? targetPlatform,
    bool isWeb = kIsWeb,
  }) {
    final sanitizedBaseUrl = sanitizeBaseUrlForStorage(
      baseUrl,
      targetPlatform: targetPlatform,
      isWeb: isWeb,
    );
    if (sanitizedBaseUrl.isEmpty) {
      return fallbackBaseUrl;
    }
    return sanitizedBaseUrl;
  }
}
