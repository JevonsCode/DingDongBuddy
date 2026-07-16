import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/built_in_resources.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';

/// Installs each bundled resource once while respecting later user deletion.
final class BuiltInResourceInstaller {
  BuiltInResourceInstaller(
    this._store,
    this._preferences, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const String preferenceKey = 'dingdong.library.builtInResourceVersion';
  static const int currentVersion = 1;

  final ResourceStore _store;
  final PreferencesBackend _preferences;
  final DateTime Function() _now;

  Future<bool> install() async {
    final Object? installedVersion = await _preferences.read(preferenceKey);
    if (installedVersion is int && installedVersion >= currentVersion) {
      return false;
    }

    final List<Resource> resources = await _store.load();
    final bool alreadyPresent = resources.any(
      (Resource resource) => resource.id == builtInReplyMarkerPromptId,
    );
    if (!alreadyPresent) {
      await _store.save(<Resource>[
        ...resources,
        builtInReplyMarkerPrompt(_now()),
      ]);
    }
    await _preferences.write(preferenceKey, currentVersion);
    return !alreadyPresent;
  }
}
