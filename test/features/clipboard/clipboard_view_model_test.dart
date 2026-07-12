import 'package:dingdong/core/data/data_revision_bus.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/quick_paste_gateway.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pinning the selected row persists and keeps it selected', () {
    final DateTime now = DateTime.utc(2026, 7, 12);
    final InMemoryClipboardStore store = InMemoryClipboardStore(
      <ClipboardRecord>[
        ClipboardRecord(
          id: 'clip',
          group: 'Clipboard',
          title: 'Clipboard item',
          content: 'Value',
          tags: const <String>['clipboard', 'text'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    final ClipboardViewModel model = ClipboardViewModel(store)..load();
    model.select(model.visibleRecords.single);

    model.togglePinned();

    expect(model.selectedRecord?.pinned, isTrue);
    expect(store.list(limit: 10).single.pinned, isTrue);
    expect(store.list(limit: 10).single.activation, 'always');
  });

  test(
    'restoring the selected text writes through the platform seam',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 12);
      final ClipboardRecord record = ClipboardRecord(
        id: 'clip',
        group: 'Clipboard',
        title: 'Clipboard item',
        content: 'Restored value',
        tags: const <String>['clipboard', 'text'],
        pinned: false,
        enabled: true,
        activation: 'taskMatch',
        createdAt: now,
        updatedAt: now,
      );
      final _RecordingClipboardGateway gateway = _RecordingClipboardGateway();
      final ClipboardViewModel model = ClipboardViewModel(
        InMemoryClipboardStore(<ClipboardRecord>[record]),
        gateway: gateway,
      )..load();
      model.select(record);

      await model.restoreSelected();

      expect(gateway.writtenText, 'Restored value');
    },
  );

  test(
    'restoring after the global shortcut pastes into the previous app',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 12);
      final _RecordingClipboardGateway gateway = _RecordingClipboardGateway();
      final _FakeQuickPasteGateway quickPaste = _FakeQuickPasteGateway();
      final ClipboardRecord record = _record(now);
      final ClipboardViewModel model = ClipboardViewModel(
        InMemoryClipboardStore(<ClipboardRecord>[record]),
        gateway: gateway,
        quickPasteGateway: quickPaste,
      )..load();
      model.select(record);

      await model.restoreSelected();

      expect(gateway.writtenText, 'flutter test');
      expect(quickPaste.pasteCount, 1);
    },
  );

  test(
    'restoring a file record writes each stored path as a file URL',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 12);
      final ClipboardRecord record = ClipboardRecord(
        id: 'files',
        group: 'Files',
        title: 'Files: 2 items',
        content: '/tmp/first.txt\n/tmp/second.png',
        tags: const <String>['clipboard', 'file', 'file-url'],
        pinned: false,
        enabled: true,
        activation: 'taskMatch',
        createdAt: now,
        updatedAt: now,
      );
      final _RecordingClipboardGateway gateway = _RecordingClipboardGateway();
      final ClipboardViewModel model = ClipboardViewModel(
        InMemoryClipboardStore(<ClipboardRecord>[record]),
        gateway: gateway,
      )..load();
      model.select(record);

      await model.restoreSelected();

      expect(gateway.writtenFiles, <String>[
        '/tmp/first.txt',
        '/tmp/second.png',
      ]);
      expect(gateway.writtenText, isNull);
    },
  );

  test('organizing and deleting clipboard history persists both changes', () {
    final DateTime now = DateTime.utc(2026, 7, 12);
    final InMemoryClipboardStore store = InMemoryClipboardStore(
      <ClipboardRecord>[_record(now)],
    );
    final ClipboardViewModel model = ClipboardViewModel(
      store,
      now: () => now.add(const Duration(minutes: 1)),
    )..load();
    model.select(model.visibleRecords.single);

    model.organizeSelected(
      title: 'Build command',
      content: 'flutter build windows',
      group: 'Release',
      tags: const <String>['alias:build'],
    );

    expect(model.selectedRecord?.group, 'Release');
    expect(model.selectedRecord?.tags, contains('alias:build'));
    model.deleteSelected();
    expect(store.list(limit: 10), isEmpty);
  });

  test(
    'promoting clipboard content creates a selected library resource',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 12);
      final InMemoryResourceStore resources = InMemoryResourceStore();
      final ClipboardViewModel model = ClipboardViewModel(
        InMemoryClipboardStore(<ClipboardRecord>[_record(now)]),
        resourceStore: resources,
        idGenerator: () => 'promoted-1',
        now: () => now,
      )..load();
      model.select(model.visibleRecords.single);

      final promoted = await model.promoteSelected(ResourceType.prompt);

      expect(promoted?.id, 'promoted-1');
      expect(promoted?.type, ResourceType.prompt);
      expect((await resources.load()).single.content, 'flutter test');
    },
  );

  test('number shortcut restores the matching visible clipboard row', () async {
    final DateTime now = DateTime.utc(2026, 7, 12);
    final _RecordingClipboardGateway gateway = _RecordingClipboardGateway();
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[
        _record(now),
        ClipboardRecord(
          id: 'second',
          group: 'Clipboard',
          title: 'Second item',
          content: 'second value',
          tags: const <String>['clipboard', 'text'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: now.subtract(const Duration(seconds: 1)),
          updatedAt: now.subtract(const Duration(seconds: 1)),
        ),
      ]),
      gateway: gateway,
    )..load();

    await model.restoreVisibleAt(1);

    expect(model.selectedRecord?.id, 'second');
    expect(gateway.writtenText, 'second value');
  });

  test('available categories contain only kinds present in history', () {
    final DateTime now = DateTime.utc(2026, 7, 12);
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[
        _record(now),
        ClipboardRecord(
          id: 'link',
          group: '',
          title: 'https://example.com',
          content: 'https://example.com',
          tags: const <String>['clipboard', 'url'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    )..load();

    expect(model.availableCategories, <ClipboardCategory>[
      ClipboardCategory.text,
      ClipboardCategory.link,
    ]);
  });

  test('category and user group orders move independently', () {
    final DateTime now = DateTime.utc(2026, 7, 12);
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[
        _record(now),
        ClipboardRecord(
          id: 'link',
          group: '项目乙',
          title: 'https://example.com',
          content: 'https://example.com',
          tags: const <String>['clipboard', 'url'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: now,
          updatedAt: now,
        ),
        ClipboardRecord(
          id: 'group-a',
          group: '项目甲',
          title: 'Note',
          content: 'Note',
          tags: const <String>['clipboard', 'text'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    )..load();

    model.moveCategory(ClipboardCategory.link, before: ClipboardCategory.text);
    model.moveGroup('项目乙', before: '项目甲');

    expect(model.availableCategories.first, ClipboardCategory.link);
    expect(model.groups, <String>['项目乙', '项目甲']);
  });

  test('promoting content publishes a library revision', () async {
    final DataRevisionBus revisions = DataRevisionBus();
    final List<DataCollection> changes = <DataCollection>[];
    final subscription = revisions.changes.listen(changes.add);
    final DateTime now = DateTime.utc(2026, 7, 12);
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[_record(now)]),
      resourceStore: InMemoryResourceStore(),
      revisions: revisions,
    )..load();
    model.select(model.visibleRecords.single);

    await model.promoteSelected(ResourceType.prompt);

    expect(changes, contains(DataCollection.library));
    await subscription.cancel();
    await revisions.dispose();
  });

  test('bulk archive updates every selected clipboard record', () {
    final DateTime now = DateTime.utc(2026, 7, 12);
    final InMemoryClipboardStore store = InMemoryClipboardStore(
      <ClipboardRecord>[
        _record(now),
        ClipboardRecord(
          id: 'second',
          group: '',
          title: 'Second',
          content: 'Second',
          tags: const <String>['clipboard', 'text'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    final ClipboardViewModel model = ClipboardViewModel(store)..load();

    model.archiveMany(<String>{'clip', 'second'}, group: '项目归档');

    expect(
      store.list(limit: 10).map((ClipboardRecord item) => item.group).toSet(),
      <String>{'项目归档'},
    );
    expect(
      store
          .list(limit: 10)
          .every((ClipboardRecord item) => item.tags.contains('archived')),
      isTrue,
    );
  });
}

ClipboardRecord _record(DateTime now) {
  return ClipboardRecord(
    id: 'clip',
    group: 'Clipboard',
    title: 'Run tests',
    content: 'flutter test',
    tags: const <String>['clipboard', 'command'],
    pinned: false,
    enabled: true,
    activation: 'taskMatch',
    createdAt: now,
    updatedAt: now,
  );
}

final class _RecordingClipboardGateway implements ClipboardGateway {
  String? writtenText;
  List<String>? writtenFiles;

  @override
  Future<ClipboardSnapshot> read() async => const ClipboardSnapshot();

  @override
  Future<void> writeText(String text) async {
    writtenText = text;
  }

  @override
  Future<void> writeFiles(List<String> paths) async {
    writtenFiles = paths;
  }
}

final class _FakeQuickPasteGateway implements QuickPasteGateway {
  int pasteCount = 0;

  @override
  Future<bool> pasteIntoPreviousApplication() async {
    pasteCount += 1;
    return true;
  }
}
