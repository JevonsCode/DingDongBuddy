import 'dart:async';
import 'dart:io';

import 'package:dingdong/features/agent_adapters/data/agent_adapter_repository.dart';
import 'package:dingdong/features/agent_adapters/ui/agent_adapter_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reloads when an external Agent changes a user Adapter file', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-adapter-watch-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final Directory user = Directory('${temp.path}/adapters');
    final Completer<void> synchronized = Completer<void>();
    final AgentAdapterController controller = AgentAdapterController(
      repository: AgentAdapterRepository(
        userDirectory: user,
        historyDirectory: Directory('${temp.path}/history'),
        homeDirectory: '${temp.path}/home',
        loadBuiltIns: () async => <String, String>{'codex': _codex},
      ),
      onAdaptersChanged: () async {
        if (!synchronized.isCompleted) {
          synchronized.complete();
        }
      },
    );
    addTearDown(controller.close);
    await controller.load();
    final Completer<void> observed = Completer<void>();
    controller.addListener(() {
      if (!observed.isCompleted &&
          controller.selectedEntry?.displayName == 'Codex External') {
        observed.complete();
      }
    });

    await Future<void>.delayed(const Duration(milliseconds: 100));
    final File temporary = File('${user.path}/codex.yaml.external-tmp');
    await temporary.writeAsString(
      _codex.replaceFirst('displayName: Codex', 'displayName: Codex External'),
      flush: true,
    );
    await temporary.rename('${user.path}/codex.yaml');

    await observed.future.timeout(const Duration(seconds: 3));
    await synchronized.future.timeout(const Duration(seconds: 3));
    expect(controller.selectedEntry?.isCustomized, isTrue);
    expect(controller.history, hasLength(2));
  });

  test('synchronizes resources after an Adapter is saved', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-adapter-sync-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    var synchronizationCount = 0;
    final AgentAdapterController controller = AgentAdapterController(
      repository: AgentAdapterRepository(
        userDirectory: Directory('${temp.path}/adapters'),
        historyDirectory: Directory('${temp.path}/history'),
        homeDirectory: '${temp.path}/home',
        loadBuiltIns: () async => <String, String>{'codex': _codex},
      ),
      onAdaptersChanged: () async => synchronizationCount += 1,
    );
    addTearDown(controller.close);
    await controller.load();

    await controller.save(
      _codex.replaceFirst('displayName: Codex', 'displayName: Codex Custom'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(controller.error, isNull);
    expect(controller.selectedEntry?.displayName, 'Codex Custom');
    expect(synchronizationCount, 1);
  });
}

const String _codex = '''
schemaVersion: 1
id: codex
displayName: Codex
detect:
  directory: ~/.codex
mcp:
  file: ~/.codex/config.toml
  format: codex-toml
''';
