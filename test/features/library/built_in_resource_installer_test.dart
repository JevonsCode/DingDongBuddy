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
      expect(prompt.agentSessionName, '🌟');
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
      expect(skill.hideInAgentConversation, isTrue);
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

  test('bundled Skill documents per-Agent Skill delivery', () async {
    final String document = await _loadConfigureSkill();

    expect(document, contains('dingdong_install_skill'));
    expect(document, contains('dingdong_set_skill_delivery'));
    expect(document, contains('dingdong_get_skill_deployments'));
    expect(document, contains('dingdong_reconcile_skill'));
    expect(document, contains('dingdong_upsert_trigger_group'));
    expect(document, contains('dingdong_bind_resource_scope'));
    expect(document, isNot(contains('strictProjectSkill')));
    expect(document, contains('`dynamic`, `nativeUser`, or `nativeProject`'));
    expect(document, contains('`mode: "nativeProject"`'));
    expect(document, contains('`projectPaths`'));
    expect(document, contains('exact absolute project path'));
    expect(document, contains('dynamic Skill catalog'));
    expect(document, contains('discover native Skill changes automatically'));
    expect(
      document,
      contains('restart the Agent only if the Skill is missing'),
    );
    expect(document, isNot(contains('reload required')));
    expect(
      document,
      contains(
        'Every active, scope-matched MCP and Knowledge candidate is returned',
      ),
    );
    expect(document, isNot(contains('Bridge `limit`')));
    expect(document, contains('dingdong_read_skill_file'));
  });

  test('bundled Skill documents Agent launcher configuration', () async {
    final String document = await _loadConfigureSkill();

    expect(document, contains('agent-launchers.json'));
    expect(document, contains('claude-code'));
    expect(document, contains('"macosTerminal": "iterm"'));
    expect(document, contains('"itermOpenMode": "new-tab"'));
    expect(document, contains('atomically replace'));
    expect(
      document,
      contains('does not locate or focus an original terminal tab'),
    );
  });

  test('bundled Skill documents Agent Adapter configuration', () async {
    final String document = await _loadConfigureSkill();

    expect(document, contains('Agent Adapters'));
    expect(
      document,
      contains('~/Library/Application Support/DingDong/Agent Adapters'),
    );
    expect(document, contains('schemaVersion: 1'));
    expect(document, contains('mcpServers-json'));
    expect(document, contains('Agent Adapter History'));
    expect(document, contains('Do not edit the history directory directly'));
  });

  test('version five refreshes the existing built-in Skill document', () async {
    final DateTime originalTime = DateTime.utc(2026, 7, 1);
    final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
      builtInDingDongConfigureSkill(
        'old bundled instructions',
        originalTime,
      ).copyWith(enabled: false),
    ]);
    final MemoryPreferencesBackend preferences = MemoryPreferencesBackend()
      ..values[BuiltInResourceInstaller.preferenceKey] = 4;
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
  });

  test('version six refreshes the Agent Adapter instructions', () async {
    final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
      builtInDingDongConfigureSkill(
        'instructions without Agent Adapters',
        DateTime.utc(2026, 7, 1),
      ),
    ]);
    final MemoryPreferencesBackend preferences = MemoryPreferencesBackend()
      ..values[BuiltInResourceInstaller.preferenceKey] = 5;
    final BuiltInResourceInstaller installer = BuiltInResourceInstaller(
      store,
      preferences,
      now: () => DateTime.utc(2026, 7, 23),
      skillDocumentLoader: _loadConfigureSkill,
    );

    expect(await installer.install(), isTrue);
    expect((await store.load()).single.content, await _loadConfigureSkill());
    expect(
      preferences.values[BuiltInResourceInstaller.preferenceKey],
      BuiltInResourceInstaller.currentVersion,
    );
  });

  test('version nine removes the obsolete Bridge limit instructions', () async {
    final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
      builtInDingDongConfigureSkill(
        'instructions for native Skill mirrors',
        DateTime.utc(2026, 7, 1),
      ).copyWith(enabled: false),
    ]);
    final MemoryPreferencesBackend preferences = MemoryPreferencesBackend()
      ..values[BuiltInResourceInstaller.preferenceKey] = 8;
    final BuiltInResourceInstaller installer = BuiltInResourceInstaller(
      store,
      preferences,
      now: () => DateTime.utc(2026, 7, 28),
      skillDocumentLoader: _loadConfigureSkill,
    );

    expect(await installer.install(), isTrue);
    final Resource skill = (await store.load()).single;
    expect(skill.content, await _loadConfigureSkill());
    expect(skill.enabled, isFalse);
    expect(skill.updatedAt, DateTime.utc(2026, 7, 28));
    expect(
      preferences.values[BuiltInResourceInstaller.preferenceKey],
      BuiltInResourceInstaller.currentVersion,
    );
  });

  test(
    'version ten hides the configure Skill and upgrades the old marker',
    () async {
      final DateTime now = DateTime.utc(2026, 8, 1);
      final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
        builtInReplyMarkerPrompt(
          now,
        ).copyWith(title: '回复末尾添加 👻', content: '每次完整回复的最后加一个「👻」'),
        builtInDingDongConfigureSkill(
          'old',
          now,
        ).copyWith(hideInAgentConversation: false),
      ]);
      final MemoryPreferencesBackend preferences = MemoryPreferencesBackend()
        ..values[BuiltInResourceInstaller.preferenceKey] = 9;
      final BuiltInResourceInstaller installer = BuiltInResourceInstaller(
        store,
        preferences,
        now: () => DateTime.utc(2026, 8, 7),
        skillDocumentLoader: _loadConfigureSkill,
      );

      expect(await installer.install(), isTrue);
      final List<Resource> resources = await store.load();
      expect(
        resources
            .singleWhere(
              (Resource item) => item.id == builtInReplyMarkerPromptId,
            )
            .content,
        '每次完整回复的最后加一个「🌟」',
      );
      expect(
        resources
            .singleWhere(
              (Resource item) => item.id == builtInReplyMarkerPromptId,
            )
            .agentSessionName,
        '🌟',
      );
      expect(
        resources
            .singleWhere(
              (Resource item) => item.id == builtInDingDongConfigureSkillId,
            )
            .hideInAgentConversation,
        isTrue,
      );
    },
  );

  test('version eleven refreshes native Skill delivery instructions', () async {
    final DateTime originalTime = DateTime.utc(2026, 8, 1);
    final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
      builtInDingDongConfigureSkill(
        'dynamic-only instructions',
        originalTime,
      ).copyWith(enabled: false, hideInAgentConversation: true),
    ]);
    final MemoryPreferencesBackend preferences = MemoryPreferencesBackend()
      ..values[BuiltInResourceInstaller.preferenceKey] = 10;
    final BuiltInResourceInstaller installer = BuiltInResourceInstaller(
      store,
      preferences,
      now: () => DateTime.utc(2026, 8, 12),
      skillDocumentLoader: _loadConfigureSkill,
    );

    expect(await installer.install(), isTrue);

    final Resource skill = (await store.load()).single;
    expect(skill.content, await _loadConfigureSkill());
    expect(skill.enabled, isFalse);
    expect(skill.hideInAgentConversation, isTrue);
    expect(skill.updatedAt, DateTime.utc(2026, 8, 12));
    expect(
      preferences.values[BuiltInResourceInstaller.preferenceKey],
      BuiltInResourceInstaller.currentVersion,
    );
  });

  test('version twelve refreshes configurable footer instructions', () async {
    final DateTime originalTime = DateTime.utc(2026, 8, 12);
    final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
      builtInDingDongConfigureSkill(
        'fixed emoji footer instructions',
        originalTime,
      ).copyWith(enabled: true, hideInAgentConversation: true),
    ]);
    final MemoryPreferencesBackend preferences = MemoryPreferencesBackend()
      ..values[BuiltInResourceInstaller.preferenceKey] = 11;
    final BuiltInResourceInstaller installer = BuiltInResourceInstaller(
      store,
      preferences,
      now: () => DateTime.utc(2026, 8, 13),
      skillDocumentLoader: _loadConfigureSkill,
    );

    expect(await installer.install(), isTrue);

    final Resource skill = (await store.load()).single;
    expect(skill.content, await _loadConfigureSkill());
    expect(skill.enabled, isTrue);
    expect(skill.hideInAgentConversation, isTrue);
    expect(skill.updatedAt, DateTime.utc(2026, 8, 13));
    expect(
      preferences.values[BuiltInResourceInstaller.preferenceKey],
      BuiltInResourceInstaller.currentVersion,
    );
  });
}

Future<String> _loadConfigureSkill() =>
    File('skills/dingdong-configure/SKILL.md').readAsString();
