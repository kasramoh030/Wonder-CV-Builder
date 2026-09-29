import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_settings.dart';

/// Persistence for [AppSettings].
///
/// Settings are small, needed before the first frame, and benefit from being
/// synchronous once loaded — which is exactly what `SharedPreferences` is
/// good at. The whole object is stored as one JSON string so that adding a
/// field never requires a migration.
class SettingsStore {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'cvpro.settings.v1';

  AppSettings read() {
    final String? raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return AppSettings.defaults;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return AppSettings.defaults;
      return AppSettings.fromJson(decoded);
    } on FormatException {
      // A corrupt settings blob must never brick the app: fall back to
      // defaults and let the next write heal the record.
      return AppSettings.defaults;
    }
  }

  Future<void> write(AppSettings settings) =>
      _prefs.setString(_key, jsonEncode(settings.toJson()));

  Future<void> clear() => _prefs.remove(_key);
}
