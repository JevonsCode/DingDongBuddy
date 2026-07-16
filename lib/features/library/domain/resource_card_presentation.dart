import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/domain/resource_configuration.dart';

/// Type-aware text and metadata used by compact resource cards and lists.
final class ResourceCardPresentation {
  const ResourceCardPresentation({
    required this.title,
    required this.summary,
    required this.variant,
  });

  factory ResourceCardPresentation.fromResource(Resource resource) {
    return switch (resource.type) {
      ResourceType.prompt => _prompt(resource),
      ResourceType.skill => _skill(resource),
      ResourceType.mcp => _mcp(resource),
      ResourceType.knowledge || ResourceType.clipboard => _plain(resource),
    };
  }

  final String title;
  final String summary;
  final ResourceCardVariant variant;

  String get variantLabel => switch (variant) {
    ResourceCardVariant.prompt => 'Prompt',
    ResourceCardVariant.skillLocal => 'Local',
    ResourceCardVariant.skillOnline => 'Online',
    ResourceCardVariant.mcpStdio => 'STDIO',
    ResourceCardVariant.mcpHttp => 'HTTP',
    ResourceCardVariant.mcpConfig => 'Config',
    ResourceCardVariant.plain => '',
  };

  static ResourceCardPresentation _prompt(Resource resource) {
    final String content = _compact(resource.content);
    return ResourceCardPresentation(
      title: _resolvedTitle(resource.title, content, fallback: 'Prompt'),
      summary: content,
      variant: ResourceCardVariant.prompt,
    );
  }

  static ResourceCardPresentation _skill(Resource resource) {
    final bool hasFrontMatter = resource.content.trimLeft().startsWith('---');
    final SkillConfiguration skill = SkillConfiguration.parse(
      resource.content,
      fallbackName: resource.title,
    );
    final String description = _compact(skill.description);
    final String instructions = _compact(skill.instructions);
    return ResourceCardPresentation(
      title: hasFrontMatter
          ? skill.name
          : _resolvedTitle(
              resource.title,
              instructions,
              fallback: 'Untitled Skill',
            ),
      summary: description.isNotEmpty ? description : instructions,
      variant: resource.updateUrl == null
          ? ResourceCardVariant.skillLocal
          : ResourceCardVariant.skillOnline,
    );
  }

  static ResourceCardPresentation _mcp(Resource resource) {
    final McpConfiguration configuration = McpConfiguration.parse(
      resource.content,
    );
    final String detectedName = configuration.detectedName?.trim() ?? '';
    final String title = resource.title.trim().isNotEmpty
        ? resource.title.trim()
        : detectedName.isNotEmpty
        ? detectedName
        : 'MCP Server';
    return switch (configuration.transport) {
      McpTransport.stdio => ResourceCardPresentation(
        title: title,
        summary: _mcpSummary('STDIO', <String>[
          configuration.command,
          ...configuration.arguments,
        ]),
        variant: ResourceCardVariant.mcpStdio,
      ),
      McpTransport.streamableHttp => ResourceCardPresentation(
        title: title,
        summary: _mcpSummary('HTTP', <String>[configuration.url]),
        variant: ResourceCardVariant.mcpHttp,
      ),
      McpTransport.raw => ResourceCardPresentation(
        title: title,
        summary: _mcpSummary('Config', <String>[configuration.raw]),
        variant: ResourceCardVariant.mcpConfig,
      ),
    };
  }

  static ResourceCardPresentation _plain(Resource resource) {
    final String content = _compact(resource.content);
    return ResourceCardPresentation(
      title: _resolvedTitle(resource.title, content, fallback: 'Resource'),
      summary: content,
      variant: ResourceCardVariant.plain,
    );
  }
}

enum ResourceCardVariant {
  prompt,
  skillLocal,
  skillOnline,
  mcpStdio,
  mcpHttp,
  mcpConfig,
  plain,
}

String _mcpSummary(String transport, List<String> values) {
  final String detail = _compact(
    values.where((String value) => value.trim().isNotEmpty).join(' '),
  );
  return detail.isEmpty ? transport : '$transport · $detail';
}

String _resolvedTitle(
  String title,
  String content, {
  required String fallback,
}) {
  final String trimmed = title.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  if (content.isEmpty) {
    return fallback;
  }
  return content
      .split(RegExp(r'(?<=[.!?。！？])\s+'))
      .first
      .replaceFirst(RegExp(r'^#+\s*'), '')
      .trim();
}

String _compact(String value) =>
    value.replaceAll('\r\n', '\n').trim().replaceAll(RegExp(r'\s+'), ' ');
