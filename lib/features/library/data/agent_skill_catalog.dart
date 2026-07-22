import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/library/domain/resource_configuration.dart';
import 'package:path/path.dart' as path;

/// One Skill supplied by an Agent plugin rather than a native Skill directory.
final class ExternalAgentSkill {
  const ExternalAgentSkill({
    required this.name,
    required this.clientName,
    required this.providerName,
    required this.targetPath,
  });

  final String name;
  final String clientName;
  final String providerName;
  final String targetPath;
}

/// Read-only discovery boundary for Skills that an Agent loads indirectly.
abstract interface class AgentSkillCatalog {
  Future<List<ExternalAgentSkill>> load();
}

/// Reads Skills exposed by enabled Claude Code plugins.
///
/// Claude keeps plugin enablement and installation paths in separate JSON
/// files. Only an explicitly enabled, currently installed plugin is inspected.
final class ClaudeCodePluginSkillCatalog implements AgentSkillCatalog {
  const ClaudeCodePluginSkillCatalog({
    required this.settingsFile,
    required this.installedPluginsFile,
  });

  final File settingsFile;
  final File installedPluginsFile;

  @override
  Future<List<ExternalAgentSkill>> load() async {
    if (!await settingsFile.exists() || !await installedPluginsFile.exists()) {
      return const <ExternalAgentSkill>[];
    }
    try {
      final Map<Object?, Object?> settings = _jsonObject(
        await settingsFile.readAsString(),
      );
      final Object? enabledValue = settings['enabledPlugins'];
      if (enabledValue is! Map) {
        return const <ExternalAgentSkill>[];
      }
      final Set<String> enabledPlugins = enabledValue.entries
          .where((MapEntry<Object?, Object?> entry) => entry.value == true)
          .map((MapEntry<Object?, Object?> entry) => entry.key)
          .whereType<String>()
          .toSet();
      if (enabledPlugins.isEmpty) {
        return const <ExternalAgentSkill>[];
      }

      final Map<Object?, Object?> registry = _jsonObject(
        await installedPluginsFile.readAsString(),
      );
      final Object? pluginsValue = registry['plugins'];
      if (pluginsValue is! Map) {
        return const <ExternalAgentSkill>[];
      }

      final Map<String, ExternalAgentSkill> discovered =
          <String, ExternalAgentSkill>{};
      final List<String> pluginIds = enabledPlugins.toList()..sort();
      for (final String pluginId in pluginIds) {
        final Object? installations = pluginsValue[pluginId];
        if (installations is! List) {
          continue;
        }
        final String providerName = pluginId.split('@').first;
        for (final Object? installationValue in installations) {
          if (installationValue is! Map) {
            continue;
          }
          final Object? installPathValue = installationValue['installPath'];
          if (installPathValue is! String || installPathValue.trim().isEmpty) {
            continue;
          }
          final Directory skillRoot = Directory(
            path.join(installPathValue, 'skills'),
          );
          if (!await skillRoot.exists()) {
            continue;
          }
          await for (final FileSystemEntity entity in skillRoot.list(
            followLinks: false,
          )) {
            if (entity is! Directory) {
              continue;
            }
            final File skillFile = File(path.join(entity.path, 'SKILL.md'));
            if (!await skillFile.exists()) {
              continue;
            }
            try {
              final SkillConfiguration skill = SkillConfiguration.parseOnline(
                await skillFile.readAsString(),
              );
              final ExternalAgentSkill external = ExternalAgentSkill(
                name: skill.name,
                clientName: 'Claude Code',
                providerName: providerName,
                targetPath: skillFile.path,
              );
              discovered['$pluginId\u0000${skill.name}'] = external;
            } on Object {
              // A malformed third-party Skill must not break DingDong sync.
            }
          }
        }
      }
      final List<ExternalAgentSkill> result = discovered.values.toList();
      result.sort((ExternalAgentSkill left, ExternalAgentSkill right) {
        final int name = left.name.compareTo(right.name);
        if (name != 0) {
          return name;
        }
        return left.providerName.compareTo(right.providerName);
      });
      return List<ExternalAgentSkill>.unmodifiable(result);
    } on Object {
      // Plugin discovery is advisory. Native resource synchronization remains
      // available if Claude changes or temporarily corrupts its plugin files.
      return const <ExternalAgentSkill>[];
    }
  }
}

Map<Object?, Object?> _jsonObject(String source) {
  final Object? decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw const FormatException('Expected a JSON object.');
  }
  return decoded;
}
