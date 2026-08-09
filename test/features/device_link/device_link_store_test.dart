import 'dart:io';

import 'package:dingdong/features/device_link/data/device_link_store.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileDeviceLinkStore', () {
    test('serializes concurrent saves to the same path', () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-device-link-store-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final File file = File('${directory.path}/device-links.json');
      final FileDeviceLinkStore first = FileDeviceLinkStore(file);
      final FileDeviceLinkStore second = FileDeviceLinkStore(file);

      final List<Future<void>> saves = <Future<void>>[];
      for (var index = 0; index < 80; index += 1) {
        saves.add((index.isEven ? first : second).save(_document(index)));
      }
      await Future.wait(saves);

      final DeviceLinkDocument? loaded = await first.load();
      expect(loaded, isNotNull);
      expect(loaded!.localDevice.id, 'desktop-79');
      expect(loaded.localDevice.name, 'Desktop 79');
      expect(
        await directory.list().where((FileSystemEntity entity) {
          return entity.path.startsWith('${file.path}.tmp.');
        }).toList(),
        isEmpty,
      );
    });

    test(
      'preserves invalid bytes and requires explicit recovery before replace',
      () async {
        final Directory directory = await Directory.systemTemp.createTemp(
          'dingdong-device-link-corrupt-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final File file = File('${directory.path}/device-links.json');
        final List<int> invalidBytes = <int>[0xff, 0xfe, 0x00, 0x7b, 0x7d];
        await file.writeAsBytes(invalidBytes, flush: true);
        final FileDeviceLinkStore store = FileDeviceLinkStore(file);

        late DeviceLinkStoreCorruptedException error;
        try {
          await store.load();
          fail('A corrupted device-link document must not load as null.');
        } on DeviceLinkStoreCorruptedException catch (caught) {
          error = caught;
        }

        expect(error.file.path, file.path);
        expect(error.cause, isA<FormatException>());
        expect(error.preservationError, isNull);
        expect(error.preservedFile, isNotNull);
        expect(error.preservedFile!.path, startsWith('${file.path}.corrupt.'));
        expect(await file.readAsBytes(), invalidBytes);
        expect(await error.preservedFile!.readAsBytes(), invalidBytes);

        await store.save(_document(1));

        expect((await store.load())!.localDevice.id, 'desktop-1');
        expect(
          await error.preservedFile!.readAsBytes(),
          invalidBytes,
          reason: 'Explicit recovery must not delete the preserved original.',
        );
      },
    );

    test(
      'rejects structurally invalid JSON without dropping devices',
      () async {
        final Directory directory = await Directory.systemTemp.createTemp(
          'dingdong-device-link-schema-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final File file = File('${directory.path}/device-links.json');
        await file.writeAsString(
          '{"version":1,"localDevice":{"id":"desktop","name":"Studio",'
          '"platform":"macos"},"devices":["invalid-device"]}',
          flush: true,
        );

        await expectLater(
          FileDeviceLinkStore(file).load(),
          throwsA(
            isA<DeviceLinkStoreCorruptedException>().having(
              (DeviceLinkStoreCorruptedException error) => error.preservedFile,
              'preservedFile',
              isNotNull,
            ),
          ),
        );

        expect(await file.readAsString(), contains('invalid-device'));
      },
    );
  });
}

DeviceLinkDocument _document(int index) {
  return DeviceLinkDocument(
    localDevice: LocalDeviceIdentity(
      id: 'desktop-$index',
      name: 'Desktop $index',
      platform: 'macos',
    ),
    devices: const <LinkedDevice>[],
  );
}
