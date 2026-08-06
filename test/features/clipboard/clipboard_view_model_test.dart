import 'dart:io';
import 'dart:typed_data';

import 'package:dingdong/core/data/data_revision_bus.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/clipboard/data/clipboard_group_order_store.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/quick_paste_gateway.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loading clipboard history selects the first visible row', () {
    final DateTime now = DateTime.utc(2026, 7, 16);
    final ClipboardRecord first = _record(now);
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[
        first,
        ClipboardRecord(
          id: 'second',
          group: 'Clipboard',
          title: 'Second item',
          content: 'Second',
          tags: const <String>['clipboard', 'text'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: now.subtract(const Duration(seconds: 1)),
          updatedAt: now.subtract(const Duration(seconds: 1)),
        ),
      ]),
    )..load();

    expect(model.selectedRecord?.id, first.id);
  });

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
    'original and plain-text restore use distinct clipboard paths',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 12);
      final Uint8List htmlData = Uint8List.fromList('<b>Value</b>'.codeUnits);
      final ClipboardRecord record = ClipboardRecord(
        id: 'rich',
        group: 'Clipboard',
        title: 'Rich value',
        content: 'Value',
        htmlData: htmlData,
        tags: const <String>['clipboard', 'text'],
        pinned: false,
        enabled: true,
        activation: 'taskMatch',
        createdAt: now,
        updatedAt: now,
      );
      final _RecordingClipboardGateway gateway = _RecordingClipboardGateway();
      final _FakeQuickPasteGateway quickPaste = _FakeQuickPasteGateway();
      final ClipboardViewModel model = ClipboardViewModel(
        InMemoryClipboardStore(<ClipboardRecord>[record]),
        gateway: gateway,
        quickPasteGateway: quickPaste,
      )..load();
      model.select(record);

      await model.restoreSelected();

      expect(gateway.formattedPlainText, 'Value');
      expect(gateway.formattedHtmlData, htmlData);
      expect(gateway.writtenText, isNull);

      gateway.clearWrites();
      await model.restoreSelected(mode: ClipboardPasteMode.plainText);

      expect(gateway.writtenText, 'Value');
      expect(gateway.formattedPlainText, isNull);
      expect(quickPaste.pasteCount, 2);
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

  test(
    'restoring one image writes bitmap data with its source file URL',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 12);
      final ClipboardRecord record = ClipboardRecord(
        id: 'image',
        group: 'Images',
        title: 'clipboard-image.png',
        content: '/tmp/clipboard-image.png',
        tags: const <String>[
          'clipboard',
          'ext:png',
          'file',
          'file-url',
          'image',
        ],
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

      expect(await model.copySelected(), isTrue);

      expect(gateway.writtenImagePath, '/tmp/clipboard-image.png');
      expect(gateway.writtenFiles, isNull);
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
    'deleting history removes managed image data but preserves source files',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-managed-clipboard-delete-test-',
      );
      final Directory sourceDirectory = await Directory.systemTemp.createTemp(
        'dingdong-source-clipboard-delete-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      addTearDown(() => sourceDirectory.delete(recursive: true));
      final File managed = File('${directory.path}/clipboard-managed.png')
        ..writeAsBytesSync(<int>[1, 2, 3]);
      final File source = File('${sourceDirectory.path}/source.png')
        ..writeAsBytesSync(<int>[4, 5, 6]);
      final DateTime now = DateTime.utc(2026, 7, 12);
      final ClipboardRecord managedRecord = ClipboardRecord(
        id: 'managed',
        group: '',
        title: 'Managed image',
        content: managed.path,
        tags: const <String>['clipboard', 'file', 'file-url', 'image'],
        pinned: false,
        enabled: true,
        activation: 'taskMatch',
        createdAt: now,
        updatedAt: now,
      );
      final ClipboardRecord sourceRecord = ClipboardRecord(
        id: 'source',
        group: '',
        title: 'Source image',
        content: source.path,
        tags: const <String>['clipboard', 'file', 'file-url', 'image'],
        pinned: false,
        enabled: true,
        activation: 'taskMatch',
        createdAt: now,
        updatedAt: now,
      );
      final InMemoryClipboardStore store = InMemoryClipboardStore(
        <ClipboardRecord>[managedRecord, sourceRecord],
      );
      final ClipboardViewModel model = ClipboardViewModel(
        store,
        managedImageDirectory: directory,
      )..load();

      model.deleteMany(<String>{managedRecord.id, sourceRecord.id});

      expect(managed.existsSync(), isFalse);
      expect(source.existsSync(), isTrue);
      expect(store.list(limit: 10), isEmpty);
    },
  );

  test('editing content preserves existing multi-group membership', () {
    final DateTime now = DateTime.utc(2026, 7, 12);
    final ClipboardRecord record = _record(now).copyWith(
      groups: const <String>['Clipboard', 'Project alpha', 'Reference'],
    );
    final InMemoryClipboardStore store = InMemoryClipboardStore(
      <ClipboardRecord>[record],
    );
    final ClipboardViewModel model = ClipboardViewModel(store)..load();
    model.select(model.visibleRecords.single);

    model.organizeSelected(
      title: 'Updated command',
      content: record.content,
      group: record.group,
      tags: const <String>[],
    );

    expect(model.selectedRecord?.groupNames, const <String>[
      'Clipboard',
      'Project alpha',
      'Reference',
    ]);
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

  test('available categories come from the editable ordered rule set', () {
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

    expect(model.availableCategories.map((category) => category.id), <String>[
      'links',
      'text',
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

    model.reorderCategories(3, 0);
    model.moveGroup('项目乙', before: '项目甲');

    expect(model.availableCategories.first.id, 'text');
    expect(model.groups, <String>['项目乙', '项目甲']);
  });

  test('user group order survives rebuilding and reopening the view model', () {
    final DateTime now = DateTime.utc(2026, 7, 21);
    ClipboardRecord groupedRecord(String id, String group) => ClipboardRecord(
      id: id,
      group: group,
      title: group,
      content: group,
      tags: const <String>['clipboard', 'text'],
      pinned: false,
      enabled: true,
      activation: 'taskMatch',
      createdAt: now,
      updatedAt: now,
    );
    final InMemoryClipboardStore records =
        InMemoryClipboardStore(<ClipboardRecord>[
          groupedRecord('page-id', 'PageID'),
          groupedRecord('query', 'Query'),
          groupedRecord('idev', 'iDev ID'),
        ]);
    final InMemoryClipboardGroupOrderStore orderStore =
        InMemoryClipboardGroupOrderStore();
    final ClipboardViewModel first = ClipboardViewModel(
      records,
      groupOrderStore: orderStore,
    )..load();

    first.reorderGroups(2, 0);
    expect(first.groups, <String>['Query', 'iDev ID', 'PageID']);

    final ClipboardViewModel reopened = ClipboardViewModel(
      records,
      groupOrderStore: orderStore,
    )..load();

    expect(reopened.groups, <String>['Query', 'iDev ID', 'PageID']);
  });

  test('ordered groups remain visible when they have no records', () {
    final DateTime now = DateTime.utc(2026, 7, 21);
    final ClipboardRecord query = ClipboardRecord(
      id: 'query',
      group: 'Query',
      title: 'Query',
      content: 'Query',
      tags: const <String>['clipboard', 'text'],
      pinned: false,
      enabled: true,
      activation: 'taskMatch',
      createdAt: now,
      updatedAt: now,
    );
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[query]),
      groupOrderStore: InMemoryClipboardGroupOrderStore(const <String>[
        'PageID',
        'Query',
      ]),
    )..load();

    expect(model.groups, <String>['PageID', 'Query']);

    model.setGroup('PageID');
    expect(model.visibleRecords, isEmpty);
  });

  test('ordered group labels match records case insensitively', () {
    final DateTime now = DateTime.utc(2026, 7, 21);
    final ClipboardRecord record = ClipboardRecord(
      id: 'page-id',
      group: 'pageid',
      title: 'PageID note',
      content: 'PageID note',
      tags: const <String>['clipboard', 'text'],
      pinned: false,
      enabled: true,
      activation: 'taskMatch',
      createdAt: now,
      updatedAt: now,
    );
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[record]),
      groupOrderStore: InMemoryClipboardGroupOrderStore(const <String>[
        'PageID',
      ]),
    )..load();

    expect(model.groups, <String>['PageID']);
    model.setGroup('PageID');
    expect(model.visibleRecords.single.id, 'page-id');
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

  test('bulk group assignment preserves existing memberships', () {
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

    model.addManyToGroups(<String>{'clip', 'second'}, <String>{'项目归档'});

    expect(
      store
          .list(limit: 10)
          .every((ClipboardRecord item) => item.groupNames.contains('项目归档')),
      isTrue,
    );
    expect(
      store.list(limit: 10).firstWhere((item) => item.id == 'clip').groupNames,
      <String>['Clipboard', '项目归档'],
    );
    expect(
      store
          .list(limit: 10)
          .any((ClipboardRecord item) => item.tags.contains('archived')),
      isFalse,
    );
  });

  test('group filters match every membership on a clipboard record', () {
    final DateTime now = DateTime.utc(2026, 7, 12);
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[
        ClipboardRecord(
          id: 'multi-group',
          group: '项目甲',
          groups: const <String>['项目甲', '项目乙'],
          title: 'Shared note',
          content: 'Shared note',
          tags: const <String>['clipboard', 'text'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    )..load();

    expect(model.groups, <String>['项目乙', '项目甲']);
    model.setGroup('项目乙');
    expect(model.visibleRecords.single.id, 'multi-group');
  });

  test('clearing filters resets category and group selections together', () {
    final DateTime now = DateTime.utc(2026, 7, 30);
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[
        _record(now, source: 'Terminal · com.apple.Terminal'),
      ]),
    )..load();

    model.setCategory('text');
    model.setGroup('Project');
    model.toggleSource('bundle:com.apple.terminal');
    expect(model.hasActiveFilters, isTrue);

    model.clearFilters();

    expect(model.hasActiveFilters, isFalse);
    expect(model.selectedKind, isNull);
    expect(model.selectedCategoryId, isNull);
    expect(model.selectedGroup, isNull);
    expect(model.selectedSourceIds, isEmpty);
  });

  test(
    'source filters derive real application options and combine selections',
    () {
      final DateTime now = DateTime.utc(2026, 7, 31);
      final ClipboardViewModel model = ClipboardViewModel(
        InMemoryClipboardStore(<ClipboardRecord>[
          _record(now, source: 'Google Chrome · com.google.Chrome'),
          ClipboardRecord(
            id: 'chrome-second-window',
            group: 'Clipboard',
            title: 'Another Chrome window',
            content: 'Second Chrome value',
            tags: const <String>['clipboard', 'text'],
            source: 'Chrome · com.google.Chrome',
            pinned: false,
            enabled: true,
            activation: 'taskMatch',
            createdAt: now.subtract(const Duration(seconds: 1)),
            updatedAt: now.subtract(const Duration(seconds: 1)),
          ),
          ClipboardRecord(
            id: 'notes',
            group: 'Clipboard',
            title: 'Notes value',
            content: 'A note',
            tags: const <String>['clipboard', 'text'],
            source: 'Notes · com.apple.Notes',
            pinned: false,
            enabled: true,
            activation: 'taskMatch',
            createdAt: now.subtract(const Duration(seconds: 2)),
            updatedAt: now.subtract(const Duration(seconds: 2)),
          ),
          ClipboardRecord(
            id: 'generic',
            group: 'Clipboard',
            title: 'Generic value',
            content: 'Generic clipboard',
            tags: const <String>['clipboard', 'text'],
            source: 'Clipboard',
            pinned: false,
            enabled: true,
            activation: 'taskMatch',
            createdAt: now.subtract(const Duration(seconds: 3)),
            updatedAt: now.subtract(const Duration(seconds: 3)),
          ),
        ]),
      )..load();

      expect(
        model.sourceOptions.map((option) => (option.id, option.label)),
        <(String, String)>[
          ('bundle:com.google.chrome', 'Google Chrome'),
          ('bundle:com.apple.notes', 'Notes'),
        ],
      );

      model.toggleSource('bundle:com.google.chrome');
      expect(
        model.visibleRecords.map((ClipboardRecord item) => item.id).toSet(),
        <String>{'clip', 'chrome-second-window'},
      );

      model.toggleSource('bundle:com.apple.notes');
      expect(
        model.visibleRecords.map((ClipboardRecord item) => item.id).toSet(),
        <String>{'clip', 'chrome-second-window', 'notes'},
      );

      model.clearFilters();
      model.setQuery('com.apple.notes');
      expect(model.visibleRecords.single.id, 'notes');
    },
  );

  test(
    'Windows source metadata groups changing window titles by executable',
    () {
      final DateTime now = DateTime.utc(2026, 7, 31);
      final ClipboardViewModel model = ClipboardViewModel(
        InMemoryClipboardStore(<ClipboardRecord>[
          _record(now, source: 'First document · notepad.exe'),
          ClipboardRecord(
            id: 'second-document',
            group: 'Clipboard',
            title: 'Second document',
            content: 'Second document content',
            tags: const <String>['clipboard', 'text'],
            source: 'Second document · notepad.exe',
            pinned: false,
            enabled: true,
            activation: 'taskMatch',
            createdAt: now.subtract(const Duration(seconds: 1)),
            updatedAt: now.subtract(const Duration(seconds: 1)),
          ),
        ]),
      )..load();

      expect(model.sourceOptions, hasLength(1));
      expect(model.sourceOptions.single.id, 'exe:notepad.exe');
      expect(model.sourceOptions.single.label, 'notepad.exe');
    },
  );

  test('deleting a group preserves records and their other memberships', () {
    final DateTime now = DateTime.utc(2026, 7, 12);
    final InMemoryClipboardStore store = InMemoryClipboardStore(
      <ClipboardRecord>[
        ClipboardRecord(
          id: 'first',
          group: '项目甲',
          groups: const <String>['项目甲', '参考'],
          title: 'First',
          content: 'First',
          tags: const <String>['clipboard', 'text'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: now,
          updatedAt: now,
        ),
        ClipboardRecord(
          id: 'second',
          group: '项目甲',
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
    model.select(
      model.allRecords.firstWhere((ClipboardRecord item) => item.id == 'first'),
    );
    model.setGroup('项目甲');

    expect(model.groupItemCount('项目甲'), 2);
    model.deleteGroup('项目甲');

    expect(store.list(limit: 10), hasLength(2));
    expect(model.selectedGroup, isNull);
    expect(model.selectedRecord?.groupNames, <String>['参考']);
    expect(model.groups, <String>['参考']);
    expect(
      store
          .list(limit: 10)
          .firstWhere((ClipboardRecord item) => item.id == 'first')
          .groupNames,
      <String>['参考'],
    );
    expect(
      store
          .list(limit: 10)
          .firstWhere((ClipboardRecord item) => item.id == 'second')
          .groupNames,
      isEmpty,
    );
  });
}

ClipboardRecord _record(DateTime now, {String? source}) {
  return ClipboardRecord(
    id: 'clip',
    group: 'Clipboard',
    title: 'Run tests',
    content: 'flutter test',
    tags: const <String>['clipboard', 'command'],
    source: source,
    pinned: false,
    enabled: true,
    activation: 'taskMatch',
    createdAt: now,
    updatedAt: now,
  );
}

final class _RecordingClipboardGateway
    implements
        ClipboardGateway,
        FormattedTextClipboardGateway,
        ImageClipboardGateway {
  String? writtenText;
  List<String>? writtenFiles;
  String? writtenImagePath;
  String? formattedPlainText;
  Uint8List? formattedHtmlData;
  Uint8List? formattedRtfData;

  void clearWrites() {
    writtenText = null;
    writtenFiles = null;
    writtenImagePath = null;
    formattedPlainText = null;
    formattedHtmlData = null;
    formattedRtfData = null;
  }

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

  @override
  Future<bool> writeImageFile(String path) async {
    writtenImagePath = path;
    return true;
  }

  @override
  Future<void> writeFormattedText({
    required String plainText,
    Uint8List? htmlData,
    Uint8List? rtfData,
  }) async {
    formattedPlainText = plainText;
    formattedHtmlData = htmlData;
    formattedRtfData = rtfData;
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
