import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

enum AgentMcpConfigKind {
  codexToml('codex-toml'),
  claudeJson('claude-json'),
  cursorJson('cursor-json'),
  geminiJson('gemini-json'),
  kiroJson('kiro-json'),
  mcpServersJson('mcpServers-json');

  const AgentMcpConfigKind(this.configValue);

  final String configValue;

  static AgentMcpConfigKind parse(Object? value, String field) {
    if (value is! String) {
      throw FormatException('$field must be a string.');
    }
    return values.firstWhere(
      (AgentMcpConfigKind kind) => kind.configValue == value,
      orElse: () => throw FormatException(
        '$field must be one of: '
        '${values.map((AgentMcpConfigKind kind) => kind.configValue).join(', ')}.',
      ),
    );
  }
}

/// Declarative, validated locations and capabilities for one Agent client.
final class AgentAdapter {
  const AgentAdapter({
    required this.id,
    required this.displayName,
    required this.detectDirectory,
    this.globalSkillPath,
    this.projectSkillPath,
    this.mcpFilePath,
    this.mcpKind,
    this.promptFilePath,
    this.includeBridgeRoutingInstructions = true,
  });

  factory AgentAdapter.parse(String document) {
    final Object? yaml;
    try {
      yaml = loadYaml(document);
    } on YamlException catch (error) {
      throw FormatException('Agent Adapter YAML is invalid: ${error.message}');
    }
    final Map<String, Object?> root = _object(yaml, r'$');
    _rejectUnknown(root, const <String>{
      'schemaVersion',
      'id',
      'displayName',
      'detect',
      'skills',
      'mcp',
      'prompt',
    }, r'$');
    if (root['schemaVersion'] != 1) {
      throw const FormatException(r'$.schemaVersion must be 1.');
    }
    final String id = _requiredString(root, 'id', r'$');
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(id) || id.length > 64) {
      throw const FormatException(
        r'$.id must be 1-64 lowercase letters, numbers, or single hyphens.',
      );
    }
    final String displayName = _requiredString(root, 'displayName', r'$');
    final Map<String, Object?> detect = _requiredObject(root, 'detect', r'$');
    _rejectUnknown(detect, const <String>{'directory'}, r'$.detect');
    final String detectDirectory = _requiredString(
      detect,
      'directory',
      r'$.detect',
    );
    _validateUserPath(detectDirectory, r'$.detect.directory');

    String? globalSkillPath;
    String? projectSkillPath;
    final Map<String, Object?>? skills = _optionalObject(root, 'skills', r'$');
    if (skills != null) {
      _rejectUnknown(skills, const <String>{'global', 'project'}, r'$.skills');
      globalSkillPath = _optionalString(skills, 'global', r'$.skills');
      projectSkillPath = _optionalString(skills, 'project', r'$.skills');
      if (globalSkillPath == null || projectSkillPath == null) {
        throw const FormatException(
          r'$.skills.global and $.skills.project must be provided together.',
        );
      }
      _validateUserPath(globalSkillPath, r'$.skills.global');
      _validateProjectPath(projectSkillPath, r'$.skills.project');
    }

    String? mcpFilePath;
    AgentMcpConfigKind? mcpKind;
    final Map<String, Object?>? mcp = _optionalObject(root, 'mcp', r'$');
    if (mcp != null) {
      _rejectUnknown(mcp, const <String>{'file', 'format'}, r'$.mcp');
      mcpFilePath = _requiredString(mcp, 'file', r'$.mcp');
      _validateUserPath(mcpFilePath, r'$.mcp.file');
      mcpKind = AgentMcpConfigKind.parse(mcp['format'], r'$.mcp.format');
    }

    String? promptFilePath;
    bool includeBridgeRoutingInstructions = true;
    final Map<String, Object?>? prompt = _optionalObject(root, 'prompt', r'$');
    if (prompt != null) {
      _rejectUnknown(prompt, const <String>{
        'file',
        'includeBridgeRoutingInstructions',
      }, r'$.prompt');
      promptFilePath = _requiredString(prompt, 'file', r'$.prompt');
      _validateUserPath(promptFilePath, r'$.prompt.file');
      final Object? include = prompt['includeBridgeRoutingInstructions'];
      if (include != null && include is! bool) {
        throw const FormatException(
          r'$.prompt.includeBridgeRoutingInstructions must be a boolean.',
        );
      }
      includeBridgeRoutingInstructions = include as bool? ?? true;
    }

