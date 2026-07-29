import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'English and Chinese READMEs publish shortcuts and setting defaults',
    () {
      final String english = File('README.md').readAsStringSync();
      final String chinese = File('README.zh.md').readAsStringSync();

      expect(english, contains('## Default shortcuts and settings'));
      expect(english, contains('`⌘⇧V` (configurable)'));
      expect(english, contains('`Ctrl+Shift+V` (configurable)'));
      expect(english, contains('| Window opacity | 90% | 82%–96% |'));
      expect(
        english,
        contains('| Clipboard retention | 5,000 items, 120 days |'),
      );
      expect(chinese, contains('## 默认快捷键和设置'));
      expect(chinese, contains('`⌘⇧V`（可配置）'));
      expect(chinese, contains('`Ctrl+Shift+V`（可配置）'));
      expect(chinese, contains('| 窗口透明度 | 90% | 82%–96% |'));
      expect(chinese, contains('| 剪贴板保留 | 5000 条、120 天 |'));
    },
  );

  test('website publishes the same bilingual defaults reference', () {
    final String website = File('docs/index.html').readAsStringSync();
    final String styles = File('docs/styles.css').readAsStringSync();

    expect(website, contains('id="defaults"'));
    expect(website, contains('Settings → Keyboard shortcuts'));
    expect(website, contains('设置 → 键盘快捷键'));
    expect(website, contains('<kbd>⌘⇧V</kbd>'));
    expect(website, contains('<kbd>Ctrl+Shift+V</kbd>'));
    expect(website, contains('settings.retentionDefault'));
    expect(website, contains('settings.apiPortOptions'));
    expect(styles, contains('.defaults-grid'));
    expect(styles, contains('.defaults-panel table'));
  });
}
