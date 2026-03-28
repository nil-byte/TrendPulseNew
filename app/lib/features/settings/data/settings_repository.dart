import 'package:shared_preferences/shared_preferences.dart';

import 'package:trendpulse/core/network/api_endpoints.dart';

class SettingsRepository {
  static const _keyBaseUrl = 'settings_base_url';
  static const _keyLanguage = 'settings_language';
  static const _keyMaxItems = 'settings_max_items';
  static const _keyThemeMode = 'settings_theme_mode';
  static const _keyInAppNotify = 'in_app_notify';
  static const _keySubscriptionNotify = 'subscription_notify';

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBaseUrl) ?? ApiEndpoints.defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, url);
  }

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage) ?? 'en';
  }

  Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, language);
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
    return prefs.getString(_keyThemeMode) ?? 'system';
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

  Future<bool> getSubscriptionNotify() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySubscriptionNotify) ?? true;
  }

  Future<void> setSubscriptionNotify(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySubscriptionNotify, value);
  }
}
