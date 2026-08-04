import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_qr_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 3);

  ClipboardRecord record({
    String content = 'https://example.com/share',
    List<String> tags = const <String>['clipboard', 'url'],
  }) => ClipboardRecord(
    id: 'qr-record',
    group: 'Clipboard',
    title: 'Share with QR Code',
    content: content,
    tags: tags,
    pinned: false,
    enabled: true,
    activation: 'taskMatch',
    createdAt: now,
    updatedAt: now,
  );

  test('valid text keeps its exact content as a QR payload', () {
    const String content = '  line one\nline two  ';

    final ClipboardQrData? data = clipboardQrData(
      record(content: content, tags: const <String>['clipboard', 'text']),
    );

    expect(data?.payload, content);
    expect(data?.qrCode, isNotNull);
  });

  test('sensitive text remains available for QR sharing', () {
    final ClipboardQrData? data = clipboardQrData(
      record(tags: const <String>['clipboard', 'url', 'sensitive']),
    );

    expect(data, isNotNull);
  });

  test('empty, file-backed, image, and over-capacity content hide QR', () {
    expect(clipboardQrData(record(content: '   ')), isNull);
    expect(
      clipboardQrData(
        record(content: '/tmp/report.pdf', tags: const <String>['file']),
      ),
      isNull,
    );
    expect(
      clipboardQrData(
        record(content: '/tmp/image.png', tags: const <String>['image']),
      ),
      isNull,
    );
    expect(
      clipboardQrData(
        record(
          content: List<String>.filled(8000, 'x').join(),
          tags: const <String>['clipboard', 'text'],
        ),
      ),
      isNull,
    );
  });
}
