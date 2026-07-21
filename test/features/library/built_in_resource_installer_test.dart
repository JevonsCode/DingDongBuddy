import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/built_in_resource_installer.dart';
import 'package:dingdong/features/library/domain/built_in_resources.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'first run installs the reply marker and DingDong configure skill once',
    () async {
      final InMemoryResourceStore store = InMemoryResourceStore();
      final MemoryPreferencesBackend preferences = MemoryPreferencesBackend();
      final BuiltInResourceInstaller installer = BuiltInResourceInstaller(
        store,
        preferences,
        now: () => DateTime.utc(2026, 7, 15),
        skillDocumentLoader: _loadConfigureSkill,
      );

      await installer.install();
      await installer.install();

      final List<Resource> resources = await store.load();
      expect(resources, hasLength(2));
      final Resource prompt = resources.singleWhere(
        (Resource item) => item.id == builtInReplyMarkerPromptId,
      );
      expect(prompt.type, ResourceType.prompt);
      expect(prompt.content, '每次完整回复的最后加一个「🌟」');
      expect(prompt.pinned, isTrue);
      expect(prompt.enabled, isTrue);
      expect(prompt.activation, ResourceActivation.always);

      final Resource skill = resources.singleWhere(
        (Resource item) => item.id == builtInDingDongConfigureSkillId,
      );
      expect(skill.type, ResourceType.skill);
      expect(skill.title, 'DingDong Configure');
      expect(skill.content, await _loadConfigureSkill());
      expect(
        skill.updateUrl,
        'https://github.com/JevonsCode/DingDongBuddy/tree/main/skills/dingdong-configure',
      );
      expect(skill.enabled, isTrue);
      expect(skill.activation, ResourceActivation.manual);
      expect(
        preferences.values[BuiltInResourceInstaller.preferenceKey],
        BuiltInResourceInstaller.currentVersion,
      );
    },
  );

  test(
    'a user-deleted built-in prompt is not recreated on every launch',
    () async {
      final InMemoryResourceStore store = InMemoryResourceStore();
      final MemoryPreferencesBackend preferences = MemoryPreferencesBackend();
      final BuiltInResourceInstaller installer = BuiltInResourceInstaller(
        store,
        preferences,
        now: () => DateTime.utc(2026, 7, 15),
        skillDocumentLoader: _loadConfigureSkill,
      );

      await installer.install();
      await store.save(const <Resource>[]);
      await installer.install();

      expect(await store.load(), isEmpty);
    },
  );

  test(
    'version two adds only the new skill after a user deleted v1 prompt',
    () async {
      final InMemoryResourceStore store = InMemoryResourceStore();
      final MemoryPreferencesBackend preferences = MemoryPreferencesBackend()
        ..values[BuiltInResourceInstaller.preferenceKey] = 1;
      final BuiltInResourceInstaller installer = BuiltInResourceInstaller(
        store,
        preferences,
        now: () => DateTime.utc(2026, 7, 19),
        skillDocumentLoader: _loadConfigureSkill,
      );

      await installer.install();

      final List<Resource> resources = await store.load();
      expect(resources, hasLength(1));
      expect(resources.single.id, builtInDingDongConfigureSkillId);
    },
  );

  test(
    'version three refreshes the existing built-in Skill document',
    () async {
      final DateTime originalTime = DateTime.utc(2026, 7, 1);
      final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
        builtInDingDongConfigureSkill(
          'old bundled instructions',
          originalTime,
        ).copyWith(enabled: false),
      ]);
      final MemoryPreferencesBackend preferences = MemoryPreferencesBackend()
        ..values[BuiltInResourceInstaller.preferenceKey] = 2;
      final BuiltInResourceInstaller installer = BuiltInResourceInstaller(
        store,
        preferences,
        now: () => DateTime.utc(2026, 7, 21),
        skillDocumentLoader: _loadConfigureSkill,
      );

      expect(await installer.install(), isTrue);

      final Resource skill = (await store.load()).single;
      expect(skill.content, await _loadConfigureSkill());
      expect(skill.enabled, isFalse);
      expect(skill.updatedAt, DateTime.utc(2026, 7, 21));
      expect(
        preferences.values[BuiltInResourceInstaller.preferenceKey],
        BuiltInResourceInstaller.currentVersion,
      );
    },
  );

  test('version three does not recreate a deleted built-in Skill', () async {
    final InMemoryResourceStore store = InMemoryResourceStore();
    final MemoryPreferencesBackend preferences = MemoryPreferencesBackend()
      ..values[BuiltInResourceInstaller.preferenceKey] = 2;
    final BuiltInResourceInstaller installer = BuiltInResourceInstaller(
      store,
      preferences,
      skillDocumentLoader: _loadConfigureSkill,
    );

    expect(await installer.install(), isFalse);
    expect(await store.load(), isEmpty);
  });
}

Future<String> _loadConfigureSkill() =>
    File('skills/dingdong-configure/SKILL.md').readAsString();