    return AgentAdapter(
      id: id,
      displayName: displayName,
      detectDirectory: detectDirectory,
      globalSkillPath: globalSkillPath,
      projectSkillPath: projectSkillPath,
      mcpFilePath: mcpFilePath,
      mcpKind: mcpKind,
      promptFilePath: promptFilePath,
      includeBridgeRoutingInstructions: includeBridgeRoutingInstructions,
    );
  }

  static const int schemaVersion = 1;

  final String id;
  final String displayName;
  final String detectDirectory;
  final String? globalSkillPath;
  final String? projectSkillPath;
  final String? mcpFilePath;
  final AgentMcpConfigKind? mcpKind;
  final String? promptFilePath;
  final bool includeBridgeRoutingInstructions;

  void validateForHomeDirectory(String homeDirectory) {
    resolveUserPath(detectDirectory, homeDirectory);
    if (globalSkillPath != null) {
      resolveUserPath(globalSkillPath!, homeDirectory);
    }
    if (mcpFilePath != null) {
      resolveUserPath(mcpFilePath!, homeDirectory);
    }
    if (promptFilePath != null) {
      resolveUserPath(promptFilePath!, homeDirectory);
    }
  }

  bool isInstalled(String homeDirectory) =>
      Directory(resolveUserPath(detectDirectory, homeDirectory)).existsSync();

  String? resolvedGlobalSkillPath(String homeDirectory) =>
      globalSkillPath == null
      ? null
      : resolveUserPath(globalSkillPath!, homeDirectory);

  String? resolvedMcpFilePath(String homeDirectory) =>
      mcpFilePath == null ? null : resolveUserPath(mcpFilePath!, homeDirectory);

  String? resolvedPromptFilePath(String homeDirectory) => promptFilePath == null
      ? null
      : resolveUserPath(promptFilePath!, homeDirectory);

  String resolvedProjectSkillPath() =>
      path.joinAll(projectSkillPath!.split('/'));

  String toYaml() {
    final StringBuffer output = StringBuffer()
      ..writeln('schemaVersion: $schemaVersion')
      ..writeln('id: ${jsonEncode(id)}')
      ..writeln('displayName: ${jsonEncode(displayName)}')
      ..writeln()
      ..writeln('detect:')
      ..writeln('  directory: ${jsonEncode(detectDirectory)}');
    if (globalSkillPath != null) {
      output
        ..writeln()
        ..writeln('skills:')
        ..writeln('  global: ${jsonEncode(globalSkillPath)}')
        ..writeln('  project: ${jsonEncode(projectSkillPath)}');
    }
    if (mcpFilePath != null) {
      output
        ..writeln()
        ..writeln('mcp:')
        ..writeln('  file: ${jsonEncode(mcpFilePath)}')
        ..writeln('  format: ${jsonEncode(mcpKind!.configValue)}');
    }
    if (promptFilePath != null) {
      output
        ..writeln()
        ..writeln('prompt:')
        ..writeln('  file: ${jsonEncode(promptFilePath)}')
        ..writeln(
          '  includeBridgeRoutingInstructions: '
          '$includeBridgeRoutingInstructions',
        );
    }
    return output.toString();
  }

  static String resolveUserPath(String configured, String homeDirectory) {
    final String resolved = configured == '~'
        ? homeDirectory
        : configured.startsWith('~/')
        ? path.joinAll(<String>[
            homeDirectory,
            ...configured.substring(2).split('/'),
          ])
        : configured;
    final String normalized = path.normalize(resolved);
    final String home = path.normalize(path.absolute(homeDirectory));
    final String absolute = path.normalize(path.absolute(normalized));
    if (absolute != home && !path.isWithin(home, absolute)) {
      throw FormatException(
        'Agent Adapter user paths must stay inside $homeDirectory.',
      );
    }
    final String resolvedHome = _resolveExistingAncestors(home);
    final String resolvedAbsolute = _resolveExistingAncestors(absolute);
    if (resolvedAbsolute != resolvedHome &&
        !path.isWithin(resolvedHome, resolvedAbsolute)) {
      throw FormatException(
        'Agent Adapter user paths must stay inside $homeDirectory after '
        'resolving symbolic links.',
      );
    }
    return resolvedAbsolute;
  }

  static String _resolveExistingAncestors(String value) {
    var existing = value;
    final List<String> missingSegments = <String>[];
    while (FileSystemEntity.typeSync(existing, followLinks: false) ==
        FileSystemEntityType.notFound) {
      final String parent = path.dirname(existing);
      if (path.equals(parent, existing)) {
        return path.normalize(value);
      }
      missingSegments.insert(0, path.basename(existing));
      existing = parent;
    }
    try {
      final FileSystemEntityType resolvedType = FileSystemEntity.typeSync(
        existing,
        followLinks: true,
      );
      final String resolved = switch (resolvedType) {
        FileSystemEntityType.directory => Directory(
          existing,
        ).resolveSymbolicLinksSync(),
        FileSystemEntityType.file => File(existing).resolveSymbolicLinksSync(),
        FileSystemEntityType.link => Link(existing).resolveSymbolicLinksSync(),
        FileSystemEntityType.notFound => throw const FormatException(
          'Agent Adapter paths must not contain broken symbolic links.',
        ),
        FileSystemEntityType.unixDomainSock ||
        FileSystemEntityType.pipe => throw const FormatException(
          'Agent Adapter paths must resolve to files or directories.',
        ),
        _ => throw const FormatException(
          'Agent Adapter paths must resolve to files or directories.',
        ),
      };
      return path.normalize(
        path.joinAll(<String>[resolved, ...missingSegments]),
      );
    } on FileSystemException catch (error) {
      throw FormatException(
        'Agent Adapter path could not be resolved safely: ${error.message}.',
      );
    }
  }
}

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map) {
    throw FormatException('$field must be a YAML object.');
  }
  final Map<String, Object?> result = <String, Object?>{};
  for (final MapEntry<Object?, Object?> entry in value.entries) {
    final Object? key = entry.key;
    if (key is! String) {
      throw FormatException('$field contains a non-string key.');
    }
    result[key] = _plain(entry.value);
  }
  return result;
}

