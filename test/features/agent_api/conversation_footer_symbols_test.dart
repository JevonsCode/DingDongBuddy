import 'package:dingdong/features/agent_api/domain/conversation_footer_symbols.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults and JSON round trip preserve all three resource symbols', () {
    expect(
      ConversationFooterSymbols.parse(null),
      ConversationFooterSymbols.defaultValue,
    );

    const ConversationFooterSymbols custom = ConversationFooterSymbols(
      prompt: '◆',
      skill: '🧑🏽‍💻',
      mcp: '●',
    );

    expect(ConversationFooterSymbols.parse(custom.encode()), custom);
  });

  test('malformed and unsafe stored values fall back independently', () {
    expect(
      ConversationFooterSymbols.parse('{not-json'),
      ConversationFooterSymbols.defaultValue,
    );
    expect(
      ConversationFooterSymbols.parse('{"prompt":"|","skill":"*","mcp":"\\n"}'),
      ConversationFooterSymbols.defaultValue,
    );
    expect(
      ConversationFooterSymbols.parse('{"prompt":"◇"}'),
      const ConversationFooterSymbols(prompt: '◇'),
    );
  });

  test('validation accepts one grapheme and rejects footer syntax', () {
    expect(ConversationFooterSymbols.isValidSymbol('🧑🏽‍💻'), isTrue);
    expect(ConversationFooterSymbols.isValidSymbol(''), isFalse);
    expect(ConversationFooterSymbols.isValidSymbol(' '), isFalse);
    expect(ConversationFooterSymbols.isValidSymbol('♥♦'), isFalse);
    expect(ConversationFooterSymbols.isValidSymbol('|'), isFalse);
    expect(ConversationFooterSymbols.isValidSymbol('*'), isFalse);
    expect(ConversationFooterSymbols.isValidSymbol('\u001B'), isFalse);
    expect(ConversationFooterSymbols.isValidSymbol('\u200B'), isFalse);
    expect(ConversationFooterSymbols.isValidSymbol('\u200D'), isFalse);
    expect(ConversationFooterSymbols.isValidSymbol('\uFE0F'), isFalse);
    expect(ConversationFooterSymbols.isValidSymbol('\u202E'), isFalse);
    expect(ConversationFooterSymbols.isValidSymbol('♥\u202E'), isFalse);
  });
}
