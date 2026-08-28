import 'dart:convert';

import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores [T] as a JSON-encoded string under [key]. Note this is
/// unencrypted storage — fine for a cached DTO like a user or a list of
/// apiaries, never for tokens (see `TokenStorage`/`SecureStorage` instead).
final class SharedPreferencesLocalDataSource<T> implements LocalDataSource<T> {
  const SharedPreferencesLocalDataSource({
    required this._preferences,
    required this._key,
    required this._toJson,
    required this._fromJson,
  });

  final SharedPreferences _preferences;
  final String _key;
  final Object? Function(T data) _toJson;
  final T Function(Object? json) _fromJson;

  @override
  Future<T?> read() async {
    final raw = _preferences.getString(_key);
    if (raw == null) {
      return null;
    }
    try {
      return _fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(T data) => _preferences.setString(_key, jsonEncode(_toJson(data)));

  @override
  Future<void> clear() async {
    await _preferences.remove(_key);
  }
}
