import 'dart:convert';

import 'package:dingdong/features/ai_companion/domain/ai_companion_models.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:flutter/services.dart';

abstract interface class AiCompanionSecretStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

/// Provider tokens use the same local preferences as the model configuration.
/// They remain separate from settings JSON so metadata requests never include them.
final class PreferencesAiCompanionSecretStore
    implements AiCompanionSecretStore {
  const PreferencesAiCompanionSecretStore(this.backend, {required this.key});
  final PreferencesBackend backend;
  final String key;
  @override
  Future<String?> read() async => await backend.read(key) as String?;
  @override
  Future<void> write(String value) => backend.write(key, value);
  @override
  Future<void> delete() => backend.remove(key);
}

abstract interface class AiCompanionStore {
  Future<AiCompanionSettings> loadSettings();
  Future<void> saveSettings(AiCompanionSettings value);
  Future<String?> readApiKey();
  Future<void> writeApiKey(String? value);
}

/// Separate preference keys avoid overwriting other open settings windows.
final class AiCompanionPreferencesStore implements AiCompanionStore {
  AiCompanionPreferencesStore(
    this._backend, {
    AiCompanionSecretStore? secretStore,
    bool development = false,
  }) : _secretStore =
           secretStore ??
           PreferencesAiCompanionSecretStore(
             _backend,
             key: development
                 ? 'dingdong.dev.aiCompanion.providerApiKey.v1'
                 : 'dingdong.aiCompanion.providerApiKey.v1',
           );

  final PreferencesBackend _backend;
  final AiCompanionSecretStore _secretStore;
  static const String settingsKey = 'dingdong.aiCompanion.settings.v1';

  @override
  Future<AiCompanionSettings> loadSettings() async =>
      AiCompanionSettings.fromJson(_decode(await _backend.read(settingsKey)));
  @override
  Future<void> saveSettings(AiCompanionSettings value) =>
      _backend.write(settingsKey, jsonEncode(value.toJson()));
  @override
  Future<String?> readApiKey() => _credentialOperation(_secretStore.read);
  @override
  Future<void> writeApiKey(String? value) => _credentialOperation(
    () => value == null || value.isEmpty
        ? _secretStore.delete()
        : _secretStore.write(value),
  );

  Future<T> _credentialOperation<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException {
      // Never surface platform messages, which can include credential data.
      throw const AiCompanionException(AiCompanionError.credentialUnavailable);
    } on MissingPluginException {
      throw const AiCompanionException(AiCompanionError.credentialUnavailable);
    }
  }

  static Map<String, Object?> _decode(Object? value) {
    if (value is! String || value.length > 65536) return <String, Object?>{};
    try {
      final Object? parsed = jsonDecode(value);
      return parsed is Map<String, Object?> ? parsed : <String, Object?>{};
    } on FormatException {
      return <String, Object?>{};
    }
  }
}
