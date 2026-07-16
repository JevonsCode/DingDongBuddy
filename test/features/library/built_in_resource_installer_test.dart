import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/built_in_resource_installer.dart';
import 'package:dingdong/features/library/domain/built_in_resources.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first run installs the always-on reply marker prompt once', () async {
    final InMemoryResourceStore store = InMemoryResourceStore();
    final MemoryPreferencesBackend preferences = MemoryPreferencesBackend();
    final BuiltInResourceInstaller installer = BuiltInResourceInstaller(
      store,
      preferences,
      now: () => DateTime.utc(2026, 7, 15),
    );

    await installer.install();
    await installer.install();

    final List<Resource> resources = await store.load();
    expect(resources, hasLength(1));
    expect(resources.single.id, builtInReplyMarkerPromptId);
    expect(resources.single.type, ResourceType.prompt);
    expect(resources.single.content, '每次完整回复的最后加一个「🌟」');
    expect(resources.single.pinned, isTrue);
    expect(resources.single.enabled, isTrue);
    expect(resources.single.activation, ResourceActivation.always);
    expect(
      preferences.values[BuiltInResourceInstaller.preferenceKey],
      BuiltInResourceInstaller.currentVersion,
    );
  });

  test(
    'a user-deleted built-in prompt is not recreated on every launch',
    () async {
      final InMemoryResourceStore store = InMemoryResourceStore();
      final MemoryPreferencesBackend preferences = MemoryPreferencesBackend();
      final BuiltInResourceInstaller installer = BuiltInResourceInstaller(
        store,
        preferences,
        now: () => DateTime.utc(2026, 7, 15),
      );

      await installer.install();
      await store.save(const <Resource>[]);
      await installer.install();

      expect(await store.load(), isEmpty);
    },
  );
}
