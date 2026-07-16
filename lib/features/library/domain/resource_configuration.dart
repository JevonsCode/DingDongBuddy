import 'dart:convert';

/// Editable representation of a portable Agent Skills `SKILL.md` document.
final class SkillConfiguration {
  const SkillConfiguration({
    required this.name,
    required this.description,
    required this.instructions,
    this.preservedFrontMatter = const <String>[],
  });

  factory SkillConfiguration.template(String name) {
    final String normalizedName = normalizeSkillName(name);
    return SkillConfiguration(
      name: normalizedName,
      description: '',
      instructions: '# ${_titleFromSkillName(normalizedName)}\n\n',
    );
  }

  factory SkillConfiguration.parse(
    String document, {
    required String fallbackName,
  }) {
    final _SkillDocument parsed = _parseSkillDocument(document);
    if (parsed.hasFrontMatter) {
      return SkillConfiguration(
        name: normalizeSkillName(parsed.name ?? fallbackName),
        description: parsed.description?.trim() ?? '',
        instructions: parsed.instructions,
        preservedFrontMatter: parsed.preservedFrontMatter,
      );
    }
    return SkillConfiguration(
      name: normalizeSkillName(fallbackName),
      description: '',
      instructions: parsed.instructions,
    );
  }

  /// Parses an installed online Skill without repairing invalid metadata.
  ///
  /// Online resources must follow the Agent Skills name and description
  /// constraints because those fields are presented as authoritative,
  /// read-only metadata in DingDong.
  factory SkillConfiguration.parseOnline(String document) {
    final _SkillDocument parsed = _parseSkillDocument(document);
    if (!parsed.hasFrontMatter) {
      throw const FormatException(
        'Online SKILL.md must start with YAML frontmatter.',
      );
    }
    final String name = parsed.name?.trim() ?? '';
    final String description = parsed.description?.trim() ?? '';
    if (name.isEmpty ||
        name.length > 64 ||
        !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(name)) {
      throw const FormatException(
        'Online Skill name must be 1-64 lowercase letters, numbers, or single hyphens.',
      );
    }
    if (description.isEmpty || description.length > 1024) {
      throw const FormatException(
        'Online Skill description must be 1-1024 characters.',
      );
    }
    return SkillConfiguration(
      name: name,
      description: description,
      instructions: parsed.instructions,
      preservedFrontMatter: parsed.preservedFrontMatter,
    );
  }

  final String name;
  final String description;
  final String instructions;
  final List<String> preservedFrontMatter;

  SkillConfiguration copyWith({
    String? name,
    String? description,
    String? instructions,
  }) {
    return SkillConfiguration(
      name: name ?? this.name,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
      preservedFrontMatter: preservedFrontMatter,
    );
  }

  String encode() {
    final List<String> frontMatter = <String>[
      'name: ${normalizeSkillName(name)}',
      'description: ${jsonEncode(description.trim())}',
      ...preservedFrontMatter.where((String line) => line.trim().isNotEmpty),
    ];
    return <String>[
      '---',
      ...frontMatter,
      '---',
      '',
      instructions.trim(),
    ].join('\n').trimRight();
  }
}

