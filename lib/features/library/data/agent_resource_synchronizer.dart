import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/built_in_resources.dart';
import 'package:dingdong/features/library/domain/resource_configuration.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:path/path.dart' as path;

enum AgentMcpConfigKind { codexToml, claudeJson, cursorJson, geminiJson }

final class AgentPromptTarget {
  const AgentPromptTarget(this.file);

  final File file;
}

final class AgentMcpTarget {
  const AgentMcpTarget(this.file, this.kind);

  final File file;
  final AgentMcpConfigKind kind;
}

/// Makes DingDong's enabled state concrete in supported Agent clients.
/// Skills are mirrored as complete packages; MCP resources become real client
/// configuration entries. Only DingDong-marked files and entries are removed.
final class AgentResourceSynchronizer {
  AgentResourceSynchronizer({
    required this.packageRoot,
    required this.skillRoots,
    required this.mcpTargets,
    this.promptTargets = const <AgentPromptTarget>[],
    File? managedStateFile,
    SkillPackageInstaller? skillPackageInstaller,
  }) : managedStateFile =
           managedStateFile ??
           File(path.join(packageRoot.parent.path, 'agent-sync-state.json')),
       skillPackageInstaller =
           skillPackageInstaller ?? GitHubSkillPackageInstaller(packageRoot);

  factory AgentResourceSynchronizer.currentUser(Directory packageRoot) {
    final String home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;
    final String separator = Platform.pathSeparator;
    bool present(String name) => Directory('$home$separator$name').existsSync();
    final List<Directory> skills = <Directory>[
      if (present('.codex'))
        Directory('$home$separator.agents${separator}skills'),
      if (present('.claude'))
        Directory('$home$separator.claude${separator}skills'),
      if (present('.cursor'))
        Directory('$home$separator.cursor${separator}skills'),
      if (present('.gemini'))
        Directory('$home$separator.gemini${separator}skills'),
    ];
    final List<AgentPromptTarget> prompts = <AgentPromptTarget>[
      if (present('.codex'))
        AgentPromptTarget(File('$home$separator.codex${separator}AGENTS.md')),
    ];
    final List<AgentMcpTarget> mcps = <AgentMcpTarget>[
      if (present('.codex'))
        AgentMcpTarget(
          File('$home$separator.codex${separator}config.toml'),
          AgentMcpConfigKind.codexToml,
        ),
      if (present('.claude'))
        AgentMcpTarget(
          File('$home$separator.claude.json'),
          AgentMcpConfigKind.claudeJson,
        ),
      if (present('.cursor'))
        AgentMcpTarget(
          File('$home$separator.cursor${separator}mcp.json'),
          AgentMcpConfigKind.cursorJson,
        ),
      if (present('.gemini'))
        AgentMcpTarget(
          File('$home$separator.gemini${separator}settings.json'),
          AgentMcpConfigKind.geminiJson,
        ),
    ];
    return AgentResourceSynchronizer(
      packageRoot: packageRoot,
      skillRoots: skills,
      promptTargets: prompts,
      mcpTargets: mcps,
    );
  }

  final Directory packageRoot;
  final List<Directory> skillRoots;
  final List<AgentPromptTarget> promptTargets;
  final List<AgentMcpTarget> mcpTargets;
  final File managedStateFile;
  final SkillPackageInstaller skillPackageInstaller;

  Future<void> sync(List<Resource> resources) async {
    final List<Resource> prompts = resources
        .where(
          (Resource item) => item.enabled && item.type == ResourceType.prompt,
        )
        .toList(growable: false);
    final List<Resource> skills = resources
        .where(
          (Resource item) => item.enabled && item.type == ResourceType.skill,
        )
        .toList(growable: false);
    final List<Resource> mcps = resources
        .where((Resource item) => item.enabled && item.type == ResourceType.mcp)
        .toList(growable: false);
    final Map<String, Set<String>> managed = await _readManagedMcpState();
    await _preflight(skills, mcps);
    for (final AgentPromptTarget target in promptTargets) {
      await _syncPrompts(target.file, prompts);
    }
    for (final Directory root in skillRoots) {
      await _syncSkills(root, skills);
    }
    for (final AgentMcpTarget target in mcpTargets) {
      final Set<String> previousNames = managed[target.file.path] ?? <String>{};
      if (mcps.isEmpty && previousNames.isEmpty) {
        continue;
      }
      await switch (target.kind) {
        AgentMcpConfigKind.codexToml => _syncCodex(target.file, mcps),
        AgentMcpConfigKind.claudeJson ||
        AgentMcpConfigKind.cursorJson ||
        AgentMcpConfigKind.geminiJson => _syncJson(
          target.file,
          target.kind,
          mcps,
          previousNames,
        ),
      };
      managed[target.file.path] = mcps.map(_serverName).toSet();
      await _writeManagedMcpState(managed);
    }
  }

