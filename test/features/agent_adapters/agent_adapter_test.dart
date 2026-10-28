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
      'opencode',
      'antigravity',
      'antigravity-cli',
      'copilot-cli',
      'windsurf',
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

    final AgentAdapter opencode = AgentAdapter.parse(documents['opencode']!);
    expect(opencode.globalSkillPath, '~/.config/opencode/skills');
    expect(opencode.projectSkillPath, '.opencode/skills');
    expect(opencode.mcpFilePath, '~/.config/opencode/opencode.json');
    expect(opencode.mcpKind!.configValue, 'opencode-json');

    final AgentAdapter antigravity = AgentAdapter.parse(
      documents['antigravity']!,
    );
    expect(antigravity.globalSkillPath, '~/.gemini/config/skills');
    expect(antigravity.projectSkillPath, '.agents/skills');
    expect(antigravity.mcpFilePath, '~/.gemini/config/mcp_config.json');
    expect(antigravity.mcpKind!.configValue, 'antigravity-json');

    final AgentAdapter antigravityCli = AgentAdapter.parse(
      documents['antigravity-cli']!,
    );
    expect(antigravityCli.globalSkillPath, '~/.gemini/antigravity-cli/skills');
    expect(antigravityCli.projectSkillPath, '.agents/skills');
    expect(antigravityCli.mcpFilePath, antigravity.mcpFilePath);

    final AgentAdapter copilot = AgentAdapter.parse(documents['copilot-cli']!);
    expect(copilot.globalSkillPath, '~/.copilot/skills');
    expect(copilot.projectSkillPath, '.github/skills');
    expect(copilot.mcpFilePath, '~/.copilot/mcp-config.json');
    expect(copilot.mcpKind!.configValue, 'copilot-json');

    final AgentAdapter windsurf = AgentAdapter.parse(documents['windsurf']!);
    expect(windsurf.globalSkillPath, '~/.codeium/windsurf/skills');
    expect(windsurf.projectSkillPath, '.windsurf/skills');
    expect(windsurf.mcpFilePath, isNull);
  });
}
