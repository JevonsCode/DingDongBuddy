import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists settings in NSUserDefaults on macOS and roaming AppData on Windows.
final class SharedPreferencesBackend implements PreferencesBackend {
  SharedPreferencesBackend([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<Object?> read(String key) async {
    final Map<String, Object?> values = await _preferences.getAll(
      allowList: <String>{key},
    );
    return values[key];
  }

  @override
  Future<void> remove(String key) => _preferences.remove(key);

  @override
  Future<void> write(String key, Object value) {
    return switch (value) {
      final bool typed => _preferences.setBool(key, typed),
      final int typed => _preferences.setInt(key, typed),
      final double typed => _preferences.setDouble(key, typed),
      final String typed => _preferences.setString(key, typed),
      final List<String> typed => _preferences.setStringList(key, typed),
      _ => throw ArgumentError.value(value, key, 'Unsupported preference type'),
    };
  }
}
