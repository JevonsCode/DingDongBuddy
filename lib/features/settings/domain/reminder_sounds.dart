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

/// Sounds an Agent may save on the user's behalf. Custom files stay a desktop
/// choice because an Agent cannot pick a sound file for the user.
const List<String> agentSelectableSoundValues = <String>[
  'default',
  'dingSoft',
  'dingBright',
  'dingCrisp',
  'dingDeep',
  'system',
  'muted',
];
