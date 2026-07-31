import 'dart:io';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/platform/url_launcher_clipboard_content_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'opens every available clipboard path with the system launcher',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-content-launcher-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final File first = await File(
        '${directory.path}${Platform.pathSeparator}first.png',
      ).writeAsBytes(<int>[1]);
      final File second = await File(
        '${directory.path}${Platform.pathSeparator}second.png',
      ).writeAsBytes(<int>[2]);
      final String missing =
          '${directory.path}${Platform.pathSeparator}missing.png';
      final List<Uri> launched = <Uri>[];
      final UrlLauncherClipboardContentLauncher launcher =
          UrlLauncherClipboardContentLauncher(
            launch: (Uri uri) async {
              launched.add(uri);
              return true;
            },
          );

      await launcher.open(
        _fileRecord('${first.path}\n$missing\n${second.path}'),
      );

      expect(launched, <Uri>[Uri.file(first.path), Uri.file(second.path)]);
    },
  );

  test('reports when no clipboard path remains available', () async {
    final UrlLauncherClipboardContentLauncher launcher =
        UrlLauncherClipboardContentLauncher(launch: (_) async => true);

    await expectLater(
      launcher.open(_fileRecord('/path/that/does/not/exist')),
      throwsA(isA<StateError>()),
    );
  });

  test('reports when the system refuses to open a file', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'dingdong-content-launcher-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File file = await File(
      '${directory.path}${Platform.pathSeparator}document.txt',
    ).writeAsString('content');
    final UrlLauncherClipboardContentLauncher launcher =
        UrlLauncherClipboardContentLauncher(launch: (_) async => false);

    await expectLater(
      launcher.open(_fileRecord(file.path)),
      throwsA(isA<StateError>()),
    );
  });
}

ClipboardRecord _fileRecord(String content) => ClipboardRecord(
  id: 'file',
  group: 'Files',
  title: 'File',
  content: content,
  tags: const <String>['clipboard', 'file', 'file-url'],
  pinned: false,
  enabled: true,
  activation: 'taskMatch',
  createdAt: DateTime.utc(2026, 7, 30),
  updatedAt: DateTime.utc(2026, 7, 30),
);
