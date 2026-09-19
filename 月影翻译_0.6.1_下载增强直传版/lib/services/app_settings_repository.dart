import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';

class SecretKeys {
  static const deepl = 'secret.deepl.api_key';
  static const azure = 'secret.azure.api_key';
  static const google = 'secret.google.api_key';
  static const openAiCompatible = 'secret.openai_compatible.api_key';
}

class AppSettingsRepository {
  AppSettingsRepository({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _settingsKey = 'app.settings.v1';
  final FlutterSecureStorage _secureStorage;

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, settings.encode());
  }

  Future<String> readSecret(String key) async => (await _secureStorage.read(key: key))?.trim() ?? '';

  Future<void> writeSecret(String key, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _secureStorage.delete(key: key);
    } else {
      await _secureStorage.write(key: key, value: trimmed);
    }
  }

  Future<bool> hasSecret(String key) async => (await readSecret(key)).isNotEmpty;
}
