import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  SettingsStore._(this._prefs);

  static const _kBaseUrlKey = 'baseUrl';

  final SharedPreferences _prefs;

  String get baseUrl => _prefs.getString(_kBaseUrlKey) ?? _defaultBaseUrl();

  static String _defaultBaseUrl() {
    // Web typically runs on the same machine as the backend during local dev.
    if (kIsWeb) return 'http://localhost:8000';
    // Android emulator default.
    return 'http://10.0.2.2:8000';
  }

  Future<void> setBaseUrl(String value) async {
    await _prefs.setString(_kBaseUrlKey, value);
  }

  static Future<SettingsStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsStore._(prefs);
  }
}

