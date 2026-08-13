import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/built_in_resources.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';

/// Installs bundled resources and migrates existing managed content while
/// respecting later user deletion.
final class BuiltInResourceInstaller {
  BuiltInResourceInstaller(
    this._store,
    this._preferences, {
    DateTime Function()? now,
    Future<String> Function()? skillDocumentLoader,
  }) : _now = now ?? DateTime.now,
       // Named private initializing formals are not callable cross-library.
       // ignore: prefer_initializing_formals
       _skillDocumentLoader = skillDocumentLoader;

  static const String preferenceKey = 'dingdong.library.builtInResourceVersion';
  static const int currentVersion = 12;

  final ResourceStore _store;
  final PreferencesBackend _preferences;
  final DateTime Function() _now;
  final Future<String> Function()? _skillDocumentLoader;

  Future<bool> install() async {
    final Object? storedVersion = await _preferences.read(preferenceKey);
    final int installedVersion = storedVersion is int ? storedVersion : 0;
    if (installedVersion >= currentVersion) {
      return false;
    }

    final List<Resource> resources = await _store.load();
    final List<Resource> next = List<Resource>.of(resources);
    bool changed = false;
    String? bundledSkillDocument;
    Future<String> loadBundledSkill() async {
      final Future<String> Function()? loadSkill = _skillDocumentLoader;
      if (loadSkill == null) {
        throw StateError(
          'The bundled DingDong configure Skill is unavailable.',
        );
      }
      return bundledSkillDocument ??= await loadSkill();
    }

    if (installedVersion < 1 &&
        !next.any(
          (Resource resource) => resource.id == builtInReplyMarkerPromptId,
        )) {
      next.add(builtInReplyMarkerPrompt(_now()));
      changed = true;
    }
    if (installedVersion < 2 &&
        !next.any(
          (Resource resource) => resource.id == builtInDingDongConfigureSkillId,
        )) {
      next.add(builtInDingDongConfigureSkill(await loadBundledSkill(), _now()));
      changed = true;
    }
    if (installedVersion < 12) {
      final int index = next.indexWhere(
        (Resource resource) => resource.id == builtInDingDongConfigureSkillId,
      );
      if (index >= 0) {
        final String document = await loadBundledSkill();
        final Resource current = next[index];
        if (current.content != document) {
          next[index] = current.copyWith(
            content: document,
            updatedAt: _now().toUtc(),
          );
          changed = true;
        }
      }
    }
    if (installedVersion < 10) {
      final int skillIndex = next.indexWhere(
        (Resource resource) => resource.id == builtInDingDongConfigureSkillId,
      );
      if (skillIndex >= 0 && !next[skillIndex].hideInAgentConversation) {
        next[skillIndex] = next[skillIndex].copyWith(
          hideInAgentConversation: true,
          updatedAt: _now().toUtc(),
        );
        changed = true;
      }

      final int promptIndex = next.indexWhere(
        (Resource resource) => resource.id == builtInReplyMarkerPromptId,
      );
      if (promptIndex >= 0) {
        final Resource current = next[promptIndex];
        final Resource bundled = builtInReplyMarkerPrompt(_now());
        final bool isPreviousDefault =
            current.title == '回复末尾添加 👻' ||
            current.content == '每次完整回复的最后加一个「👻」';
        final bool isCurrentBundledDefault =
            current.title == bundled.title &&
            current.content == bundled.content &&
            current.agentSessionName == null;
        if (isPreviousDefault || isCurrentBundledDefault) {
          next[promptIndex] = current.copyWith(
            title: bundled.title,
            content: bundled.content,
            agentSessionName: bundled.agentSessionName,
            updatedAt: _now().toUtc(),
          );
          changed = true;
        }
      }
    }
    if (changed) {
      await _store.save(next);
    }
    await _preferences.write(preferenceKey, currentVersion);
    return changed;
  }
}
