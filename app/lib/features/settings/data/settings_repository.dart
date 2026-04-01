import 'package:shared_preferences/shared_preferences.dart';

import 'package:trendpulse/core/network/api_client.dart';
import 'package:trendpulse/core/network/api_endpoints.dart';

class SettingsRepository {
  static const _keyBaseUrl = 'settings_base_url';
  static const _keyLanguage = 'settings_language';
  static const _keyReportLanguage = 'settings_report_language';
  static const _keyMaxItems = 'settings_max_items';
  static const _keyThemeMode = 'settings_theme_mode';
  static const _keyInAppNotify = 'in_app_notify';
  final ApiClient? _apiClient;
  final ApiClient Function(String? baseUrl)? _readApiClient;

  SettingsRepository({
    ApiClient? apiClient,
    ApiClient Function(String? baseUrl)? readApiClient,
  }) : _apiClient = apiClient,
       _readApiClient = readApiClient;

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUrl = prefs.getString(_keyBaseUrl)?.trim();
    if (storedUrl == null || storedUrl.isEmpty) {
      return ApiEndpoints.defaultBaseUrl;
    }
    return storedUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      await prefs.remove(_keyBaseUrl);
      return;
    }
    await prefs.setString(_keyBaseUrl, trimmedUrl);
  }

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage) ?? 'zh';
  }

  Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, language);
  }

  Future<String> getCachedReportLanguage({
    String fallbackLanguage = 'zh',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyReportLanguage) ?? fallbackLanguage;
  }

  Future<void> setCachedReportLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyReportLanguage, language);
  }

  Future<String> getReportLanguage({String? baseUrl}) async {
    final response = await _clientForBaseUrl(baseUrl).get(
      ApiEndpoints.reportLanguage,
    );
    final data = response.data as Map<String, dynamic>;
    return _requireReportLanguage(data);
  }

  Future<String> setReportLanguage(String language, {String? baseUrl}) async {
    final response = await _clientForBaseUrl(baseUrl).put(
      ApiEndpoints.reportLanguage,
      data: {'report_language': language},
    );
    final data = response.data as Map<String, dynamic>;
    return _requireReportLanguage(data);
  }

  Future<int> getMaxItems() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMaxItems) ?? 50;
  }

  Future<void> setMaxItems(int maxItems) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMaxItems, maxItems);
  }

  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeMode) ?? 'light';
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode);
  }

  Future<bool> getInAppNotify() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyInAppNotify) ?? true;
  }

  Future<void> setInAppNotify(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyInAppNotify, value);
  }

  ApiClient _clientForBaseUrl(String? baseUrl) {
    final trimmedBaseUrl = baseUrl?.trim();
    if (trimmedBaseUrl != null && trimmedBaseUrl.isNotEmpty) {
      final scopedClient = _readApiClient?.call(trimmedBaseUrl);
      if (scopedClient != null) {
        return scopedClient;
      }
      return ApiClient(baseUrl: trimmedBaseUrl, enableLogging: false);
    }

    final sharedClient = _readApiClient?.call(null);
    if (sharedClient != null) {
      return sharedClient;
    }
    if (_apiClient != null) {
      return _apiClient;
    }
    return ApiClient(enableLogging: false);
  }

  String _requireReportLanguage(Map<String, dynamic> data) {
    final value = data['report_language'];
    if (value is String) {
      return value;
    }
    throw const FormatException(
      'Missing or invalid "report_language" in settings response.',
    );
  }
}