Object? _plain(Object? value) {
  if (value is Map) {
    return _object(value, r'$');
  }
  if (value is List) {
    return value.map(_plain).toList(growable: false);
  }
  return value;
}

Map<String, Object?> _requiredObject(
  Map<String, Object?> parent,
  String key,
  String field,
) {
  final Object? value = parent[key];
  if (value is! Map<String, Object?>) {
    throw FormatException('$field.$key must be an object.');
  }
  return value;
}

Map<String, Object?>? _optionalObject(
  Map<String, Object?> parent,
  String key,
  String field,
) {
  if (!parent.containsKey(key)) {
    return null;
  }
  return _requiredObject(parent, key, field);
}

String _requiredString(Map<String, Object?> parent, String key, String field) {
  final String? value = _optionalString(parent, key, field);
  if (value == null) {
    throw FormatException('$field.$key must be a non-empty string.');
  }
  return value;
}

String? _optionalString(Map<String, Object?> parent, String key, String field) {
  if (!parent.containsKey(key)) {
    return null;
  }
  final Object? value = parent[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field.$key must be a non-empty string.');
  }
  return value.trim();
}

void _rejectUnknown(
  Map<String, Object?> value,
  Set<String> allowed,
  String field,
) {
  final List<String> unknown =
      value.keys.where((String key) => !allowed.contains(key)).toList()..sort();
  if (unknown.isNotEmpty) {
    throw FormatException(
      '$field contains unsupported fields: ${unknown.join(', ')}.',
    );
  }
}

void _validateUserPath(String value, String field) {
  if (value != '~' && !value.startsWith('~/') && !path.isAbsolute(value)) {
    throw FormatException('$field must use ~/ or an absolute path.');
  }
  if (value.contains('\u0000') ||
      value.contains('\n') ||
      value.contains('\r')) {
    throw FormatException('$field contains unsafe characters.');
  }
}

void _validateProjectPath(String value, String field) {
  final String normalized = path.posix.normalize(value);
  if (path.posix.isAbsolute(value) ||
      normalized == '..' ||
      normalized.startsWith('../') ||
      normalized == '.' ||
      value.contains(r'\') ||
      value.contains('\u0000') ||
      value.contains('\n') ||
      value.contains('\r')) {
    throw FormatException('$field must be a safe project-relative directory.');
  }
}
