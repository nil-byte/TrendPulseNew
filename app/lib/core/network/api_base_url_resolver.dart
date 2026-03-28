import 'package:flutter/foundation.dart';

abstract final class ApiBaseUrlResolver {
  static const String _androidEmulatorHost = '10.0.2.2';

  static String resolve(
    String baseUrl, {
    TargetPlatform? targetPlatform,
    bool isWeb = kIsWeb,
  }) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) {
      return baseUrl;
    }

    if (isWeb) {
      return baseUrl;
    }

    final effectivePlatform = targetPlatform ?? defaultTargetPlatform;
    if (effectivePlatform != TargetPlatform.android) {
      return baseUrl;
    }

    if (!_isLoopbackHost(uri.host)) {
      return baseUrl;
    }

    return uri.replace(host: _androidEmulatorHost).toString();
  }

  static bool isLoopbackHost(String? host) =>
      host == 'localhost' || host == '127.0.0.1';

  static bool _isLoopbackHost(String host) => isLoopbackHost(host);
}
