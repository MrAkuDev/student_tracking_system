import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// URL del backend, persistida en `SharedPreferences`.
class ServerConfigProvider extends ChangeNotifier {
  String _baseUrl = AppConfig.defaultServerUrl;

  /// Siempre normalizada (con esquema, sin `/` final).
  String get baseUrl => _baseUrl;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConfig.prefServerUrl);
    if (saved != null && saved.trim().isNotEmpty) {
      _baseUrl = AppConfig.normalizeUrl(saved);
    }
  }

  Future<void> setBaseUrl(String raw) async {
    final normalized = AppConfig.normalizeUrl(raw);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.prefServerUrl, normalized);
    if (normalized != _baseUrl) {
      _baseUrl = normalized;
      notifyListeners();
    }
  }

  Future<void> resetToDefault() => setBaseUrl(AppConfig.defaultServerUrl);
}
