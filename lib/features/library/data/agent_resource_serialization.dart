part of 'agent_resource_synchronizer.dart';

// Encode client MCP formats and maintain DingDong-owned target metadata safely.
Map<String, Object?> _jsonMcp(
  McpConfiguration config,
  AgentMcpConfigKind kind,
) {
  final Map<String, String> headers = <String, String>{...config.headers};
  if (config.tokenEnvironmentVariable.isNotEmpty &&
      !headers.containsKey('Authorization')) {
    final String variable = config.tokenEnvironmentVariable;
    headers['Authorization'] = switch (kind) {
      AgentMcpConfigKind.claudeJson => 'Bearer \${$variable}',
      AgentMcpConfigKind.cursorJson => 'Bearer \${env:$variable}',
      AgentMcpConfigKind.geminiJson => 'Bearer \$$variable',
      AgentMcpConfigKind.kiroJson ||
      AgentMcpConfigKind.mcpServersJson => 'Bearer \${$variable}',
      AgentMcpConfigKind.codexToml => throw StateError(
        'Codex MCP configuration is not JSON.',
      ),
    };
  }
  return switch (config.transport) {
    McpTransport.stdio => <String, Object?>{
      if (kind == AgentMcpConfigKind.claudeJson) 'type': 'stdio',
      'command': config.command,
      if (config.arguments.isNotEmpty) 'args': config.arguments,
      if (config.environment.isNotEmpty) 'env': config.environment,
      if (kind == AgentMcpConfigKind.claudeJson) 'alwaysLoad': true,
    },
    McpTransport.streamableHttp => <String, Object?>{
      if (kind == AgentMcpConfigKind.claudeJson) 'type': 'http',
      if (kind == AgentMcpConfigKind.geminiJson)
        'httpUrl': config.url
      else
        'url': config.url,
      if (headers.isNotEmpty) 'headers': headers,
      if (kind == AgentMcpConfigKind.claudeJson) 'alwaysLoad': true,
    },
    McpTransport.raw => throw const FormatException(
      'Enabled MCP resources must use STDIO or HTTP configuration.',
    ),
  };
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await destination.create(recursive: true);
  await for (final FileSystemEntity entity in source.list()) {
    final String name = path.basename(entity.path);
    if (name == '.dingdong-managed') {
      continue;
    }
    final String target = path.join(destination.path, name);
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(target));
    } else if (entity is File) {
      await entity.copy(target);
    } else if (entity is Link) {
      throw const FormatException(
        'Skill packages with symbolic links are not supported.',
      );
    }
  }
}

String _skillName(Resource resource) {
  try {
    return SkillConfiguration.parseOnline(resource.content).name;
  } on Object {
    return normalizeSkillName(resource.title);
  }
}

AppIssue _issue({
  required Resource resource,
  required AppIssueKind kind,
  required String title,
  required String detail,
  AppIssueSeverity severity = AppIssueSeverity.error,
  String? clientName,
  String? targetPath,
}) => AppIssue(
  id: _issueId(kind, resource.id, targetPath),
  source: agentResourceSyncIssueSource,
  kind: kind,
  severity: severity,
  title: title,
  detail: detail,
  resourceId: resource.id,
  resourceTitle: resource.title,
  clientName: clientName,
  targetPath: targetPath,
);

String _issueId(AppIssueKind kind, String? resourceId, String? targetPath) =>
    '${kind.name}:${resourceId ?? '-'}:${targetPath ?? '-'}';

