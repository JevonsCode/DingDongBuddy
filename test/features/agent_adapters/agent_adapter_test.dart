import 'dart:io';

import 'package:dingdong/features/agent_adapters/data/agent_adapter_repository.dart';
import 'package:dingdong/features/agent_adapters/domain/agent_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses a declarative Agent Adapter and resolves paths', () {
    final AgentAdapter adapter = AgentAdapter.parse('''
schemaVersion: 1
id: new-agent
displayName: New Agent
detect:
  directory: ~/.new-agent
skills:
  global: ~/.new-agent/skills
  project: .new-agent/skills
mcp:
  file: ~/.new-agent/mcp.json
  format: mcpServers-json
prompt:
  file: ~/.new-agent/AGENTS.md
  includeBridgeRoutingInstructions: false
''');

    expect(adapter.id, 'new-agent');
    expect(adapter.displayName, 'New Agent');
    final String homeDirectory = Platform.isWindows
        ? r'C:\Users\example'
        : '/Users/example';
    expect(
      adapter.resolvedGlobalSkillPath(homeDirectory),
      path.join(homeDirectory, '.new-agent', 'skills'),
    );
    expect(
      adapter.resolvedProjectSkillPath(),
      path.join('.new-agent', 'skills'),
    );
    expect(adapter.mcpKind, AgentMcpConfigKind.mcpServersJson);
    expect(adapter.includeBridgeRoutingInstructions, isFalse);
  });

  test('rejects unknown fields, unsafe paths, and unknown MCP formats', () {
    expect(
      () => AgentAdapter.parse('''
schemaVersion: 1
id: unsafe
displayName: Unsafe
detect:
  directory: ~/.unsafe
skills:
  global: ~/.unsafe/skills
  project: ../outside
'''),
      throwsFormatException,
    );
    expect(
      () => AgentAdapter.parse('''
schemaVersion: 1
id: unsafe
displayName: Unsafe
detect:
  directory: ~/.unsafe
mcp:
  file: ~/.unsafe/mcp.json
  format: arbitrary-script
'''),
      throwsFormatException,
    );
    expect(
      () => AgentAdapter.parse('''
schemaVersion: 1
id: unsafe
displayName: Unsafe
detect:
  directory: ~/.unsafe
command: rm
'''),
      throwsFormatException,
    );
    expect(
      () => AgentAdapter.parse(r'''
schemaVersion: 1
id: unsafe
displayName: Unsafe
detect:
  directory: ~/.unsafe
skills:
  global: ~/.unsafe/skills
  project: ..\outside
'''),
      throwsFormatException,
    );
  });

  test('loads every bundled Agent Adapter asset', () async {
    final Map<String, String> documents =
        await loadBundledAgentAdapterDocuments();

    expect(builtInAgentAdapterIds, <String>[
      'codex',
      'claude-code',
      'cursor',
      'gemini',
      'grok-build',
      'kiro',
      'pi',
    ]);
    expect(documents.keys, builtInAgentAdapterIds);
    expect(
      documents.values
          .map(AgentAdapter.parse)
          .map((AgentAdapter adapter) => adapter.id),
      builtInAgentAdapterIds,
    );

    final String homeDirectory = Platform.isWindows
        ? r'C:\Users\example'
        : '/Users/example';
    final AgentAdapter grok = AgentAdapter.parse(documents['grok-build']!);
    expect(grok.displayName, 'Grok Build');
    expect(
      grok.resolvedGlobalSkillPath(homeDirectory),
      path.join(homeDirectory, '.grok', 'skills'),
    );
    expect(grok.resolvedProjectSkillPath(), path.join('.grok', 'skills'));
    expect(grok.mcpFilePath, isNull);
    expect(grok.promptFilePath, isNull);

    final AgentAdapter pi = AgentAdapter.parse(documents['pi']!);
    expect(pi.displayName, 'Pi');
    expect(
      pi.resolvedGlobalSkillPath(homeDirectory),
      path.join(homeDirectory, '.pi', 'agent', 'skills'),
    );
    expect(pi.resolvedProjectSkillPath(), path.join('.pi', 'skills'));
    expect(pi.mcpFilePath, isNull);
    expect(pi.promptFilePath, isNull);
  });
}