  Future<void> _syncPrompts(File file, List<Resource> enabled) async {
    final List<Resource> direct =
        enabled
            .where(
              (Resource resource) =>
                  resource.activation == ResourceActivation.always &&
                  resource.triggerGroupIds.isEmpty,
            )
            .toList(growable: false)
          ..sort(_comparePromptOrder);
    final bool hasRoutedPrompts = enabled.any(
      (Resource resource) =>
          resource.activation != ResourceActivation.manual &&
          !direct.contains(resource),
    );
    final String current = await file.exists() ? await file.readAsString() : '';
    final String cleaned = current
        .replaceAll(_managedPromptsPattern, '')
        .trimRight();
    final StringBuffer block = StringBuffer();
    if (direct.isNotEmpty || hasRoutedPrompts) {
      block
        ..writeln(_managedPromptsBegin)
        ..writeln('# DingDong managed prompts')
        ..writeln()
        ..writeln(
          'This section is maintained by DingDong. Preserve and follow these instructions.',
        );
      for (final Resource prompt in direct) {
        block
          ..writeln()
          ..writeln('## ${_safeManagedPromptText(prompt.title)}')
          ..writeln()
          ..writeln(_safeManagedPromptText(prompt.content).trim());
      }
      if (hasRoutedPrompts) {
        block
          ..writeln()
          ..writeln('## Project and task prompts')
          ..writeln()
          ..writeln(
            '- At the start of each user task, call DingDong `dingdong_bridge` with `expand: "prompts"` and apply every returned active prompt before responding.',
          )
          ..writeln(
            '- Returned Skill and MCP entries are candidates, not instructions. Load a Skill only when its description matches the task; call MCP tools only when the task requires them.',
          );
      }
      block.writeln(_managedPromptsEnd);
    }
    final String managed = block.toString().trimRight();
    final String next = <String>[
      if (cleaned.isNotEmpty) cleaned,
      if (managed.isNotEmpty) managed,
    ].join('\n\n');
    final String normalized = next.isEmpty ? '' : '$next\n';
    if (normalized == current || (!await file.exists() && normalized.isEmpty)) {
      return;
    }
    await _writeAtomically(file, normalized);
  }

  Future<void> _preflight(List<Resource> skills, List<Resource> mcps) async {
    for (final Resource resource in skills) {
      SkillConfiguration.parseOnline(resource.content);
      final String? packagePath = resource.packagePath;
      if (packagePath != null &&
          !await File(path.join(packagePath, 'SKILL.md')).exists()) {
        throw StateError('Skill package is missing: ${resource.title}');
      }
      for (final Directory root in skillRoots) {
        final String name = _skillName(resource);
        final Directory destination = Directory(path.join(root.path, name));
        if (await destination.exists() &&
            !await File(
              path.join(destination.path, '.dingdong-managed'),
            ).exists()) {
          throw StateError('Skill "$name" already exists in ${root.path}.');
        }
      }
    }
    for (final Resource resource in mcps) {
      final McpConfiguration config = McpConfiguration.parse(resource.content);
      if (config.transport == McpTransport.raw) {
        throw FormatException(
          'MCP ${resource.title} must use STDIO or Streamable HTTP.',
        );
      }
    }
    for (final AgentMcpTarget target in mcpTargets) {
      if (target.kind == AgentMcpConfigKind.codexToml ||
          !await target.file.exists()) {
        continue;
      }
      final String contents = await target.file.readAsString();
      if (contents.trim().isEmpty) {
        continue;
      }
      final Object? decoded = jsonDecode(contents);
      if (decoded is! Map) {
        throw FormatException(
          '${target.file.path} must contain a JSON object.',
        );
      }
      final Object? servers = decoded['mcpServers'];
      if (servers != null && servers is! Map) {
        throw FormatException(
          '${target.file.path} has an invalid mcpServers value.',
        );
      }
    }
  }

