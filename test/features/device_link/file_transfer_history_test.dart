import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/device_link/data/file_transfer_history.dart';
import 'package:dingdong/features/device_link/domain/file_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retry failures at the same offset keep the latest reason', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dingdong-history-retry-',
    );
    final history = FileTransferHistory(File('${directory.path}/history.json'));
    addTearDown(() async {
      await history.flush();
      await directory.delete(recursive: true);
    });
    final transfer = FileTransfer(
      id: 'retry',
      deviceId: 'peer',
      name: 'file.txt',
      size: 12,
      sending: true,
      status: 'failed',
      detail: 'source_changed',
    );
    history.remember(transfer, 'JARVIS');
    transfer.detail = 'checksum_failed';
    history.remember(transfer, 'JARVIS');
    expect(history.records.single.detail, 'checksum_failed');
  });

  test(
    'history stays bounded and repeated progress cannot resurrect an evicted record',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dingdong-history-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/history.json');
      final history = FileTransferHistory(file);
      final transfers = List.generate(
        101,
        (index) => FileTransfer(
          id: '$index',
          deviceId: 'peer',
          name: 'file-$index.txt',
          size: 12,
          bytes: 12,
          status: 'completed',
          sending: true,
          itemId: '/private/source-not-for-history',
        ),
      );
      for (final transfer in transfers) {
        history.remember(transfer, 'JARVIS');
      }
      history.remember(transfers.first, 'JARVIS');
      expect(history.records, hasLength(100));
      expect(history.records.any((record) => record.id == '0'), isFalse);
      await history.flush();
      final raw = await file.readAsString();
      expect(raw, isNot(contains('/private/source-not-for-history')));
      final restored = FileTransferHistory(file);
      await restored.load();
      expect(restored.records, hasLength(100));
      expect(restored.records.first.deviceName, 'JARVIS');
      expect(restored.records.every((record) => record.archived), isTrue);
    },
  );

  test(
    'one invalid history entry does not hide valid records and deleting a peer persists',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dingdong-history-load-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/history.json');
      await file.writeAsString(
        jsonEncode([
          {'id': 'invalid'},
          FileTransfer(
            id: 'good',
            deviceId: 'peer',
            name: 'good.txt',
            size: 0,
            sending: false,
            status: 'completed',
          ).toJson(),
        ]),
      );
      final history = FileTransferHistory(file);
      await history.load();
      expect(history.records.single.name, 'good.txt');
      history.forgetDevice('peer');
      await history.flush();
      final restored = FileTransferHistory(file);
      await restored.load();
      expect(restored.records, isEmpty);
    },
  );
}
