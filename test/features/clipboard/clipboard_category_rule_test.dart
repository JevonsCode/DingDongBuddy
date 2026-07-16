import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_category_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a category rule combines type regex source and length conditions', () {
    final ClipboardCategoryRule rule = ClipboardCategoryRule(
      id: 'dingdong-links',
      name: 'DingDong links',
      kinds: const <ClipboardKind>{ClipboardKind.url},
      contentPattern: r'dingdong',
      sourcePattern: r'Chrome|Cursor',
      minCharacters: 10,
      maxCharacters: 200,
    );

    expect(
      rule.matches(
        _record(
          content: 'https://example.com/dingdong',
          tags: const <String>['clipboard', 'url'],
          source: 'Google Chrome · com.google.Chrome',
        ),
      ),
      isTrue,
    );
    expect(
      rule.matches(
        _record(
          content: 'https://example.com/other',
          tags: const <String>['clipboard', 'url'],
          source: 'Google Chrome · com.google.Chrome',
        ),
      ),
      isFalse,
    );
  });

  test('invalid regular expressions are reported and never match', () {
    const ClipboardCategoryRule rule = ClipboardCategoryRule(
      id: 'invalid',
      name: 'Invalid',
      contentPattern: '[',
    );

    expect(rule.validationError, isNotNull);
    expect(rule.matches(_record(content: 'anything')), isFalse);
  });

  test('default rules classify links images files and remaining text', () {
    final List<ClipboardCategoryRule> rules = ClipboardCategoryRule.defaults();

    String? category(ClipboardRecord record) => rules
        .where((ClipboardCategoryRule rule) => rule.matches(record))
        .firstOrNull
        ?.id;

    expect(
      category(
        _record(
          content: 'https://example.com',
          tags: const <String>['clipboard', 'url'],
        ),
      ),
      'links',
    );
    expect(
      category(
        _record(
          content: '/tmp/image.png',
          tags: const <String>['clipboard', 'image'],
        ),
      ),
      'images',
    );
    expect(category(_record(content: 'hello')), 'text');
  });
}

ClipboardRecord _record({
  required String content,
  List<String> tags = const <String>['clipboard', 'text'],
  String? source,
}) {
  final DateTime now = DateTime.utc(2026, 7, 16);
  return ClipboardRecord(
    id: content,
    group: '',
    title: content,
    content: content,
    tags: tags,
    source: source,
    pinned: false,
    enabled: true,
    activation: 'taskMatch',
    createdAt: now,
    updatedAt: now,
  );
}
