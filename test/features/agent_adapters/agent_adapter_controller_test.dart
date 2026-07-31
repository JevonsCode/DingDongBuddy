import 'dart:async';
import 'dart:io';

import 'package:dingdong/features/agent_adapters/data/agent_adapter_repository.dart';
import 'package:dingdong/features/agent_adapters/domain/codex_completion_hook.dart';
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

  test('checks and repairs the Codex completion Hook on demand', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-adapter-hook-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final _FakeCodexCompletionHookGateway gateway =
        _FakeCodexCompletionHookGateway();
    final AgentAdapterController controller = AgentAdapterController(
      repository: AgentAdapterRepository(
        userDirectory: Directory('${temp.path}/adapters'),
        historyDirectory: Directory('${temp.path}/history'),
        homeDirectory: '${temp.path}/home',
        loadBuiltIns: () async => <String, String>{'codex': _codex},
      ),
      watchExternalChanges: false,
      codexCompletionHookGateway: gateway,
    );
    addTearDown(controller.close);

    await controller.load();
    await Future<void>.delayed(Duration.zero);

    expect(gateway.inspectCount, 1);
    expect(
      controller.codexCompletionHookStatus.review,
      CodexCompletionHookReview.untrusted,
    );

    await controller.repairCodexCompletionHook();

    expect(gateway.repairCount, 1);
    expect(controller.codexCompletionHookStatus.isOperational, isTrue);
  });
}

final class _FakeCodexCompletionHookGateway
    implements CodexCompletionHookGateway {
  int inspectCount = 0;
  int repairCount = 0;

  @override
  Future<CodexCompletionHookStatus> inspect() async {
    inspectCount += 1;
    return const CodexCompletionHookStatus(
      review: CodexCompletionHookReview.untrusted,
      enabled: true,
      key: '/Users/tester/.codex/config.toml:stop:0:0',
      command: 'dingdong_mcp --notify-stop --source Codex',
      currentHash: 'sha256:current-hook',
    );
  }

  @override
  Future<CodexCompletionHookStatus> repair({
    required String expectedKey,
    required String expectedHash,
  }) async {
    repairCount += 1;
    expect(expectedKey, '/Users/tester/.codex/config.toml:stop:0:0');
    expect(expectedHash, 'sha256:current-hook');
    return const CodexCompletionHookStatus(
      review: CodexCompletionHookReview.trusted,
      enabled: true,
      key: '/Users/tester/.codex/config.toml:stop:0:0',
      command: 'dingdong_mcp --notify-stop --source Codex',
      currentHash: 'sha256:current-hook',
    );
  }
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
