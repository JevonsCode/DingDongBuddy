import 'dart:convert';
import 'dart:io';

/// A local stdio MCP command parsed from one stored MCP resource.
final class McpCommandSpec {
  const McpCommandSpec({
    required this.command,
    this.arguments = const <String>[],
  });

  factory McpCommandSpec.parse(String content) {
    try {
      final Map<String, Object?> json =
          jsonDecode(content) as Map<String, Object?>;
      final String? command = json['command'] as String?;
      if (command != null && command.trim().isNotEmpty) {
        return McpCommandSpec(
          command: command.trim(),
          arguments: (json['args'] as List<Object?>? ?? const <Object?>[])
              .map((Object? value) => '$value')
              .toList(growable: false),
        );
      }
    } on Object {
      // Fall through to the human-readable command line format.
    }
    for (final String line in content.split('\n')) {
      final String trimmed = line.trim();
      for (final String prefix in <String>[
        'Local command:',
        'Command:',
        'command:',
      ]) {
        if (trimmed.startsWith(prefix)) {
          final List<String> words = _splitShellWords(
            trimmed.substring(prefix.length).trim(),
          );
          if (words.isNotEmpty) {
            return McpCommandSpec(
              command: words.first,
              arguments: words.skip(1).toList(growable: false),
            );
          }
        }
      }
    }
    throw const FormatException(
      'MCP resource does not include a command or Local command line.',
    );
  }

  final String command;
  final List<String> arguments;

  @override
  bool operator ==(Object other) {
    return other is McpCommandSpec &&
        other.command == command &&
        _listEquals(other.arguments, arguments);
  }

  @override
  int get hashCode => Object.hash(command, Object.hashAll(arguments));
}

/// Result returned for both previews and confirmed configuration writes.
final class NativeMcpInstallResult {
  const NativeMcpInstallResult({required this.configPath, required this.entry});

  final String configPath;
  final Map<String, Object?> entry;
}

/// Safely previews or installs MCP entries without replacing unrelated config.
final class NativeMcpInstaller {
  const NativeMcpInstaller({
    required this.codexConfigFile,
    required this.claudeConfigFile,
  });

  final File codexConfigFile;
  final File claudeConfigFile;

  Future<NativeMcpInstallResult> install({
    required String serverName,
    required McpCommandSpec commandSpec,
    required String target,
    required bool write,
  }) async {
    return switch (target) {
      'codex' => _installCodex(serverName, commandSpec, write),
      'claude' => _installClaude(serverName, commandSpec, write),
      _ => throw ArgumentError.value(target, 'target', 'Use codex or claude'),
    };
  }

  Future<NativeMcpInstallResult> _installCodex(
    String serverName,
    McpCommandSpec spec,
    bool write,
  ) async {
    final Map<String, Object?> entry = <String, Object?>{
      'type': 'stdio',
      'command': spec.command,
      'args': spec.arguments,
      'enabled': true,
    };
    if (write) {
      final String existing = await codexConfigFile.exists()
          ? await codexConfigFile.readAsString()
          : '';
      await _writeAtomically(
        codexConfigFile,
        _replaceCodexBlock(existing, serverName, spec),
      );
    }
    return NativeMcpInstallResult(
      configPath: codexConfigFile.path,
      entry: entry,
    );
  }

  Future<NativeMcpInstallResult> _installClaude(
    String serverName,
    McpCommandSpec spec,
    bool write,
  ) async {
    final Map<String, Object?> entry = <String, Object?>{
      'command': spec.command,
      if (spec.arguments.isNotEmpty) 'args': spec.arguments,
    };
    if (write) {
      Map<String, Object?> root = <String, Object?>{
        'mcpServers': <String, Object?>{},
      };
      if (await claudeConfigFile.exists()) {
        final String existing = await claudeConfigFile.readAsString();
        if (existing.trim().isNotEmpty) {
          root = jsonDecode(existing) as Map<String, Object?>;
        }
      }
      final Map<String, Object?> servers = <String, Object?>{
        ...(root['mcpServers'] as Map<String, Object?>? ?? <String, Object?>{}),
        serverName: entry,
      };
      await _writeAtomically(
        claudeConfigFile,
        const JsonEncoder.withIndent(
          '  ',
        ).convert(<String, Object?>{...root, 'mcpServers': servers}),
      );
    }
    return NativeMcpInstallResult(
      configPath: claudeConfigFile.path,
      entry: entry,
    );
  }
}

String _replaceCodexBlock(
  String content,
  String serverName,
  McpCommandSpec spec,
) {
  final String header = '[mcp_servers.$serverName]';
  final List<String> lines = content.split('\n');
  final int start = lines.indexWhere((String line) => line.trim() == header);
  if (start >= 0) {
    var end = start + 1;
    while (end < lines.length) {
      final String value = lines[end].trim();
      if (value.startsWith('[') && value.endsWith(']')) {
        break;
      }
      end += 1;
    }
    lines.removeRange(start, end);
  }
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  lines.addAll(<String>[
    if (lines.isNotEmpty) '',
    header,
    'type = "stdio"',
    'command = "${_tomlEscape(spec.command)}"',
    if (spec.arguments.isNotEmpty)
      'args = [${spec.arguments.map((String value) => '"${_tomlEscape(value)}"').join(', ')}]',
    'enabled = true',
    '',
  ]);
  return lines.join('\n');
}

Future<void> _writeAtomically(File target, String content) async {
  await target.parent.create(recursive: true);
  final File temporary = File('${target.path}.tmp');
  final File backup = File('${target.path}.bak');
  await temporary.writeAsString(content, flush: true);
  final bool hadTarget = await target.exists();
  try {
    if (hadTarget) {
      if (await backup.exists()) {
        await backup.delete();
      }
      await target.rename(backup.path);
    }
    await temporary.rename(target.path);
    if (await backup.exists()) {
      await backup.delete();
    }
  } on Object {
    if (await temporary.exists()) {
      await temporary.delete();
    }
    if (hadTarget && await backup.exists() && !await target.exists()) {
      await backup.rename(target.path);
    }
    rethrow;
  }
}

List<String> _splitShellWords(String value) {
  final List<String> words = <String>[];
  final StringBuffer current = StringBuffer();
  String? quote;
  var escaped = false;
  void flush() {
    if (current.isNotEmpty) {
      words.add(current.toString());
      current.clear();
    }
  }

  for (final int rune in value.runes) {
    final String character = String.fromCharCode(rune);
    if (escaped) {
      current.write(character);
      escaped = false;
    } else if (character == r'\') {
      escaped = true;
    } else if (quote != null) {
      if (character == quote) {
        quote = null;
      } else {
        current.write(character);
      }
    } else if (character == '"' || character == "'") {
      quote = character;
    } else if (character.trim().isEmpty) {
      flush();
    } else {
      current.write(character);
    }
  }
  flush();
  return words;
}

String _tomlEscape(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

bool _listEquals(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
