import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Settings live in SharedPreferences (the async API, so the background
/// isolate always sees fresh values); the GitHub token lives in the Android
/// Keystore-backed secure storage.
class SettingsStore {
  final _prefs = SharedPreferencesAsync();
  static const _secure = FlutterSecureStorage();

  static const _settingsKey = 'settings';
  static const _snoozeKey = 'snoozeUntil';
  static const _indexKey = 'availableDates';
  static const _tokenKey = 'githubToken';

  Future<AppSettings> load() async {
    final raw = await _prefs.getString(_settingsKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings s) => _prefs.setString(_settingsKey, jsonEncode(s.toJson()));

  Future<DateTime?> snoozedUntil() async {
    final ms = await _prefs.getInt(_snoozeKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setSnoozedUntil(DateTime? t) async {
    if (t == null) {
      await _prefs.remove(_snoozeKey);
    } else {
      await _prefs.setInt(_snoozeKey, t.millisecondsSinceEpoch);
    }
  }

  Future<List<String>> availableDates() async =>
      await _prefs.getStringList(_indexKey) ?? const [];

  Future<void> setAvailableDates(List<String> dates) => _prefs.setStringList(_indexKey, dates);

  Future<String?> token() async {
    try {
      final t = await _secure.read(key: _tokenKey);
      return (t == null || t.trim().isEmpty) ? null : t.trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> setToken(String? token) async {
    if (token == null || token.trim().isEmpty) {
      await _secure.delete(key: _tokenKey);
    } else {
      await _secure.write(key: _tokenKey, value: token.trim());
    }
  }
}
