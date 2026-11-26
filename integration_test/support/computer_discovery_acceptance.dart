// A native two-machine acceptance runner. Use a new private fixture directory
// per run on each machine; it never opens the user's databases or clipboard.
import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/device_link/data/device_link_store.dart';
import 'package:dingdong/features/device_link/data/lan_computer_link.dart';
import 'package:dingdong/features/device_link/ui/device_link_controller.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await runAcceptance().timeout(const Duration(minutes: 3));
    exit(0);
  } catch (error, stack) {
    stderr.writeln('Acceptance failed: ${error.runtimeType} $error\n$stack');
    exit(1);
  }
}

Future<void> runAcceptance() async {
  final env = Platform.environment;
  final host = env['DD_TEST_ROLE'] == 'host';
  final phase = env['DD_TEST_PHASE']!;
  final dir = Directory(env['DD_TEST_DIR']!);
  final discoveryUri = Uri.parse(env['DD_TEST_SERVICE']!);
  final link = LanComputerLink(
    discoveryBaseUrl: discoveryUri,
    discoveryPort: int.parse(env['DD_TEST_PORT']!),
  );
  final clipboard = InMemoryClipboardStore();
  final store = FileDeviceLinkStore(File('${dir.path}/pair.json'));
  final controller = DeviceLinkController(
    store: store,
    clipboardStore: clipboard,
    transferDirectory: Directory('${dir.path}/files'),
    computerLink: link,
    relayBaseUrl: null,
    pwaBaseUrl: null,
  );
  await controller.start();
  try {
    if (phase == 'first') {
      if (controller.devices.isNotEmpty) {
        throw StateError('Expected an empty fixture');
      }
      final codeFile = File('${dir.path}/code');
      if (host) {
        await controller.beginComputerPairing();
        if (!link.codeLookupAvailable) {
          throw StateError('Invitation registration failed');
        }
        await codeFile.writeAsString(controller.computerPairingCode!);
      } else {
        await controller.joinComputer((await codeFile.readAsString()).trim());
      }
    } else if (phase == 'reconnect') {
      if (controller.devices.length != 1 ||
          controller.devices.single.lanAddress != '192.0.2.19') {
        throw StateError('Expected stale persisted peer address');
      }
    } else {
      throw ArgumentError('Unknown phase');
    }
    await until(() => controller.connectedDeviceCount == 1);
    final peer = controller.devices.single;
    final actualAddress = link.connectedAddressOf(peer.id);
    if (actualAddress == null) throw StateError('No direct TCP socket');
    stdout.writeln('CONNECTED $phase remote=$actualAddress');
    await File('${dir.path}/connected-$phase').writeAsString(actualAddress);

    // The orchestrator may stop the discovery service after both endpoints
    // are connected. It then opens this gate to exercise both data directions.
    final gate = File('${dir.path}/transfer-$phase');
    await until(gate.existsSync);
    final text = 'discovery acceptance $phase';
    final bytes = List.generate(131071, (i) => (i * 17 + 13) & 255);
    final digest = await Sha256().hash(bytes);
    if (!host) {
      await controller.shareRecord(record(text, false), peer.id);
      final file = File('${dir.path}/acceptance.bin');
      await file.writeAsBytes(bytes);
      await controller.shareRecord(record(file.path, true), peer.id);
      await until(
        () =>
            clipboard.list(limit: 10).any((r) => r.content == 'received $text'),
      );
    } else {
      await until(
        () => clipboard.list(limit: 10).any((r) => r.content == text),
      );
      await until(
        () => clipboard.list(limit: 10).any((r) => r.filePaths.isNotEmpty),
      );
      final received = clipboard
          .list(limit: 10)
          .firstWhere((r) => r.filePaths.isNotEmpty);
      final actual = await Sha256().hash(
        await File(received.filePaths.single).readAsBytes(),
      );
      if (actual != digest) throw StateError('File digest mismatch');
      await controller.shareRecord(record('received $text', false), peer.id);
    }
    stdout.writeln('PASS $phase bytes=${bytes.length} sha256=$digest');
  } finally {
    await controller.shutdown();
  }
}

Future<void> until(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 100));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Acceptance condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

ClipboardRecord record(String content, bool file) {
  final now = DateTime.now().toUtc();
  return ClipboardRecord(
    id: 'accept-${now.microsecondsSinceEpoch}',
    group: '',
    title: 'Acceptance',
    content: content,
    tags: ['clipboard', file ? 'file' : 'text'],
    pinned: false,
    enabled: true,
    activation: 'taskMatch',
    createdAt: now,
    updatedAt: now,
  );
}
