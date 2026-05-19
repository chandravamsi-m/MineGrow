import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden at startup.');
});

final localStorageProvider = Provider<LocalStorage>((ref) {
  return LocalStorage(ref.watch(sharedPreferencesProvider));
});

class LocalStorage {
  const LocalStorage(this._preferences);

  final SharedPreferences _preferences;

  String? readString(String key) => _preferences.getString(key);

  Future<bool> writeString(String key, String value) {
    return _preferences.setString(key, value);
  }

  Future<bool> remove(String key) {
    return _preferences.remove(key);
  }
}
