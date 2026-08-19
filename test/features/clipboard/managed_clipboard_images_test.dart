import 'dart:io';

import 'package:dingdong/features/clipboard/domain/managed_clipboard_images.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test(
    'cache pruning removes a symlink without deleting its source image',
    () async {
      final Directory root = await Directory.systemTemp.createTemp(
        'dingdong-image-cache-safety-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      final Directory sourceDirectory = Directory(
        path.join(root.path, 'Source'),
      )..createSync();
      final Directory cacheDirectory = Directory(path.join(root.path, 'Cache'))
        ..createSync();
      final File source = File(path.join(sourceDirectory.path, 'original.png'))
        ..writeAsBytesSync(<int>[1, 2, 3]);
      final Link link = Link(path.join(cacheDirectory.path, 'linked.png'))
        ..createSync(source.path);

      final int deleted = pruneUnreferencedManagedClipboardImages(
        const <Never>[],
        cacheDirectory,
      );

      expect(deleted, 1);
      expect(link.existsSync(), isFalse);
      expect(source.existsSync(), isTrue);
      expect(source.readAsBytesSync(), <int>[1, 2, 3]);
    },
  );
}
