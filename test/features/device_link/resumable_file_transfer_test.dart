import 'dart:io';
import 'dart:typed_data';
import 'package:dingdong/features/device_link/data/resumable_file_transfer.dart';
import 'package:dingdong/features/device_link/domain/file_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'completion failure resumes the finalized body and repeated sends are new transfers',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dingdong-finish-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final source = await File(
        '${directory.path}/source',
      ).writeAsString('real content');
      late ResumableFileTransfers sender, receiver;
      var attempts = 0, chunks = 0;
      sender = ResumableFileTransfers(
        directory: Directory('${directory.path}/a'),
        isLan: (_) async => true,
        onChange: () {},
        onReceived: (_, _, _) async {},
        send: (_, message) async {
          if (message['type'] == 'transfer.chunk') chunks++;
          await receiver.handle('a', message);
        },
      );
      receiver = ResumableFileTransfers(
        directory: Directory('${directory.path}/b'),
        isLan: (_) async => true,
        onChange: () {},
        send: (_, message) => sender.handle('b', message),
        onReceived: (_, file, _) async {
          expect(await file.readAsString(), 'real content');
          if (++attempts == 1) {
            throw const FileSystemException('test storage issue');
          }
        },
      );
      addTearDown(sender.dispose);
      addTearDown(receiver.dispose);
      final first = await sender.sendFile('b', source, name: 'file');
      expect(first.status, 'failed');
      await sender.control('b', first.id, 'resume');
      expect(first.status, 'completed');
      expect(chunks, 1);
      final second = await sender.sendFile('b', source, name: 'file');
      expect(second.status, 'completed');
      expect(second.id, isNot(first.id));
      expect(attempts, 3);
    },
  );

  test('cancelled zero-byte offers cannot be finalized or revived', () async {
    final directory = await Directory.systemTemp.createTemp('dingdong-cancel-');
    addTearDown(() => directory.delete(recursive: true));
    final replies = <Map<String, Object?>>[];
    final engine = ResumableFileTransfers(
      directory: directory,
      isLan: (_) async => true,
      onChange: () {},
      send: (_, message) async => replies.add(message),
      onReceived: (_, _, _) async => fail('cancelled file completed'),
    );
    addTearDown(engine.dispose);
    final offer = <String, Object?>{
      'type': 'transfer.offer',
      'id': 'empty',
      'request': '1',
      'name': 'file',
      'size': 0,
      'fingerprint': 'source',
    };
    await engine.handle('peer', offer);
    await engine.control('peer', 'empty', 'cancel');
    await engine.handle('peer', {
      'type': 'transfer.finish',
      'id': 'empty',
      'request': '2',
    });
    expect(replies.last['error'], 'cancelled');
    await engine.handle('peer', offer);
    expect(replies.last['error'], 'cancelled');
    expect(await directory.list().length, 0);
  });

  test(
    'a large file stays waiting and sends no content on an unverified route',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dingdong-limit-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final source = File('${directory.path}/large');
      final writer = await source.open(mode: FileMode.write);
      await writer.truncate(relayFileLimit + 1);
      await writer.close();
      var sends = 0;
      final engine = ResumableFileTransfers(
        directory: directory,
        isLan: (_) async => false,
        send: (_, _) async {
          sends++;
        },
        onChange: () {},
        onReceived: (_, _, _) async {},
      );
      addTearDown(engine.dispose);
      final view = await engine.sendFile('peer', source, name: 'large.bin');
      expect(view.status, 'waiting');
      expect(view.detail, 'waiting_lan');
      expect(sends, 0);
    },
  );

  test('corrupt chunks never advance persisted progress', () async {
    final directory = await Directory.systemTemp.createTemp('dingdong-digest-');
    addTearDown(() => directory.delete(recursive: true));
    final replies = <Map<String, Object?>>[];
    final engine = ResumableFileTransfers(
      directory: directory,
      isLan: (_) async => true,
      send: (_, message) async => replies.add(message),
      onChange: () {},
      onReceived: (_, _, _) async {},
    );
    addTearDown(engine.dispose);
    await engine.handle('peer', {
      'type': 'transfer.offer',
      'id': 'test',
      'request': '1',
      'name': 'file',
      'size': 3,
      'fingerprint': 'source',
    });
    await engine.handle('peer', {
      'type': 'transfer.chunk',
      'id': 'test',
      'request': '2',
      'offset': 0,
      'data': 'AQID',
      'digest': 'not-the-digest',
    });
    expect(replies.last['error'], 'checksum_failed');
    expect(engine.transfers.single.bytes, 0);
    expect(
      await directory
          .list()
          .where((entry) => entry.path.endsWith('.part'))
          .cast<File>()
          .first
          .then((file) => file.length()),
      0,
    );
  });
  test(
    'receiver-confirmed progress resumes at its saved offset after an interruption',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dingdong-resume-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final content = Uint8List.fromList(
        List.generate(transferChunkBytes * 3 + 17, (i) => i % 251),
      );
      final source = await File(
        '${directory.path}/source',
      ).writeAsBytes(content);
      late ResumableFileTransfers sender, receiver;
      var interrupt = true;
      final offsets = <int>[];
      File? received;
      sender = ResumableFileTransfers(
        directory: Directory('${directory.path}/a'),
        isLan: (_) async => true,
        send: (peer, message) async {
          if (message['type'] == 'transfer.chunk') {
            offsets.add(message['offset']! as int);
            if (interrupt && offsets.length == 2) {
              throw const SocketException('test disconnect');
            }
          }
          await receiver.handle('a', message);
        },
        onChange: () {},
        onReceived: (_, file, _) async {},
      );
      receiver = ResumableFileTransfers(
        directory: Directory('${directory.path}/b'),
        isLan: (_) async => true,
        send: (peer, message) => sender.handle('b', message),
        onChange: () {},
        onReceived: (_, file, _) async => received = file,
      );
      addTearDown(sender.dispose);
      addTearDown(receiver.dispose);
      final transfer = await sender.sendFile('b', source, name: 'sample.bin');
      expect(transfer.bytes, transferChunkBytes);
      expect(transfer.status, 'waiting');
      interrupt = false;
      await sender.control('b', transfer.id, 'resume');
      expect(offsets, [
        0,
        transferChunkBytes,
        transferChunkBytes,
        transferChunkBytes * 2,
        transferChunkBytes * 3,
      ]);
      expect(transfer.status, 'completed');
      expect(await received!.readAsBytes(), content);
    },
  );
}
