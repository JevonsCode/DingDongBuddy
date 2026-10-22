// Pure Dart: the stdio MCP server (`dart build cli`) imports these values.

/// Sound value meaning "use the completion sound" for the attention reminder.
const String sameAsCompletionSound = 'sameAsCompletion';

/// Sounds a reminder may use. `custom` reads the matching custom file path.
const Set<String> notificationSoundValues = <String>{
  'default',
  'dingSoft',
  'dingBright',
  'dingCrisp',
  'dingDeep',
  'custom',
  'system',
  'muted',
};

/// Built-in sounds accepted by the legacy sound-setting tool. The named
/// reminder API also supports validated, imported custom audio.
const List<String> agentSelectableSoundValues = <String>[
  'default',
  'dingSoft',
  'dingBright',
  'dingCrisp',
  'dingDeep',
  'system',
  'muted',
];
