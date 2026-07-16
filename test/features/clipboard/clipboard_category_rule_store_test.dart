import 'dart:io';

import 'package:dingdong/features/clipboard/data/clipboard_category_rule_store.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_category_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file store persists category rules without a migration layer', () {
    final Directory directory = Directory.systemTemp.createTempSync(
      'dingdong-category-rules-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final FileClipboardCategoryRuleStore store = FileClipboardCategoryRuleStore(
      File('${directory.path}/clipboard-category-rules.json'),
    );
    const ClipboardCategoryRule rule = ClipboardCategoryRule(
      id: 'project-links',
      name: 'Project links',
      contentPattern: r'github\.com',
    );

    store.save(const <ClipboardCategoryRule>[rule]);

    expect(store.load(), const <ClipboardCategoryRule>[rule]);
  });

  test('missing or malformed files fall back to current defaults', () {
    final Directory directory = Directory.systemTemp.createTempSync(
      'dingdong-category-rules-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final File file = File('${directory.path}/clipboard-category-rules.json');
    final FileClipboardCategoryRuleStore store = FileClipboardCategoryRuleStore(
      file,
    );

    expect(store.load(), ClipboardCategoryRule.defaults());
    file.writeAsStringSync('{"legacy": true}');
    expect(store.load(), ClipboardCategoryRule.defaults());
  });
}
