import 'dart:async';
import 'dart:io';

import 'package:dingdong/core/files/safe_managed_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent managed updates preserve both changes', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'dingdong-safe-file-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File file = File('${directory.path}/config.txt')
      ..writeAsStringSync('base');
    final SafeManagedFile first = SafeManagedFile(file);
    final SafeManagedFile second = SafeManagedFile(file);
    final Completer<void> firstStarted = Completer<void>();
    final Completer<void> releaseFirst = Completer<void>();

    final Future<bool> firstUpdate = first.update((
      ManagedFileSnapshot value,
    ) async {
      firstStarted.complete();
      await releaseFirst.future;
      return '${value.contents}-first';
    });
    await firstStarted.future;
    final Future<bool> secondUpdate = second.update(
      (ManagedFileSnapshot value) => '${value.contents}-second',
    );
    releaseFirst.complete();

    expect(await Future.wait(<Future<bool>>[firstUpdate, secondUpdate]), <bool>[
      true,
      true,
    ]);
    expect(await file.readAsString(), 'base-first-second');
  });

  test('a stale snapshot cannot overwrite an external edit', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'dingdong-safe-file-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File file = File('${directory.path}/config.txt')
      ..writeAsStringSync('inspected');
    final SafeManagedFile managed = SafeManagedFile(file);
    final ManagedFileSnapshot inspected = await managed.snapshot();
    await file.writeAsString('external', flush: true);

    await expectLater(
      managed.replaceIfUnchanged(inspected, 'dingdong'),
      throwsA(isA<ManagedFileConflictException>()),
    );
    expect(await file.readAsString(), 'external');
  });

  test('a stale snapshot cannot delete an external edit', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'dingdong-safe-file-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File file = File('${directory.path}/config.txt')
      ..writeAsStringSync('inspected');
    final SafeManagedFile managed = SafeManagedFile(file);
    final ManagedFileSnapshot inspected = await managed.snapshot();
    await file.writeAsString('external', flush: true);

    await expectLater(
      managed.deleteIfUnchanged(inspected),
      throwsA(isA<ManagedFileConflictException>()),
    );
    expect(await file.readAsString(), 'external');
  });

  test('replacement is validated and read back before success', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'dingdong-safe-file-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File file = File('${directory.path}/config.json')
      ..writeAsStringSync('{"valid":true}');
    final SafeManagedFile managed = SafeManagedFile(file);

    await expectLater(
      managed.update(
        (_) => 'not-json',
        validate: (String value) {
          if (!value.startsWith('{')) {
            throw const FormatException('invalid JSON');
          }
        },
      ),
      throwsFormatException,
    );
    expect(await file.readAsString(), '{"valid":true}');

    expect(
      await managed.update(
        (_) => '{"valid":false}',
        validate: (String value) {
          if (!value.endsWith('}')) {
            throw const FormatException('invalid JSON');
          }
        },
      ),
      isTrue,
    );
    expect(await file.readAsString(), '{"valid":false}');
  });

  test('replacement preserves POSIX permission bits where supported', () async {
    if (Platform.isWindows) {
      return;
    }
    final Directory directory = await Directory.systemTemp.createTemp(
      'dingdong-safe-file-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File file = File('${directory.path}/config.txt')
      ..writeAsStringSync('before');
    final ProcessResult chmod = await Process.run('chmod', <String>[
      '640',
      file.path,
    ]);
    expect(chmod.exitCode, 0);
    final int before = (await file.stat()).mode & 0xFFF;

    await SafeManagedFile(file).update((_) => 'after');

    expect((await file.stat()).mode & 0xFFF, before);
  });

  test(
    'a new managed file can be created with restrictive permissions',
    () async {
      if (Platform.isWindows) {
        return;
      }
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-safe-file-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final File file = File('${directory.path}/transaction.json');

      await SafeManagedFile(file, newFileMode: 0x180).update((_) => '{}');

      expect((await file.stat()).mode & 0xFFF, 0x180);
    },
  );

  test('does not restore an unrelated user backup', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'dingdong-safe-file-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File file = File('${directory.path}/AGENTS.md');
    final File userBackup = File('${file.path}.manual.bak')
      ..writeAsStringSync('user backup');

    final ManagedFileSnapshot snapshot = await SafeManagedFile(file).snapshot();

    expect(snapshot.exists, isFalse);
    expect(await userBackup.readAsString(), 'user backup');
  });

  test('restores an interrupted DingDong replacement', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'dingdong-safe-file-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File file = File('${directory.path}/config.json');
    File('${file.path}.dingdong-bak.123.1').writeAsStringSync('managed backup');

    final ManagedFileSnapshot snapshot = await SafeManagedFile(file).snapshot();

    expect(snapshot.exists, isTrue);
    expect(snapshot.contents, 'managed backup');
    expect(await file.readAsString(), 'managed backup');
  });
}
