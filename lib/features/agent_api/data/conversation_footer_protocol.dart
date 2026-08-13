import 'package:dingdong/features/agent_api/domain/conversation_footer_symbols.dart';

const int _maximumConversationFooterItems = 24;
const int _maximumConversationFooterLabelCharacters = 32;
const int _maximumConversationFooterTitleCharacters = 64;
const int _maximumConversationFooterMergeKeyCharacters = 160;

const Map<String, Map<String, String>> dingDongConversationFooterPalette =
    <String, Map<String, String>>{
      'prompt': <String, String>{'light': '#A97822', 'dark': '#D8A64A'},
      'skill': <String, String>{'light': '#4C63A1', 'dark': '#91A8E8'},
      'mcp': <String, String>{'light': '#2F7651', 'dark': '#8BB29E'},
    };

/// Builds compact text presentations from one canonical footer capsule.
///
/// Codex and other non-ANSI hosts receive one text-only Markdown line. Images
/// are intentionally excluded because Codex renders every Markdown image as a
/// block-level media preview instead of an inline glyph.
Map<String, Object?> buildDingDongConversationFooter({
  required Iterable<Map<String, Object?>> items,
  String label = 'DingDong',
  ConversationFooterSymbols symbols = ConversationFooterSymbols.defaultValue,
}) {
  final ConversationFooterSymbols normalizedSymbols = symbols.sanitized();
  final String normalizedLabel = _boundedFooterText(
    label,
    maximumCharacters: _maximumConversationFooterLabelCharacters,
    fallback: 'DingDong',
  );
  final List<Map<String, Object?>> normalizedItems = items
      .take(_maximumConversationFooterItems)
      .map(
        (Map<String, Object?> item) => normalizeDingDongConversationFooterItem(
          item,
          symbols: normalizedSymbols,
        ),
      )
      .whereType<Map<String, Object?>>()
      .toList(growable: false);
  final List<String> titles = normalizedItems
      .map((Map<String, Object?> item) => item['title']! as String)
      .toList(growable: false);
  final String markdownTokens = normalizedItems
      .map((Map<String, Object?> item) => item['lineToken']! as String)
      .join(' | ');
  final String markdownLine = normalizedItems.isEmpty
      ? ''
      : '${_markdownSafeFooterText(normalizedLabel)} · $markdownTokens';
  final String fallbackLine = normalizedItems.isEmpty
      ? ''
      : '$normalizedLabel · ${normalizedItems.map((Map<String, Object?> item) => _plainFooterToken(item, normalizedSymbols)).join(' | ')}';
  final String ansiLine = normalizedItems.isEmpty
      ? ''
      : '\u001B[2m$normalizedLabel\u001B[0m · ${normalizedItems.map((Map<String, Object?> item) => _ansiFooterToken(item, normalizedSymbols)).join(' | ')}';
  final Map<String, Object?> capsule = <String, Object?>{
    'label': normalizedLabel,
    'items': normalizedItems,
    'palette': dingDongConversationFooterPalette,
    'confirmedSkillUseMarker': '*',
    'titles': titles,
    // Keep the original nested flag for already-configured Agents while the
    // top-level flag remains the preferred shape for new integrations.
    'visible': normalizedItems.isNotEmpty,
  };

  return <String, Object?>{
    'visible': normalizedItems.isNotEmpty,
    'capsule': capsule,
    'presentations': <String, Object?>{
      'codex': <String, Object?>{
        'format': 'markdown',
        'line': markdownLine,
        'usesToolCall': false,
      },
      'ansi': <String, Object?>{
        'format': 'ansi-256',
        'line': ansiLine,
        'requiresCapability': 'ansi-color',
      },
      'markdown': <String, Object?>{'format': 'markdown', 'line': markdownLine},
      'text': <String, Object?>{'format': 'plain-text', 'line': fallbackLine},
    },
    'ansiLine': ansiLine,
    'line': markdownLine,
    'fallbackLine': fallbackLine,
    'titles': titles,
  };
}

/// Removes presentation-controlled fields and recomputes truthful markers.
///
/// A Skill receives `*` only when the item carries the complete evidence shape
/// returned by a successful `dingdong_load_skill` call.
Map<String, Object?>? normalizeDingDongConversationFooterItem(
  Map<String, Object?> item, {
  ConversationFooterSymbols symbols = ConversationFooterSymbols.defaultValue,
}) {
  final String type = (item['type'] as String? ?? '').trim().toLowerCase();
  if (!dingDongConversationFooterPalette.containsKey(type)) {
    return null;
  }
  final String title = _boundedFooterText(
    item['title'] as String? ?? '',
    maximumCharacters: _maximumConversationFooterTitleCharacters,
  );
  if (title.isEmpty) {
    return null;
  }
  final bool skill = type == 'skill';
  final String mergeKey = _boundedFooterText(
    item['mergeKey'] as String? ?? '',
    maximumCharacters: _maximumConversationFooterMergeKeyCharacters,
  );
  final bool confirmedSkillUse =
      skill &&
      item['confirmedUse'] == true &&
      item['usage'] == 'loaded' &&
      item['marker'] == '*';
  final String usage = switch (type) {
    'prompt' => 'active',
    'skill' => confirmedSkillUse ? 'loaded' : 'candidate',
    'mcp' => 'available',
    _ => 'available',
  };
  final String marker = confirmedSkillUse ? '*' : '';
  final String markdownMarker = confirmedSkillUse ? r'\*' : '';
  return <String, Object?>{
    'title': title,
    'type': type,
    'tone': type,
    'usage': usage,
    if (mergeKey.isNotEmpty) 'mergeKey': mergeKey,
    if (skill) 'confirmedUse': confirmedSkillUse,
    if (skill) 'marker': marker,
    'lineToken':
        '${_markdownTypeIndicator(type, symbols.sanitized())} ${_markdownSafeFooterText(title)}$markdownMarker',
  };
}

String _ansiFooterToken(
  Map<String, Object?> item,
  ConversationFooterSymbols symbols,
) {
  final String type = item['type']! as String;
  final String color = switch (type) {
    'prompt' => '178',
    'skill' => '69',
    'mcp' => '71',
    _ => '250',
  };
  final String marker = item['marker'] as String? ?? '';
  return '\u001B[38;5;${color}m${symbols.forType(type)} ${item['title']}$marker\u001B[0m';
}

String _plainFooterToken(
  Map<String, Object?> item,
  ConversationFooterSymbols symbols,
) {
  final String marker = item['marker'] as String? ?? '';
  return '${symbols.forType(item['type']! as String)} ${item['title']}$marker';
}

String _markdownTypeIndicator(String type, ConversationFooterSymbols symbols) =>
    _markdownSafeFooterText(symbols.forType(type));

String _boundedFooterText(
  String value, {
  required int maximumCharacters,
  String fallback = '',
}) {
  final String normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  final String withoutControls = normalized
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F]'), '')
      .trim();
  if (withoutControls.isEmpty) {
    return fallback;
  }
  final List<int> characters = withoutControls.runes.toList(growable: false);
  if (characters.length <= maximumCharacters) {
    return withoutControls;
  }
  return '${String.fromCharCodes(characters.take(maximumCharacters))}...';
}

String _markdownSafeFooterText(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('`', r'\`')
    .replaceAll('*', r'\*')
    .replaceAll('_', r'\_')
    .replaceAll('[', r'\[')
    .replaceAll(']', r'\]')
    .replaceAll('|', r'\|');
