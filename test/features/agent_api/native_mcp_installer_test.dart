import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/agent_api/data/native_mcp_installer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses JSON and quoted command-line MCP specifications', () {
    expect(
      McpCommandSpec.parse('{"command":"npx","args":["-y","server"]}'),
      const McpCommandSpec(command: 'npx', arguments: <String>['-y', 'server']),
    );
    expect(
      McpCommandSpec.parse('Local command: node "my server.js" --stdio'),
      const McpCommandSpec(
        command: 'node',
        arguments: <String>['my server.js', '--stdio'],
      ),
    );
  });

  test('dry run returns a Codex entry without touching the config', () async {
    final Directory directory = Directory.systemTemp.createTempSync(
      'dingdong-mcp-installer-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final File codex = File('${directory.path}/config.toml');
    final NativeMcpInstaller installer = NativeMcpInstaller(
      codexConfigFile: codex,
      claudeConfigFile: File('${directory.path}/claude.json'),
    );

    final result = await installer.install(
      serverName: 'release-helper',
      commandSpec: const McpCommandSpec(
        command: 'npx',
        arguments: <String>['-y', 'release-mcp'],
      ),
      target: 'codex',
      write: false,
    );

    expect(codex.existsSync(), isFalse);
    expect(result.entry['command'], 'npx');
    expect(result.configPath, codex.path);
  });

  test(
    'confirmed installs preserve unrelated Codex and Claude configuration',
    () async {
      final Directory directory = Directory.systemTemp.createTempSync(
        'dingdong-mcp-installer-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final File codex = File('${directory.path}/config.toml')
        ..writeAsStringSync('model = "gpt-5"\n');
      final File claude = File('${directory.path}/claude.json')
        ..writeAsStringSync('{"theme":"dark","mcpServers":{}}');
      final NativeMcpInstaller installer = NativeMcpInstaller(
        codexConfigFile: codex,
        claudeConfigFile: claude,
      );
      const McpCommandSpec spec = McpCommandSpec(
        command: 'node',
        arguments: <String>['server.js'],
      );

      await installer.install(
        serverName: 'helper',
        commandSpec: spec,
        target: 'codex',
        write: true,
      );
      await installer.install(
        serverName: 'helper',
        commandSpec: spec,
        target: 'claude',
        write: true,
      );

      expect(codex.readAsStringSync(), contains('model = "gpt-5"'));
      expect(codex.readAsStringSync(), contains('[mcp_servers.helper]'));
      final Map<String, Object?> claudeJson =
          jsonDecode(claude.readAsStringSync()) as Map<String, Object?>;
      expect(claudeJson['theme'], 'dark');
      expect(
        (claudeJson['mcpServers'] as Map<String, Object?>),
        contains('helper'),
      );
    },
  );
}
