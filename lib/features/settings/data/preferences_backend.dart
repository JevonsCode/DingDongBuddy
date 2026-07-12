/// Minimal persistent key-value boundary used by settings domain code.
abstract interface class PreferencesBackend {
  Future<Object?> read(String key);

  Future<void> write(String key, Object value);

  Future<void> remove(String key);
}

/// Deterministic backend for tests and ephemeral application instances.
final class MemoryPreferencesBackend implements PreferencesBackend {
  MemoryPreferencesBackend([Map<String, Object>? initialValues])
    : values = <String, Object>{...?initialValues};

  final Map<String, Object> values;

  @override
  Future<Object?> read(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> write(String key, Object value) async {
    values[key] = value;
  }
}