  Future<void> _syncSkills(Directory targetRoot, List<Resource> enabled) async {
    await targetRoot.create(recursive: true);
    final Set<String> activeIds = enabled
        .map((Resource item) => item.id)
        .toSet();
    await for (final FileSystemEntity entity in targetRoot.list()) {
      if (entity is! Directory) {
        continue;
      }
      final File marker = File(path.join(entity.path, '.dingdong-managed'));
      if (await marker.exists() &&
          !activeIds.contains((await marker.readAsString()).trim())) {
        await entity.delete(recursive: true);
      }
    }
    for (final Resource resource in enabled) {
      final Directory source = await _skillSource(resource);
      final String name = _skillName(resource);
      final Directory destination = Directory(path.join(targetRoot.path, name));
      final File marker = File(
        path.join(destination.path, '.dingdong-managed'),
      );
      if (await destination.exists() && !await marker.exists()) {
        throw StateError(
          'Skill "$name" already exists in ${targetRoot.path} and is not managed by DingDong.',
        );
      }
      final Directory staging = Directory('${destination.path}.dingdong-tmp');
      final Directory backup = Directory('${destination.path}.dingdong-bak');
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
      if (await backup.exists()) {
        await backup.delete(recursive: true);
      }
      await _copyDirectory(source, staging);
      await File(
        path.join(staging.path, '.dingdong-managed'),
      ).writeAsString(resource.id, flush: true);
      final bool hadDestination = await destination.exists();
      try {
        if (hadDestination) {
          await destination.rename(backup.path);
        }
        await staging.rename(destination.path);
        if (await backup.exists()) {
          await backup.delete(recursive: true);
        }
      } on Object {
        if (await staging.exists()) {
          await staging.delete(recursive: true);
        }
        if (hadDestination &&
            await backup.exists() &&
            !await destination.exists()) {
          await backup.rename(destination.path);
        }
        rethrow;
      }
    }
  }

  Future<Directory> _skillSource(Resource resource) async {
    final String? storedPath = resource.packagePath;
    if (storedPath != null) {
      final Directory stored = Directory(storedPath);
      if (await File(path.join(stored.path, 'SKILL.md')).exists()) {
        final String managedRoot = path.canonicalize(packageRoot.path);
        final String sourcePath = path.canonicalize(stored.path);
        if (path.isWithin(managedRoot, sourcePath)) {
          return stored;
        }
        final Directory imported = Directory(
          path.join(packageRoot.path, resource.id),
        );
        final Directory staging = Directory('${imported.path}.dingdong-tmp');
        if (await staging.exists()) {
          await staging.delete(recursive: true);
        }
        await _copyDirectory(stored, staging);
        if (await imported.exists()) {
          await imported.delete(recursive: true);
        }
        await staging.rename(imported.path);
        return imported;
      }
    }
    final String? updateUrl = resource.updateUrl;
    if (updateUrl != null) {
      final Directory installed = Directory(
        path.join(packageRoot.path, _skillName(resource)),
      );
      if (resource.source == builtInDingDongConfigureSkillSource) {
        await installed.create(recursive: true);
        await File(
          path.join(installed.path, 'SKILL.md'),
        ).writeAsString(resource.content, flush: true);
        return installed;
      }
      if (await File(path.join(installed.path, 'SKILL.md')).exists()) {
        return installed;
      }
      final SkillPackageInstallResult result = await skillPackageInstaller
          .install(Uri.parse(updateUrl));
      return Directory(result.directoryPath);
    }
    final Directory generated = Directory(
      path.join(packageRoot.path, resource.id),
    );
    await generated.create(recursive: true);
    await File(
      path.join(generated.path, 'SKILL.md'),
    ).writeAsString(resource.content, flush: true);
    return generated;
  }

