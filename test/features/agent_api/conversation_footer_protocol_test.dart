import 'package:dingdong/features/agent_api/data/conversation_footer_protocol.dart';
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
    expect(conversation['line'], 'DingDong · 🟠 Reply marker');
    expect(conversation['fallbackLine'], 'DingDong · 🟠 Reply marker');
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
      ],
    );
    final Map<String, Object?> capsule =
        conversation['capsule']! as Map<String, Object?>;
    final List<Map<String, Object?>> items =
        (capsule['items']! as List<Object?>).cast<Map<String, Object?>>();

    expect(
      conversation['line'],
      r'DingDong · 🟠 Policy &lt;b&gt; \| \[x\] \* | 🔵 Candidate | 🔵 Loaded*',
    );
    expect(
      conversation['fallbackLine'],
      'DingDong · 🟠 Policy <b> | [x] * | 🔵 Candidate | 🔵 Loaded*',
    );
    expect(items[1]['confirmedUse'], isFalse);
    expect(items[1]['marker'], isEmpty);
    expect(items[2]['confirmedUse'], isTrue);
    expect(items[2]['marker'], '*');
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
