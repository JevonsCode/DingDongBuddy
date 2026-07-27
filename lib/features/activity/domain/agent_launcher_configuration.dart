import 'dart:convert';

import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';

/// macOS terminal applications supported for reopening CLI Agent sessions.
enum MacOsTerminalApplication {
  terminal('terminal'),
  iTerm('iterm');

  const MacOsTerminalApplication(this.configValue);

  final String configValue;

  static MacOsTerminalApplication parse(Object? value, String path) {
    if (value is! String) {
      throw FormatException('$path must be a string.');
    }
    return values.firstWhere(
      (MacOsTerminalApplication item) => item.configValue == value,
      orElse: () => throw FormatException(
        '$path must be one of: '
        '${values.map((MacOsTerminalApplication item) => item.configValue).join(', ')}.',
      ),
    );
  }
}

/// How iTerm should create a resumed Agent session.
enum ITermOpenMode {
  newWindow('new-window'),
  newTab('new-tab');

  const ITermOpenMode(this.configValue);

  final String configValue;

  static ITermOpenMode parse(Object? value, String path) {
    if (value is! String) {
      throw FormatException('$path must be a string.');
    }
    return values.firstWhere(
      (ITermOpenMode item) => item.configValue == value,
      orElse: () => throw FormatException(
        '$path must be one of: '
        '${values.map((ITermOpenMode item) => item.configValue).join(', ')}.',
      ),
    );
  }
}

/// Resolved settings used to open one CLI Agent conversation.
final class AgentLauncherSettings {
  const AgentLauncherSettings({
    this.macosTerminal = MacOsTerminalApplication.terminal,
    this.iTermOpenMode = ITermOpenMode.newWindow,
  });

  final MacOsTerminalApplication macosTerminal;
  final ITermOpenMode iTermOpenMode;

  Map<String, Object?> toJson() => <String, Object?>{
    'macosTerminal': macosTerminal.configValue,
    'itermOpenMode': iTermOpenMode.configValue,
  };
}

/// User-owned, declarative launcher settings with optional Agent overrides.
final class AgentLauncherConfiguration {
  const AgentLauncherConfiguration({
    this.schemaVersion = currentSchemaVersion,
    this.defaults = const AgentLauncherSettings(),
    this.agentOverrides = const <AgentClient, AgentLauncherOverride>{},
  });

  factory AgentLauncherConfiguration.decode(String contents) {
    final Object? decoded;
    try {
      decoded = jsonDecode(contents);
    } on FormatException catch (error) {
      throw FormatException(
        'Agent launcher configuration is not valid JSON: ${error.message}',
      );
    }
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException(
        'Agent launcher configuration must be a JSON object.',
      );
    }
    return AgentLauncherConfiguration.fromJson(_stringMap(decoded, r'$'));
  }

  factory AgentLauncherConfiguration.fromJson(Map<String, Object?> json) {
    _rejectUnknownKeys(json, const <String>{
      'schemaVersion',
      'defaults',
      'agents',
    }, r'$');
    final Object? version = json['schemaVersion'];
    if (version != currentSchemaVersion) {
      throw FormatException(
        r'$.schemaVersion must be '
        '$currentSchemaVersion.',
      );
    }
    final AgentLauncherOverride defaultOverride =
        AgentLauncherOverride.fromJson(
          _optionalObject(json['defaults'], r'$.defaults'),
          r'$.defaults',
        );
    final AgentLauncherSettings defaults = defaultOverride.resolve(
      const AgentLauncherSettings(),
    );
    final Map<String, Object?> agents = _optionalObject(
      json['agents'],
      r'$.agents',
    );
    final Map<AgentClient, AgentLauncherOverride> overrides =
        <AgentClient, AgentLauncherOverride>{};
    for (final MapEntry<String, Object?> entry in agents.entries) {
      final AgentClient client = AgentClient.values.firstWhere(
        (AgentClient item) => item.apiValue == entry.key,
        orElse: () => AgentClient.unknown,
      );
      if (client == AgentClient.unknown) {
        throw FormatException(
          r'$.agents contains an unsupported Agent key: '
          '"${entry.key}".',
        );
      }
      overrides[client] = AgentLauncherOverride.fromJson(
        _requiredObject(entry.value, r'$.agents.${entry.key}'),
        r'$.agents.${entry.key}',
      );
    }
    return AgentLauncherConfiguration(
      schemaVersion: currentSchemaVersion,
      defaults: defaults,
      agentOverrides: Map<AgentClient, AgentLauncherOverride>.unmodifiable(
        overrides,
      ),
    );
  }

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final AgentLauncherSettings defaults;
  final Map<AgentClient, AgentLauncherOverride> agentOverrides;

  AgentLauncherSettings settingsFor(AgentClient client) =>
      agentOverrides[client]?.resolve(defaults) ?? defaults;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'defaults': defaults.toJson(),
    if (agentOverrides.isNotEmpty)
      'agents': <String, Object?>{
        for (final MapEntry<AgentClient, AgentLauncherOverride> entry
            in agentOverrides.entries)
          entry.key.apiValue: entry.value.toJson(),
      },
  };
}

/// Partial settings applied on top of the configuration defaults.
final class AgentLauncherOverride {
  const AgentLauncherOverride({this.macosTerminal, this.iTermOpenMode});

  factory AgentLauncherOverride.fromJson(
    Map<String, Object?> json,
    String path,
  ) {
    _rejectUnknownKeys(json, const <String>{
      'macosTerminal',
      'itermOpenMode',
    }, path);
    return AgentLauncherOverride(
      macosTerminal: json.containsKey('macosTerminal')
          ? MacOsTerminalApplication.parse(
              json['macosTerminal'],
              '$path.macosTerminal',
            )
          : null,
      iTermOpenMode: json.containsKey('itermOpenMode')
          ? ITermOpenMode.parse(json['itermOpenMode'], '$path.itermOpenMode')
          : null,
    );
  }

  final MacOsTerminalApplication? macosTerminal;
  final ITermOpenMode? iTermOpenMode;

  AgentLauncherSettings resolve(AgentLauncherSettings fallback) =>
      AgentLauncherSettings(
        macosTerminal: macosTerminal ?? fallback.macosTerminal,
        iTermOpenMode: iTermOpenMode ?? fallback.iTermOpenMode,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    if (macosTerminal != null) 'macosTerminal': macosTerminal!.configValue,
    if (iTermOpenMode != null) 'itermOpenMode': iTermOpenMode!.configValue,
  };
}

Map<String, Object?> _optionalObject(Object? value, String path) {
  if (value == null) {
    return <String, Object?>{};
  }
  return _requiredObject(value, path);
}

Map<String, Object?> _requiredObject(Object? value, String path) {
  if (value is! Map<Object?, Object?>) {
    throw FormatException('$path must be a JSON object.');
  }
  return _stringMap(value, path);
}

Map<String, Object?> _stringMap(Map<Object?, Object?> value, String path) {
  final Map<String, Object?> result = <String, Object?>{};
  for (final MapEntry<Object?, Object?> entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$path contains a non-string key.');
    }
    result[entry.key! as String] = entry.value;
  }
  return result;
}

void _rejectUnknownKeys(
  Map<String, Object?> value,
  Set<String> allowed,
  String path,
) {
  final List<String> unknown =
      value.keys.where((String key) => !allowed.contains(key)).toList()..sort();
  if (unknown.isNotEmpty) {
    throw FormatException(
      '$path contains unsupported fields: ${unknown.join(', ')}.',
    );
  }
}
