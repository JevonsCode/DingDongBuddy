import 'package:dingdong/features/agent_api/data/conversation_footer_protocol.dart';
import 'package:dingdong/features/agent_api/domain/conversation_footer_symbols.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('text footer keeps both current and legacy visibility flags', () {
    final Map<String, Object?> conversation = buildDingDongConversationFooter(
      items: <Map<String, Object?>>[
        <String, Object?>{
          'title': 'Reply marker',
          'type': 'prompt',
          'usage': 'active',
        },
      ],
    );
    final Map<String, Object?> capsule =
        conversation['capsule']! as Map<String, Object?>;
    final Map<String, Object?> presentations =
        conversation['presentations']! as Map<String, Object?>;

    expect(conversation['visible'], isTrue);
    expect(capsule['visible'], isTrue);
    expect(conversation['line'], 'DingDong · ♥ Reply marker');
    expect(conversation['fallbackLine'], 'DingDong · ♥ Reply marker');
    expect(presentations, isNot(contains('rich')));
    expect(presentations['codex'], containsPair('usesToolCall', false));
  });

  test('Markdown escaping and plain-text fallback remain distinct', () {
    final Map<String, Object?> conversation = buildDingDongConversationFooter(
      items: <Map<String, Object?>>[
        <String, Object?>{'title': 'Policy <b> | [x] *', 'type': 'prompt'},
        <String, Object?>{
          'title': 'Candidate',
          'type': 'skill',
          'usage': 'candidate',
          'confirmedUse': true,
          'marker': '*',
        },
        <String, Object?>{
          'title': 'Loaded',
          'type': 'skill',
          'usage': 'loaded',
          'confirmedUse': true,
          'marker': '*',
        },
        <String, Object?>{
          'title': 'Loaded again',
          'type': 'skill',
          'usage': 'loaded',
          'confirmedUse': true,
          'marker': '*',
        },
      ],
    );
    final Map<String, Object?> capsule =
        conversation['capsule']! as Map<String, Object?>;
    final List<Map<String, Object?>> items =
        (capsule['items']! as List<Object?>).cast<Map<String, Object?>>();

    expect(
      conversation['line'],
      r'DingDong · ♥ Policy &lt;b&gt; \| \[x\] \* | ♦ Candidate | ♦ Loaded\* | ♦ Loaded again\*',
    );
    expect(
      conversation['fallbackLine'],
      'DingDong · ♥ Policy <b> | [x] * | ♦ Candidate | ♦ Loaded* | ♦ Loaded again*',
    );
    expect(items[1]['confirmedUse'], isFalse);
    expect(items[1]['marker'], isEmpty);
    expect(items[2]['confirmedUse'], isTrue);
    expect(items[2]['marker'], '*');
    expect(items[2]['lineToken'], r'♦ Loaded\*');
    expect(items[3]['lineToken'], r'♦ Loaded again\*');
  });

  test('custom symbols are escaped in Markdown and retained elsewhere', () {
    final Map<String, Object?> conversation = buildDingDongConversationFooter(
      symbols: const ConversationFooterSymbols(
        prompt: '`',
        skill: '◆',
        mcp: '&',
      ),
      items: <Map<String, Object?>>[
        <String, Object?>{'title': 'Policy', 'type': 'prompt'},
        <String, Object?>{
          'title': 'Loaded',
          'type': 'skill',
          'usage': 'loaded',
          'confirmedUse': true,
          'marker': '*',
        },
        <String, Object?>{'title': 'Connector', 'type': 'mcp'},
      ],
    );
    final Map<String, Object?> capsule =
        conversation['capsule']! as Map<String, Object?>;
    final List<Map<String, Object?>> items =
        (capsule['items']! as List<Object?>).cast<Map<String, Object?>>();

    expect(
      conversation['line'],
      r'DingDong · \` Policy | ◆ Loaded\* | &amp; Connector',
    );
    expect(
      conversation['fallbackLine'],
      'DingDong · ` Policy | ◆ Loaded* | & Connector',
    );
    expect(
      items.map((Map<String, Object?> item) => item['lineToken']),
      <String>[r'\` Policy', r'◆ Loaded\*', '&amp; Connector'],
    );
    expect(conversation['ansiLine'], contains('◆ Loaded*'));
  });

  test('empty footer is hidden in both visibility shapes', () {
    final Map<String, Object?> conversation = buildDingDongConversationFooter(
      items: const <Map<String, Object?>>[],
    );
    final Map<String, Object?> capsule =
        conversation['capsule']! as Map<String, Object?>;

    expect(conversation['visible'], isFalse);
    expect(capsule['visible'], isFalse);
    expect(conversation['line'], isEmpty);
    expect(conversation['fallbackLine'], isEmpty);
  });
}
