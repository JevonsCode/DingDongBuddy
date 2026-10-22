import 'dart:convert';

import 'package:dingdong/features/ai_companion/domain/ai_companion_models.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_privacy.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AiCompanionSecretStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

final class SecureAiCompanionSecretStore implements AiCompanionSecretStore {
  const SecureAiCompanionSecretStore({
    this.key = 'dingdong.aiCompanion.providerApiKey.v1',
    FlutterSecureStorage storage = const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
    // ignore: prefer_initializing_formals
  }) : _storage = storage;
  final FlutterSecureStorage _storage;
  final String key;
  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
  @override
  Future<void> delete() => _storage.delete(key: key);
}

abstract interface class AiCompanionStore {
  Future<AiCompanionSettings> loadSettings();
  Future<void> saveSettings(AiCompanionSettings value);
  Future<AiCompanionReport?> loadReport();
  Future<void> saveReport(AiCompanionReport? value);
  Future<String?> readApiKey();
  Future<void> writeApiKey(String? value);
}

/// Separate preference keys avoid overwriting other open settings windows.
/// Reports contain suggestion codes and
/// local references, never raw clipboard or resource content.
final class AiCompanionPreferencesStore implements AiCompanionStore {
  AiCompanionPreferencesStore(
    this._backend, {
    AiCompanionSecretStore? secretStore,
    bool development = false,
  }) : _secretStore =
           secretStore ??
           SecureAiCompanionSecretStore(
             key: development
                 ? 'dingdong.dev.aiCompanion.providerApiKey.v1'
                 : 'dingdong.aiCompanion.providerApiKey.v1',
           );

  final PreferencesBackend _backend;
  final AiCompanionSecretStore _secretStore;
  static const String settingsKey = 'dingdong.aiCompanion.settings.v1';
  static const String reportKey = 'dingdong.aiCompanion.report.v1';

  @override
  Future<AiCompanionSettings> loadSettings() async =>
      AiCompanionSettings.fromJson(_decode(await _backend.read(settingsKey)));
  @override
  Future<void> saveSettings(AiCompanionSettings value) =>
      _backend.write(settingsKey, jsonEncode(value.toJson()));
  @override
  Future<AiCompanionReport?> loadReport() async {
    final AiCompanionReport? report = AiCompanionReport.fromJson(
      _decode(await _backend.read(reportKey)),
    );
    if (report?.cloudSummary case final String summary) {
      if (summary.length > 8000 ||
          !const AiCompanionPrivacy().isSafeText(summary)) {
        return null;
      }
    }
    return report;
  }

  @override
  Future<void> saveReport(AiCompanionReport? value) => value == null
      ? _backend.remove(reportKey)
      : _backend.write(reportKey, jsonEncode(value.toJson()));
  @override
  Future<String?> readApiKey() => _secretStore.read();
  @override
  Future<void> writeApiKey(String? value) => value == null || value.isEmpty
      ? _secretStore.delete()
      : _secretStore.write(value);

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