  Future<void> _syncJson(
    File file,
    AgentMcpConfigKind kind,
    List<Resource> resources,
    Set<String> previousNames,
  ) async {
    Map<String, Object?> root = <String, Object?>{};
    if (await file.exists() && (await file.readAsString()).trim().isNotEmpty) {
      root = Map<String, Object?>.from(
        jsonDecode(await file.readAsString()) as Map,
      );
    }
    final Map<String, Object?> servers = Map<String, Object?>.from(
      (root['mcpServers'] as Map?) ?? const <String, Object?>{},
    )..removeWhere((String key, Object? _) => previousNames.contains(key));
    for (final Resource resource in resources) {
      servers[_serverName(resource)] = _jsonMcp(
        McpConfiguration.parse(resource.content),
        kind,
      );
    }
    await _writeAtomically(
      file,
      const JsonEncoder.withIndent(
        '  ',
      ).convert(<String, Object?>{...root, 'mcpServers': servers}),
    );
  }

  Future<void> _syncCodex(File file, List<Resource> resources) async {
    final String current = await file.exists() ? await file.readAsString() : '';
    final String cleaned = current
        .replaceAll(
          RegExp(
            r'^# BEGIN DINGDONG MCP .*?^# END DINGDONG MCP\s*\n?',
            multiLine: true,
            dotAll: true,
          ),
          '',
        )
        .trimRight();
    final StringBuffer output = StringBuffer(cleaned);
    for (final Resource resource in resources) {
      final McpConfiguration config = McpConfiguration.parse(resource.content);
      output
        ..writeln(output.isEmpty ? '' : '\n')
        ..writeln('# BEGIN DINGDONG MCP ${resource.id}')
        ..writeln('[mcp_servers.${_serverName(resource)}]');
      if (config.transport == McpTransport.stdio) {
        output.writeln('command = "${_toml(config.command)}"');
        if (config.arguments.isNotEmpty) {
          output.writeln(
            'args = [${config.arguments.map((String value) => '"${_toml(value)}"').join(', ')}]',
          );
        }
        if (config.environment.isNotEmpty) {
          output.writeln(
            'env = { ${config.environment.entries.map((MapEntry<String, String> item) => '${item.key} = "${_toml(item.value)}"').join(', ')} }',
          );
        }
      } else if (config.transport == McpTransport.streamableHttp) {
        output.writeln('url = "${_toml(config.url)}"');
        if (config.tokenEnvironmentVariable.isNotEmpty) {
          output.writeln(
            'bearer_token_env_var = "${_toml(config.tokenEnvironmentVariable)}"',
          );
        }
        if (config.headers.isNotEmpty) {
          output.writeln(
            'http_headers = { ${config.headers.entries.map((MapEntry<String, String> item) => '"${_toml(item.key)}" = "${_toml(item.value)}"').join(', ')} }',
          );
        }
      } else {
        throw FormatException('MCP ${resource.title} must use STDIO or HTTP.');
      }
      output
        ..writeln('enabled = true')
        ..writeln('# END DINGDONG MCP');
    }
    await _writeAtomically(file, '${output.toString().trimRight()}\n');
  }

  Future<Map<String, Set<String>>> _readManagedMcpState() async {
    if (!await managedStateFile.exists()) {
      return <String, Set<String>>{};
    }
    try {
      final Map<String, Object?> decoded = Map<String, Object?>.from(
        jsonDecode(await managedStateFile.readAsString()) as Map,
      );
      return <String, Set<String>>{
        for (final MapEntry<String, Object?> entry in decoded.entries)
          entry.key: (entry.value as List<Object?>? ?? const <Object?>[])
              .map((Object? value) => value as String)
              .toSet(),
      };
    } on Object {
      throw const FormatException('DingDong Agent sync state is invalid.');
    }
  }

  Future<void> _writeManagedMcpState(Map<String, Set<String>> managed) async {
    await _writeAtomically(
      managedStateFile,
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        for (final MapEntry<String, Set<String>> entry in managed.entries)
          entry.key: entry.value.toList(growable: false)..sort(),
      }),
    );
  }
}

/// Adds transactional synchronization without changing callers of ResourceStore.
final class SynchronizedResourceStore implements ResourceStore {
  SynchronizedResourceStore(this._delegate, this._synchronizer);

  final ResourceStore _delegate;
  final AgentResourceSynchronizer _synchronizer;

  @override
  Future<List<Resource>> load() => _delegate.load();

