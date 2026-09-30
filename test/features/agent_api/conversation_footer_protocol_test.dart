import 'package:dingdong/features/agent_api/data/conversation_footer_protocol.dart';
import 'package:dingdong/features/agent_api/domain/conversation_footer_symbols.dart';
import 'package:dingdong/features/agent_api/domain/conversation_token_usage.dart';
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

  test('MCP marker requires a confirmed called replacement item', () {
    final Map<String, Object?> conversation = buildDingDongConversationFooter(
      items: <Map<String, Object?>>[
        <String, Object?>{
          'title': 'Available only',
          'type': 'mcp',
          'usage': 'available',
          'confirmedUse': true,
          'marker': '*',
          'serverName': 'dingdong-available-123456',
        },
        <String, Object?>{
          'title': 'Called',
          'type': 'mcp',
          'usage': 'called',
          'confirmedUse': true,
          'marker': '*',
          'serverName': 'dingdong-called-abcdef',
        },
        <String, Object?>{
          'title': 'Prompt',
          'type': 'prompt',
          'usage': 'called',
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
      r'DingDong · ♠ Available only | ♠ Called\* | ♥ Prompt',
    );
    expect(
      conversation['fallbackLine'],
      'DingDong · ♠ Available only | ♠ Called* | ♥ Prompt',
    );
    expect(items[0], containsPair('usage', 'available'));
    expect(items[0], containsPair('confirmedUse', false));
    expect(items[0], containsPair('marker', ''));
    expect(items[1], containsPair('usage', 'called'));
    expect(items[1], containsPair('confirmedUse', true));
    expect(items[1], containsPair('marker', '*'));
    expect(items[1], containsPair('serverName', 'dingdong-called-abcdef'));
    expect(items[2], isNot(contains('confirmedUse')));
    expect(capsule, containsPair('confirmedUseMarker', '*'));
    expect(capsule, containsPair('confirmedSkillUseMarker', '*'));
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

  test('exact token usage is appended after the resource footer', () {
    final Map<String, Object?> conversation = buildDingDongConversationFooter(
      items: <Map<String, Object?>>[
        <String, Object?>{'title': 'Reply marker', 'type': 'prompt'},
      ],
      tokenUsage: const ConversationTokenUsage(
        source: ConversationTokenUsageSource.codex,
        totalTokens: 12500,
        inputTokens: 12000,
        outputTokens: 500,
        cachedInputTokens: 8000,
      ),
    );
    final Map<String, Object?> capsule =
        conversation['capsule']! as Map<String, Object?>;

    expect(
      conversation['line'],
      'DingDong · ♥ Reply marker · 输入 12K · 输出 500 · 命中缓存 8K · 非缓存 4.5K',
    );
    expect(
      conversation['fallbackLine'],
      'DingDong · ♥ Reply marker · 输入 12K · 输出 500 · 命中缓存 8K · 非缓存 4.5K',
    );
    expect(
      conversation['ansiLine'],
      contains('输入 12K · 输出 500 · 命中缓存 8K · 非缓存 4.5K'),
    );
    expect(
      capsule['tokenUsage'],
      containsPair('source', ConversationTokenUsageSource.codex.apiValue),
    );
  });

  test(
    'Claude and Pi input includes cache once while Codex already includes it',
    () {
      for (final source in ConversationTokenUsageSource.values) {
        final result = buildDingDongConversationFooter(
          items: [
            {'title': 'Rules', 'type': 'prompt'},
          ],
          tokenUsage: ConversationTokenUsage(
            source: source,
            totalTokens: source == ConversationTokenUsageSource.codex
                ? 120
                : 190,
            inputTokens: 100,
            outputTokens: 20,
            cachedInputTokens: 60,
            cacheWriteInputTokens: 10,
          ),
        );
        expect(
          result['line'],
          contains(
            source == ConversationTokenUsageSource.codex
                ? '输入 100 · 输出 20 · 命中缓存 60'
                : '输入 170 · 输出 20 · 命中缓存 60',
          ),
        );
        expect(
          result['line'],
          contains(
            source == ConversationTokenUsageSource.codex ? '非缓存 60' : '非缓存 130',
          ),
        );
      }
    },
  );

  test('legacy total-only snapshots do not claim zero breakdowns', () {
    final result = buildDingDongConversationFooter(
      items: [
        {'title': 'Rules', 'type': 'prompt'},
      ],
      tokenUsage: const ConversationTokenUsage(
        source: ConversationTokenUsageSource.codex,
        totalTokens: 100,
      ),
    );
    expect(result['line'], endsWith('100 Token'));
  });

  test('token formatting stays compact in the footer and exact in hover', () {
    expect(formatCompactConversationTokenCount(842), '842');
    expect(formatCompactConversationTokenCount(1200), '1.2K');
    expect(formatCompactConversationTokenCount(12000), '12K');
    expect(formatCompactConversationTokenCount(1240000), '1.2M');
    expect(formatExactConversationTokenCount(12456789), '12,456,789');
  });

  test(
    'fully cached input leaves only output; inconsistent cache remains unknown',
    () {
      for (final cache in [100, 101]) {
        final result = buildDingDongConversationFooter(
          items: [
            {'title': 'Rules', 'type': 'prompt'},
          ],
          tokenUsage: ConversationTokenUsage(
            source: ConversationTokenUsageSource.codex,
            totalTokens: 120,
            inputTokens: 100,
            outputTokens: 20,
            cachedInputTokens: cache,
          ),
        );
        expect(result['line'], contains(cache == 100 ? '非缓存 20' : '120 Token'));
      }
    },
  );

  test(
    'Jev money values are ignored and unknown cache is not treated as zero',
    () {
      final result = buildDingDongConversationFooter(
        items: [
          {'title': 'Jev', 'type': 'mcp'},
        ],
        jevUsage: {
          'total_tokens': 308,
          'input_tokens': 300,
          'output_tokens': 8,
          'unknown_usage_requests': 0,
          'estimated_usd': 0.0000126,
          'is_bill': false,
        },
      );
      expect(result['line'], contains('Jev 308 Token'));
      expect((result['capsule'] as Map)['tokenUsage'], isNull);
    },
  );
}
