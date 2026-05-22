import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// HIGH-3: Use flutter_secure_storage instead of SharedPreferences for tokens.
// On Android: uses Android Keystore (hardware-backed encryption).
// On iOS: uses iOS Keychain.
// This prevents token theft via backup extraction or rooted device file access.

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

final localStorageProvider = Provider<LocalStorage>((ref) {
  return LocalStorage(ref.watch(secureStorageProvider));
});

class LocalStorage {
  LocalStorage(this._secure);

  final FlutterSecureStorage _secure;

  // Cache for sync reads (populated on first async read)
  final Map<String, String?> _cache = {};

  // Async token reads — always use these for auth tokens
  Future<String?> readStringAsync(String key) async {
    final value = await _secure.read(key: key);
    _cache[key] = value;
    return value;
  }

  // Sync read from cache (call readStringAsync first to warm cache)
  String? readString(String key) => _cache[key];

  Future<void> writeString(String key, String value) async {
    await _secure.write(key: key, value: value);
    _cache[key] = value;
  }

  Future<void> remove(String key) async {
    await _secure.delete(key: key);
    _cache.remove(key);
  }

  Future<void> removeAll() async {
    await _secure.deleteAll();
    _cache.clear();
  }

  // Non-sensitive preferences (booleans like theme, onboarding flag)
  // These go in secure storage too for consistency
  Future<bool?> readBool(String key) async {
    final val = await _secure.read(key: key);
    if (val == null) return null;
    return val == 'true';
  }

  Future<void> writeBool(String key, bool value) async {
    await _secure.write(key: key, value: value.toString());
    _cache[key] = value.toString();
  }
}