  @override
  Future<void> save(List<Resource> resources) async {
    final List<Resource> previous = await _delegate.load();
    await _delegate.save(resources);
    try {
      await _synchronizer.sync(resources);
      await _cleanupRemovedPackages(previous, resources);
    } on Object catch (error, stackTrace) {
      await _delegate.save(previous);
      try {
        await _synchronizer.sync(previous);
      } on Object {
        // Preserve the original save failure; the resource file is rolled back.
      }
      await _cleanupRemovedPackages(resources, previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _cleanupRemovedPackages(
    List<Resource> previous,
    List<Resource> current,
  ) async {
    final Set<String> active = current
        .map((Resource resource) => resource.packagePath)
        .whereType<String>()
        .map(path.canonicalize)
        .toSet();
    final String managedRoot = path.canonicalize(
      _synchronizer.packageRoot.path,
    );
    for (final String packagePath
        in previous
            .map((Resource resource) => resource.packagePath)
            .whereType<String>()) {
      final String canonical = path.canonicalize(packagePath);
      if (active.contains(canonical) ||
          !path.isWithin(managedRoot, canonical)) {
        continue;
      }
      final Directory directory = Directory(canonical);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
    final Set<String> currentIds = current
        .map((Resource resource) => resource.id)
        .toSet();
    final Set<String> activeSkillNames = current
        .where((Resource resource) => resource.type == ResourceType.skill)
        .map(_skillName)
        .toSet();
    for (final Resource resource in previous) {
      if (currentIds.contains(resource.id)) {
        continue;
      }
      final Directory generated = Directory(
        path.join(_synchronizer.packageRoot.path, resource.id),
      );
      if (await generated.exists()) {
        await generated.delete(recursive: true);
      }
      if (resource.type == ResourceType.skill &&
          resource.updateUrl != null &&
          resource.packagePath == null &&
          !activeSkillNames.contains(_skillName(resource))) {
        final Directory downloaded = Directory(
          path.join(_synchronizer.packageRoot.path, _skillName(resource)),
        );
        if (await downloaded.exists()) {
          await downloaded.delete(recursive: true);
        }
      }
    }
  }
}

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

String _serverName(Resource resource) {
  final String slug = normalizeSkillName(resource.title);
  final String suffix = resource.id
      .replaceAll(RegExp('[^A-Za-z0-9]'), '')
      .toLowerCase();
  final int suffixLength = suffix.length < 6 ? suffix.length : 6;
  return 'dingdong-$slug-${suffix.substring(0, suffixLength)}';
}

String _skillName(Resource resource) {
  try {
    return SkillConfiguration.parseOnline(resource.content).name;
  } on Object {
    return normalizeSkillName(resource.title);
  }
}

const String _managedPromptsBegin = '<!-- BEGIN DINGDONG MANAGED PROMPTS -->';
const String _managedPromptsEnd = '<!-- END DINGDONG MANAGED PROMPTS -->';

final RegExp _managedPromptsPattern = RegExp(
  '${RegExp.escape(_managedPromptsBegin)}.*?${RegExp.escape(_managedPromptsEnd)}\\s*',
  dotAll: true,
);

int _comparePromptOrder(Resource left, Resource right) {
  final int order = (left.sortOrder ?? 1 << 30).compareTo(
    right.sortOrder ?? 1 << 30,
  );
  if (order != 0) {
    return order;
  }
  final int title = left.title.compareTo(right.title);
  return title != 0 ? title : left.id.compareTo(right.id);
}

String _safeManagedPromptText(String value) => value
    .replaceAll(_managedPromptsBegin, '&lt;!-- BEGIN DINGDONG PROMPTS --&gt;')
    .replaceAll(_managedPromptsEnd, '&lt;!-- END DINGDONG PROMPTS --&gt;');

String _toml(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('\n', r'\n');

Future<void> _writeAtomically(File file, String content) async {
  await file.parent.create(recursive: true);
  final File temporary = File('${file.path}.dingdong-tmp');
  final File backup = File('${file.path}.dingdong-bak');
  await temporary.writeAsString(content, flush: true);
  final bool hadFile = await file.exists();
  try {
    if (hadFile) {
      if (await backup.exists()) {
        await backup.delete();
      }
      await file.rename(backup.path);
    }
    await temporary.rename(file.path);
    if (await backup.exists()) {
      await backup.delete();
    }
  } on Object {
    if (await temporary.exists()) {
      await temporary.delete();
    }
    if (hadFile && await backup.exists() && !await file.exists()) {
      await backup.rename(file.path);
    }
    rethrow;
  }
}
