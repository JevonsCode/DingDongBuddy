import 'dart:io';

import 'package:agent_installer/agent_installer.dart';
import 'package:dingdong/features/agent_adapters/data/agent_adapter_repository.dart';
import 'package:dingdong/features/agent_adapters/domain/agent_adapter.dart';

/// Shares Agent locations with installation while retaining explicit user YAML
/// overrides and DingDong's project Skill delivery policy.
Future<List<AgentAdapter>> loadInstallerResourceAdapters(
  AgentAdapterRepository repository, {
  Map<String, String>? environment,
  String? extensionsDirectory,
  String? operatingSystem,
}) async {
  final catalog = await repository.load();
  final legacy = catalog.requireEffectiveAdapters();
  final env = InstallEnvironment(
    environment: environment,
    operatingSystem: operatingSystem,
  );
  final targets = InstallTargets.load(
    extensionsDirectory:
        extensionsDirectory ?? defaultExtensionsDirectory(environment: env.env),
  );
  final scans = {for (final scan in scanTargets(targets, env)) scan.id: scan};
  final overrides = {
    for (final entry in catalog.entries)
      if (entry.origin != AgentAdapterOrigin.builtIn) entry.id,
  };
  final result = <AgentAdapter>[];

  AgentAdapter convert(InstallTarget target, AgentAdapter? previous) {
    final scan = scans[target.id]!;
    if (scan.manual != null) {
      throw FormatException('${target.name}: ${scan.manual}');
    }
    final mcp = target.mcp;
    final files =
        mcp?.files.map((file) => target.resolve(env, file)).toList() ??
        <String>[];
    final existing = files.where((file) => File(file).existsSync()).toList();
    if (existing.length > 1) {
      throw FormatException(
        '${target.name}: multiple MCP files; choose one before synchronizing.',
      );
    }
    final format = switch (mcp?.format) {
      'codex-toml' => AgentMcpConfigKind.codexToml,
      'claude-json' => AgentMcpConfigKind.claudeJson,
      'kiro-json' => AgentMcpConfigKind.kiroJson,
      'opencode-json' => AgentMcpConfigKind.openCodeJson,
      'mcp-servers-json' =>
        previous?.mcpKind ?? AgentMcpConfigKind.mcpServersJson,
      _ => null,
    };
    String? prompt = target.instructionsFile;
    final override = target.instructionsOverrideFile;
    if (override != null) {
      final file = File(target.resolve(env, override));
      if (file.existsSync() && file.readAsStringSync().trim().isNotEmpty) {
        prompt = override;
      }
    }
    return AgentAdapter(
      id: previous?.id ?? target.id,
      displayName: target.name,
      detectDirectory: scan.detected
          ? env.home
          : (previous?.detectDirectory ?? env.home),
      mcpFilePath: existing.firstOrNull ?? files.firstOrNull,
      mcpKind: format,
      promptFilePath: prompt == null ? null : target.resolve(env, prompt),
      globalSkillPath: target.skillsDir == null
          ? null
          : target.resolve(env, target.skillsDir!),
      projectSkillPath: previous?.projectSkillPath,
      includeBridgeRoutingInstructions:
          previous?.includeBridgeRoutingInstructions ?? true,
    );
  }

  String installerId(String id) => id == 'gemini' ? 'gemini-cli' : id;
  for (final adapter in legacy) {
    final target = targets.targets[installerId(adapter.id)];
    result.add(
      target == null ||
              overrides.contains(adapter.id) ||
              scans[installerId(adapter.id)]?.platformSupported == false
          ? adapter
          : convert(target, adapter),
    );
  }
  final knownIds = legacy.map((adapter) => installerId(adapter.id)).toSet();
  for (final target in targets.targets.values) {
    final scan = scans[target.id]!;
    if (!knownIds.contains(target.id) &&
        scan.detected &&
        scan.platformSupported) {
      result.add(convert(target, null));
    }
  }
  return result;
}