String _clientNameFromPath(String value) {
  final String normalized = value.replaceAll(r'\', '/').toLowerCase();
  if (normalized.contains('/.agents/') || normalized.endsWith('/.agents')) {
    return 'Codex';
  }
  if (normalized.contains('/.claude/') || normalized.endsWith('/.claude')) {
    return 'Claude Code';
  }
  if (normalized.contains('/.cursor/') || normalized.endsWith('/.cursor')) {
    return 'Cursor';
  }
  if (normalized.contains('/.gemini/') || normalized.endsWith('/.gemini')) {
    return 'Gemini CLI';
  }
  if (normalized.contains('/.kiro/') || normalized.endsWith('/.kiro')) {
    return 'Kiro';
  }
  return 'Agent';
}

const String _managedPromptsBegin = '<!-- BEGIN DINGDONG MANAGED PROMPTS -->';
const String _managedPromptsEnd = '<!-- END DINGDONG MANAGED PROMPTS -->';
const String _managedProjectSkillRootsStateKey = r'$dingdongProjectSkillRoots';
const String _managedGlobalSkillRootsStateKey = r'$dingdongGlobalSkillRoots';
const String _managedPromptTargetsStateKey = r'$dingdongPromptTargets';
const String _managedMcpTargetKindsStateKey = r'$dingdongMcpTargetKinds';

bool _isManagedStateKey(String value) => const <String>{
  _managedProjectSkillRootsStateKey,
  _managedGlobalSkillRootsStateKey,
  _managedPromptTargetsStateKey,
  _managedMcpTargetKindsStateKey,
}.contains(value);

void _normalizeManagedTargetPaths(Map<String, Set<String>> managed) {
  for (final MapEntry<String, Set<String>> entry in managed.entries.toList(
    growable: false,
  )) {
    if (_isManagedStateKey(entry.key)) {
      continue;
    }
    final String normalized = path.normalize(entry.key);
    if (normalized == entry.key) {
      continue;
    }
    managed.putIfAbsent(normalized, () => <String>{}).addAll(entry.value);
    managed.remove(entry.key);
  }
}

Set<String> _encodeManagedMcpTargetKinds(Map<String, AgentMcpTarget> targets) =>
    targets.entries
        .map(
          (MapEntry<String, AgentMcpTarget> entry) =>
              jsonEncode(<String, String>{
                'path': entry.key,
                'kind': entry.value.kind.configValue,
              }),
        )
        .toSet();

Map<String, AgentMcpConfigKind> _decodeManagedMcpTargetKinds(
  Set<String> encoded,
) {
  try {
    return <String, AgentMcpConfigKind>{
      for (final String value in encoded)
        if (jsonDecode(value) case final Map<String, Object?> item)
          path.normalize(item['path']! as String): AgentMcpConfigKind.parse(
            item['kind'],
            'managed MCP kind',
          ),
    };
  } on Object {
    throw const FormatException('DingDong Agent sync state is invalid.');
  }
}

AgentMcpConfigKind _inferMcpKind(File file) =>
    path.extension(file.path).toLowerCase() == '.toml'
    ? AgentMcpConfigKind.codexToml
    : AgentMcpConfigKind.mcpServersJson;

final RegExp _managedPromptsPattern = RegExp(
  '${RegExp.escape(_managedPromptsBegin)}.*?${RegExp.escape(_managedPromptsEnd)}\\s*',
  dotAll: true,
);

final RegExp _managedMcpBlockPattern = RegExp(
  r'^# BEGIN DINGDONG MCP .*?^# END DINGDONG MCP\s*\n?',
  multiLine: true,
  dotAll: true,
);

String _removeCodexMcpTables(String contents, Set<String> serverNames) {
  if (contents.isEmpty || serverNames.isEmpty) {
    return contents;
  }
  final Set<String> targetTables = serverNames
      .map((String name) => 'mcp_servers.$name')
      .toSet();
  final List<String> kept = <String>[];
  String? removingTable;
  for (final String line in contents.split('\n')) {
    final String? table = _tomlTablePath(line);
    if (table != null) {
      if (targetTables.contains(table)) {
        removingTable = table;
        continue;
      }
      final String? activeRemoval = removingTable;
      if (activeRemoval != null) {
        if (table.startsWith('$activeRemoval.')) {
          continue;
        }
        removingTable = null;
      }
    }
    if (removingTable == null) {
      kept.add(line);
    }
  }
  return kept.join('\n');
}

String? _tomlTablePath(String line) {
  final String trimmed = line.trim();
  if (!trimmed.startsWith('[')) {
    return null;
  }
  final bool arrayTable = trimmed.startsWith('[[');
  final String closing = arrayTable ? ']]' : ']';
  final int openingLength = arrayTable ? 2 : 1;
  final int end = trimmed.indexOf(closing, openingLength);
  if (end < openingLength) {
    return null;
  }
  final String trailing = trimmed.substring(end + closing.length).trimLeft();
  if (trailing.isNotEmpty && !trailing.startsWith('#')) {
    return null;
  }
  final String table = trimmed.substring(openingLength, end).trim();
  return table.isEmpty ? null : table;
}

void _rejectDuplicateTomlTables(String contents, String targetPath) {
  final Set<String> seen = <String>{};
  final Set<String> duplicates = <String>{};
  for (final String line in contents.split('\n')) {
    if (line.trimLeft().startsWith('[[')) {
      continue;
    }
    final String? table = _tomlTablePath(line);
    if (table != null && !seen.add(table)) {
      duplicates.add(table);
    }
  }
  if (duplicates.isEmpty) {
    return;
  }
  final List<String> sorted = duplicates.toList()..sort();
  throw FormatException(
    'Codex configuration contains duplicate TOML tables: '
    '${sorted.join(', ')}. $targetPath was not changed.',
  );
}