String _titleFromSkillName(String value) {
  return value
      .split('-')
      .where((String part) => part.isNotEmpty)
      .map(
        (String part) =>
            '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

String normalizeSkillName(String value) {
  final String normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? 'untitled-skill' : normalized;
}

String _decodeYamlScalar(String value) {
  final String trimmed = value.trim();
  if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
    try {
      return jsonDecode(trimmed) as String;
    } on FormatException {
      return trimmed.substring(1, trimmed.length - 1);
    }
  }
  if (trimmed.startsWith("'") && trimmed.endsWith("'")) {
    return trimmed.substring(1, trimmed.length - 1).replaceAll("''", "'");
  }
  return trimmed;
}

final class _SkillDocument {
  const _SkillDocument({
    required this.hasFrontMatter,
    required this.name,
    required this.description,
    required this.instructions,
    required this.preservedFrontMatter,
  });

  final bool hasFrontMatter;
  final String? name;
  final String? description;
  final String instructions;
  final List<String> preservedFrontMatter;
}

_SkillDocument _parseSkillDocument(String document) {
  final String normalized = document.replaceAll('\r\n', '\n').trim();
  final List<String> lines = normalized.split('\n');
  if (lines.isEmpty || lines.first.trim() != '---') {
    return _SkillDocument(
      hasFrontMatter: false,
      name: null,
      description: null,
      instructions: normalized,
      preservedFrontMatter: const <String>[],
    );
  }
  final int end = lines.indexWhere((String line) => line.trim() == '---', 1);
  if (end <= 0) {
    return _SkillDocument(
      hasFrontMatter: false,
      name: null,
      description: null,
      instructions: normalized,
      preservedFrontMatter: const <String>[],
    );
  }

  String? name;
  String? description;
  final List<String> preserved = <String>[];
  final List<String> frontMatter = lines.sublist(1, end);
  var index = 0;
  while (index < frontMatter.length) {
    final String line = frontMatter[index];
    final RegExpMatch? match = RegExp(
      r'^([A-Za-z0-9_-]+)\s*:\s*(.*)$',
    ).firstMatch(line);
    final String? key = match?.group(1);
    if (key != 'name' && key != 'description') {
      preserved.add(line);
      index += 1;
      continue;
    }

    final String rawValue = match!.group(2) ?? '';
    final bool block = RegExp(r'^[>|][+-]?$').hasMatch(rawValue.trim());
    String value;
    if (block) {
      final List<String> blockLines = <String>[];
      index += 1;
      while (index < frontMatter.length) {
        final String candidate = frontMatter[index];
        if (candidate.isNotEmpty &&
            !candidate.startsWith(' ') &&
            !candidate.startsWith('\t')) {
          break;
        }
        blockLines.add(candidate);
        index += 1;
      }
      value = _decodeYamlBlock(rawValue.trim(), blockLines);
    } else {
      value = _decodeYamlScalar(rawValue);
      index += 1;
    }
    if (key == 'name') {
      name = value;
    } else {
      description = value;
    }
  }

  return _SkillDocument(
    hasFrontMatter: true,
    name: name,
    description: description,
    instructions: lines.sublist(end + 1).join('\n').trim(),
    preservedFrontMatter: List<String>.unmodifiable(preserved),
  );
}

String _decodeYamlBlock(String marker, List<String> lines) {
  final Iterable<String> nonEmpty = lines.where(
    (String line) => line.trim().isNotEmpty,
  );
  final int indent = nonEmpty.isEmpty
      ? 0
      : nonEmpty
            .map((String line) => line.length - line.trimLeft().length)
            .reduce((int left, int right) => left < right ? left : right);
  final List<String> content = lines
      .map(
        (String line) =>
            line.length >= indent ? line.substring(indent) : line.trimLeft(),
      )
      .toList(growable: false);
  if (marker.startsWith('|')) {
    return content.join('\n').trimRight();
  }
  final StringBuffer result = StringBuffer();
  var pendingBreak = false;
  for (final String line in content) {
    if (line.trim().isEmpty) {
      pendingBreak = true;
      continue;
    }
    if (result.isNotEmpty) {
      result.write(pendingBreak ? '\n' : ' ');
    }
    result.write(line.trim());
    pendingBreak = false;
  }
  return result.toString().trim();
}

/// Transport choices exposed by the MCP resource editor.
enum McpTransport { stdio, streamableHttp, raw }

/// Structured, portable MCP connection settings stored in Resource.content.
final class McpConfiguration {
  const McpConfiguration({
    required this.transport,
    this.command = '',
    this.arguments = const <String>[],
    this.environment = const <String, String>{},
    this.url = '',
    this.headers = const <String, String>{},
    this.tokenEnvironmentVariable = '',
    this.raw = '',
    this.detectedName,
  });

  factory McpConfiguration.parse(String content) {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) {
      return const McpConfiguration(transport: McpTransport.stdio);
    }
    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      decoded = null;
    }
    if (decoded is Map) {
      final Map<String, Object?> document = Map<String, Object?>.from(decoded);
      String? detectedName;
      Map<String, Object?> settings = document;
      final Object? serversValue = document['mcpServers'];
      if (serversValue is Map && serversValue.isNotEmpty) {
        detectedName = serversValue.keys.first.toString();
        final Object? first = serversValue.values.first;
        if (first is Map) {
          settings = Map<String, Object?>.from(first);
        }
      }
      final String command = _string(settings['command']);
      final String url = _string(settings['url']);
      final String type = _string(settings['type']).toLowerCase();
      if (url.isNotEmpty || type.contains('http') || type == 'sse') {
        return McpConfiguration(
          transport: McpTransport.streamableHttp,
          url: url,
          headers: _stringMap(settings['headers'] ?? settings['http_headers']),
          tokenEnvironmentVariable: _string(
            settings['bearerTokenEnvVar'] ?? settings['bearer_token_env_var'],
          ),
          detectedName: detectedName,
        );
      }
      if (command.isNotEmpty || type == 'stdio') {
        return McpConfiguration(
          transport: McpTransport.stdio,
          command: command,
          arguments: _stringList(settings['args']),
          environment: _stringMap(settings['env']),
          detectedName: detectedName,
        );
      }
      return McpConfiguration(transport: McpTransport.raw, raw: trimmed);
    }
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        !trimmed.contains(RegExp(r'\s'))) {
      return McpConfiguration(
        transport: McpTransport.streamableHttp,
        url: trimmed,
      );
    }
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return McpConfiguration(transport: McpTransport.raw, raw: trimmed);
    }
    return McpConfiguration(transport: McpTransport.stdio, command: trimmed);
  }

  final McpTransport transport;
  final String command;
  final List<String> arguments;
  final Map<String, String> environment;
  final String url;
  final Map<String, String> headers;
  final String tokenEnvironmentVariable;
  final String raw;
  final String? detectedName;

  String encode() {
    switch (transport) {
      case McpTransport.stdio:
        return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'type': 'stdio',
          'command': command.trim(),
          if (arguments.isNotEmpty) 'args': arguments,
          if (environment.isNotEmpty) 'env': environment,
        });
      case McpTransport.streamableHttp:
        return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'type': 'streamable-http',
          'url': url.trim(),
          if (headers.isNotEmpty) 'headers': headers,
          if (tokenEnvironmentVariable.trim().isNotEmpty)
            'bearerTokenEnvVar': tokenEnvironmentVariable.trim(),
        });
      case McpTransport.raw:
        return raw.trim();
    }
  }
}

Map<String, String> parseConfigurationPairs(String value) {
  final Map<String, String> pairs = <String, String>{};
  for (final String line in value.replaceAll('\r\n', '\n').split('\n')) {
    final int separator = line.indexOf('=');
    if (separator <= 0) {
      continue;
    }
    final String key = line.substring(0, separator).trim();
    if (key.isEmpty) {
      continue;
    }
    pairs[key] = line.substring(separator + 1).trim();
  }
  return Map<String, String>.unmodifiable(pairs);
}

String formatConfigurationPairs(Map<String, String> values) {
  return values.entries
      .map((MapEntry<String, String> entry) => '${entry.key}=${entry.value}')
      .join('\n');
}

String _string(Object? value) => value is String ? value.trim() : '';

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return List<String>.unmodifiable(
    value.whereType<String>().map((String item) => item.trim()),
  );
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) {
    return const <String, String>{};
  }
  return Map<String, String>.unmodifiable(<String, String>{
    for (final MapEntry<Object?, Object?> entry in value.entries)
      if (entry.key != null && entry.value != null)
        entry.key.toString(): entry.value.toString(),
  });
}
