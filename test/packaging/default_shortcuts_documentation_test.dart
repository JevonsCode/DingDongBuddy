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
      expect(english, contains('(individually configurable)'));
      expect(
        english,
        contains('| Select visible Clipboard group 1–5 | `⌃1`–`⌃5` |'),
      );
      expect(english, contains('| Use visible item 1–9 as plain text |'));
      expect(english, contains('| Window opacity | 90% | 82%–96% |'));
      expect(
        english,
        contains('| Clipboard retention | 5,000 items, 120 days |'),
      );
      expect(chinese, contains('## 默认快捷键和设置'));
      expect(chinese, contains('`⌘⇧V`（可配置）'));
      expect(chinese, contains('`Ctrl+Shift+V`（可配置）'));
      expect(chinese, contains('（可分别配置）'));
      expect(chinese, contains('| 选择当前可见的剪贴板分组 1–5 | `⌃1`–`⌃5` |'));
      expect(chinese, contains('| 以纯文本使用当前可见的第 1–9 条 |'));
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
    expect(website, contains('shortcuts.groups'));
    expect(website, contains('<kbd>⌃1–5</kbd>'));
    expect(website, contains('<kbd>Alt+1–5</kbd>'));
    expect(website, contains('shortcuts.groupMove'));
    expect(website, contains('settings.retentionDefault'));
    expect(website, contains('settings.apiPortOptions'));
    expect(styles, contains('.defaults-grid'));
    expect(styles, contains('.defaults-panel table'));
  });

  test('website and READMEs explain the Agent reply resource receipt', () {
    final String website = File('docs/index.html').readAsStringSync();
    final String english = File('README.md').readAsStringSync();
    final String chinese = File('README.zh.md').readAsStringSync();

    expect(website, contains('class="conversation-receipt"'));
    expect(
      website,
      contains('Every final reply leaves a little resource receipt.'),
    );
    expect(website, contains('每次答完，都留一张资源小票'));
    expect(website, contains('not necessarily called'));
    expect(website, contains('不代表工具已实际调用'));
    expect(
      english,
      contains('### A resource receipt at the end of each reply'),
    );
    expect(english, contains('not that a tool was actually called'));
    expect(chinese, contains('### 每次回复末尾，都有一张资源小票'));
    expect(chinese, contains('不代表工具已实际调用'));
  });
}
