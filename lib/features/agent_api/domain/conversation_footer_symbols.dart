import 'dart:convert';

import 'package:characters/characters.dart';

/// User-selected type symbols shown in DingDong's Agent conversation footer.
final class ConversationFooterSymbols {
  const ConversationFooterSymbols({
    this.prompt = defaultPrompt,
    this.skill = defaultSkill,
    this.mcp = defaultMcp,
  });

  static const String defaultPrompt = '♥';
  static const String defaultSkill = '♦';
  static const String defaultMcp = '♠';
  static const ConversationFooterSymbols defaultValue =
      ConversationFooterSymbols();

  final String prompt;
  final String skill;
  final String mcp;

  ConversationFooterSymbols sanitized() {
    return ConversationFooterSymbols(
      prompt: sanitizeSymbol(prompt, fallback: defaultPrompt),
      skill: sanitizeSymbol(skill, fallback: defaultSkill),
      mcp: sanitizeSymbol(mcp, fallback: defaultMcp),
    );
  }

  ConversationFooterSymbols copyWith({
    String? prompt,
    String? skill,
    String? mcp,
  }) {
    return ConversationFooterSymbols(
      prompt: prompt ?? this.prompt,
      skill: skill ?? this.skill,
      mcp: mcp ?? this.mcp,
    ).sanitized();
  }

  String forType(String type) => switch (type.trim().toLowerCase()) {
    'prompt' => prompt,
    'skill' => skill,
    'mcp' => mcp,
    _ => '○',
  };

  String encode() {
    final ConversationFooterSymbols value = sanitized();
    return jsonEncode(<String, String>{
      'prompt': value.prompt,
      'skill': value.skill,
      'mcp': value.mcp,
    });
  }

  static ConversationFooterSymbols parse(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return defaultValue;
    }
    try {
      final Object? decoded = jsonDecode(value);
      if (decoded is! Map<String, Object?>) {
        return defaultValue;
      }
      return ConversationFooterSymbols(
        prompt: decoded['prompt'] is String
            ? decoded['prompt']! as String
            : defaultPrompt,
        skill: decoded['skill'] is String
            ? decoded['skill']! as String
            : defaultSkill,
        mcp: decoded['mcp'] is String ? decoded['mcp']! as String : defaultMcp,
      ).sanitized();
    } on FormatException {
      return defaultValue;
    }
  }

  /// Accepts one visible grapheme and reserves footer syntax for DingDong.
  static bool isValidSymbol(String value) {
    final String normalized = value.trim();
    return normalized.isNotEmpty &&
        normalized.characters.length == 1 &&
        normalized.runes.length <= 16 &&
        RegExp(r'[\p{L}\p{N}\p{P}\p{S}]', unicode: true).hasMatch(normalized) &&
        !normalized.contains('|') &&
        normalized != '*' &&
        !RegExp(
          r'[\u0000-\u001F\u007F-\u009F\u061C\u200B\u200E\u200F\u2028-\u202E\u2060-\u2069\uFEFF]',
        ).hasMatch(normalized);
  }

  static String sanitizeSymbol(String value, {required String fallback}) {
    final String normalized = value.trim();
    return isValidSymbol(normalized) ? normalized : fallback;
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationFooterSymbols &&
        other.prompt == prompt &&
        other.skill == skill &&
        other.mcp == mcp;
  }

  @override
  int get hashCode => Object.hash(prompt, skill, mcp);
}
