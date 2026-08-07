import 'dart:io';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/settings/data/io_system_usage_source.dart';
import 'package:dingdong/features/settings/domain/system_usage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('local storage files are measured by stable data category', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'dingdong-usage-test-',
    );
    addTearDown(() => directory.delete(recursive: true));

    await _writeBytes(directory, 'clipboard-history.sqlite', 3);
    await _writeBytes(directory, 'Clipboard Images/image.png', 5);
    await _writeBytes(directory, 'resource-library.json', 2);
    await _writeBytes(directory, 'Skill Packages/demo/SKILL.md', 7);
    await _writeBytes(directory, 'agent-activity.json', 4);
    await _writeBytes(directory, 'Agent Adapter History/codex.json', 6);
    await _writeBytes(directory, 'Agent Adapters/codex.yaml', 8);
    await _writeBytes(directory, 'unrecognized.bin', 9);

    final SystemUsageSnapshot usage = await IoSystemUsageSource(
      directory,
    ).load();

    expect(usage.storageBytes, 44);
    expect(usage.bytesFor(SystemDataCategory.clipboardHistory), 8);
    expect(usage.bytesFor(SystemDataCategory.resourceLibrary), 9);
    expect(usage.bytesFor(SystemDataCategory.agentActivity), 4);
    expect(usage.bytesFor(SystemDataCategory.adapterHistory), 6);
    expect(usage.bytesFor(SystemDataCategory.configuration), 8);
    expect(usage.bytesFor(SystemDataCategory.other), 9);
    expect(usage.residentMemoryBytes, greaterThan(0));
  });

  test(
    'clipboard usage separates history types and protected archives',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-usage-clipboard-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final Directory images = Directory(
        path.join(directory.path, 'Clipboard Images'),
      )..createSync();
      final File historyImage = File(path.join(images.path, 'history.png'))
        ..writeAsBytesSync(List<int>.filled(11, 1));
      final File archivedImage = File(path.join(images.path, 'archive.png'))
        ..writeAsBytesSync(List<int>.filled(17, 1));
      final ClipboardRepository repository = ClipboardRepository.open(
        path.join(directory.path, 'clipboard-history.sqlite'),
      );
      final DateTime now = DateTime.utc(2026, 8, 6);
      repository
        ..save(
          _record(
            id: 'history-image',
            content: historyImage.path,
            tags: const <String>['clipboard', 'file', 'file-url', 'image'],
            now: now,
          ),
        )
        ..save(
          _record(
            id: 'archive-image',
            group: 'Project Alpha',
            content: archivedImage.path,
            tags: const <String>['clipboard', 'file', 'file-url', 'image'],
            now: now,
          ),
        )
        ..save(
          _record(
            id: 'text',
            content: 'hello',
            tags: const <String>['clipboard', 'text'],
            now: now,
          ),
        )
        ..save(
          _record(
            id: 'file',
            content: '/tmp/report.pdf',
            tags: const <String>['clipboard', 'file', 'file-url'],
            now: now,
          ),
        )
        ..close();

      final SystemUsageSnapshot usage = await IoSystemUsageSource(
        directory,
      ).load();

      expect(usage.itemsFor(SystemDataCategory.clipboardImages), 2);
      expect(usage.itemsFor(SystemDataCategory.clipboardText), 1);
      expect(usage.itemsFor(SystemDataCategory.clipboardFiles), 1);
      expect(usage.itemsFor(SystemDataCategory.clipboardArchive), 1);
      expect(
        usage.bytesFor(SystemDataCategory.clipboardImages),
        greaterThanOrEqualTo(historyImage.lengthSync()),
      );
      expect(
        usage.bytesFor(SystemDataCategory.clipboardArchive),
        greaterThanOrEqualTo(archivedImage.lengthSync()),
      );
    },
  );
}

ClipboardRecord _record({
  required String id,
  required String content,
  required List<String> tags,
  required DateTime now,
  String group = '',
}) {
  return ClipboardRecord(
    id: id,
    group: group,
    title: id,
    content: content,
    tags: tags,
    pinned: false,
    enabled: true,
    activation: 'taskMatch',
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _writeBytes(
  Directory root,
  String relativePath,
  int length,
) async {
  final File file = File(path.join(root.path, relativePath));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(List<int>.filled(length, 1), flush: true);
}
