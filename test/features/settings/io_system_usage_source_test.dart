import 'dart:io';

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
