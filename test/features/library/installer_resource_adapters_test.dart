import 'dart:io';

import 'package:dingdong/features/agent_adapters/data/agent_adapter_repository.dart';
import 'package:dingdong/features/library/data/installer_resource_adapters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'resource targets follow installer overrides and shared extensions',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'jvs-a-resource-targets-',
      );
      final home = Directory(temporary.resolveSymbolicLinksSync());
      addTearDown(() => home.delete(recursive: true));
      await Directory('${home.path}/codex-custom').create();
      await Directory('${home.path}/.gemini').create();
      final extensions = Directory('${home.path}/extensions')..createSync();
      await File('${extensions.path}/local-agent.json').writeAsString('''{
      "schemaVersion":1,
      "install":{
        "name":"Local Agent",
        "detect":[{"path":"~/local-config"}],
        "mcp":{"file":"~/local-config/mcp.json","format":"mcp-servers-json"}
      }
    }''');
      await Directory('${home.path}/local-config').create();
      final repository = AgentAdapterRepository(
        userDirectory: Directory('${home.path}/adapters'),
        historyDirectory: Directory('${home.path}/history'),
        homeDirectory: home.path,
        loadBuiltIns: () async => {
          for (final id in ['codex', 'gemini'])
            id: await File('Assets/Agent Adapters/$id.yaml').readAsString(),
        },
      );
      final adapters = await loadInstallerResourceAdapters(
        repository,
        environment: {
          'HOME': home.path,
          'PATH': '',
          'CODEX_HOME': '${home.path}/codex-custom',
        },
        extensionsDirectory: extensions.path,
      );
      final codex = adapters.singleWhere((adapter) => adapter.id == 'codex');
      expect(
        codex.resolvedMcpFilePath(home.path),
        '${home.path}/codex-custom/config.toml',
      );
      expect(codex.resolvedProjectSkillPath(), '.agents/skills');
      expect(
        adapters.where((adapter) => adapter.displayName == 'Gemini CLI'),
        hasLength(1),
      );
      final local = adapters.singleWhere(
        (adapter) => adapter.id == 'local-agent',
      );
      expect(
        local.resolvedMcpFilePath(home.path),
        '${home.path}/local-config/mcp.json',
      );
      expect(local.isInstalled(home.path), isTrue);
    },
  );
}
