import 'dart:io';
import 'dart:typed_data';

import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_capture_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'capture classifies and stores text read through the platform seam',
    () async {
      final InMemoryClipboardStore store = InMemoryClipboardStore();
      final ClipboardCaptureService service = ClipboardCaptureService(
        gateway: _FakeClipboardGateway(
          const ClipboardSnapshot(text: 'flutter test', source: 'Terminal'),
        ),
        store: store,
        idGenerator: () => 'C53836D8-EAD9-4FD0-9267-A9642CA6232D',
        now: () => DateTime.utc(2026, 7, 12),
      );

      final record = await service.capture();

      expect(record?.group, isEmpty);
      expect(record?.title, 'flutter test');
      expect(store.list(limit: 10).single.id, record?.id);
    },
  );

  test(
    'capture stores file URLs before any plain-text representation',
    () async {
      final InMemoryClipboardStore store = InMemoryClipboardStore();
      final ClipboardCaptureService service = ClipboardCaptureService(
        gateway: _FakeClipboardGateway(
          const ClipboardSnapshot(
            text: 'ignored fallback',
            filePaths: <String>[
              '/Users/me/Desktop/reference.png',
              '/Users/me/Desktop/notes.txt',
            ],
          ),
        ),
        store: store,
        idGenerator: () => 'FILES-ID',
        now: () => DateTime.utc(2026, 7, 12),
      );

      final record = await service.capture();

      expect(record?.group, isEmpty);
      expect(record?.title, '2 items · reference.png');
      expect(
        record?.content,
        '/Users/me/Desktop/reference.png\n/Users/me/Desktop/notes.txt',
      );
      expect(
        record?.tags,
        containsAll(<String>['file', 'file-url', 'ext:png']),
      );
    },
  );

  test('capture persists a raw clipboard image as a restorable file', () async {
    final Directory directory = Directory.systemTemp.createTempSync(
      'dingdong-flutter-clipboard-image-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final InMemoryClipboardStore store = InMemoryClipboardStore();
    final ClipboardCaptureService service = ClipboardCaptureService(
      gateway: _FakeClipboardGateway(
        ClipboardSnapshot(
          imageBytes: Uint8List.fromList(<int>[0x89, 0x50, 0x4e, 0x47]),
        ),
      ),
      store: store,
      imageStoreDirectory: directory,
      idGenerator: () => 'IMAGE-ID',
      now: () => DateTime.utc(2026, 7, 12),
    );

    final record = await service.capture();

    expect(record?.group, isEmpty);
    expect(record?.tags, containsAll(<String>['file', 'file-url', 'image']));
    final File image = File(record!.content);
    expect(image.existsSync(), isTrue);
    expect(image.readAsBytesSync(), <int>[0x89, 0x50, 0x4e, 0x47]);
  });
}

final class _FakeClipboardGateway implements ClipboardGateway {
  _FakeClipboardGateway(this.snapshot);

  final ClipboardSnapshot snapshot;

  @override
  Future<ClipboardSnapshot> read() async => snapshot;

  @override
  Future<void> writeText(String text) async {}

  @override
  Future<void> writeFiles(List<String> paths) async {}
}
