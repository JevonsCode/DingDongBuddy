import 'dart:convert';
import 'dart:io';

import 'package:dingdong/app/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, dynamic> english = _arb('en');
  final Map<String, dynamic> chinese = _arb('zh');
  final Map<String, dynamic> spanish = _arb('es');

  test('every locale has the same messages and resource metadata', () {
    expect(chinese.keys.toSet(), english.keys.toSet());
    expect(spanish.keys.toSet(), english.keys.toSet());

    for (final String key in english.keys.where(
      (String key) => !key.startsWith('@'),
    )) {
      expect(english['@$key'], isA<Map<String, dynamic>>(), reason: key);
      final Map<String, dynamic> enMetadata =
          english['@$key'] as Map<String, dynamic>;
      final Map<String, dynamic> zhMetadata =
          chinese['@$key'] as Map<String, dynamic>;
      final Map<String, dynamic> esMetadata =
          spanish['@$key'] as Map<String, dynamic>;
      expect(
        zhMetadata['placeholders'],
        enMetadata['placeholders'],
        reason: key,
      );
      expect(
        esMetadata['placeholders'],
        enMetadata['placeholders'],
        reason: key,
      );
    }
  });

  test('Spanish is complete instead of silently falling back to English', () {
    const intentionallyShared = <String>{
      'actionCountTimes',
      'categoryRuleKeywordsExample',
      'general',
      'hoursHCount',
      'httpsExampleComDingdongResourcesJson',
      'local',
      'localAPI',
      'manual',
      'prompt',
      'prompts',
      'skill',
      'skill2',
      'skills',
    };
    final shared = english.keys
        .where((String key) => !key.startsWith('@'))
        .where((String key) => english[key] == spanish[key])
        .toSet();

    expect(shared, intentionallyShared);
  });

  test('generated locale registry exposes English, Chinese, and Spanish', () {
    expect(
      DingDongLocalizations.supportedLocales
          .map((locale) => locale.languageCode)
          .toList(),
      <String>['en', 'zh', 'es'],
    );
  });

  test('legacy two-language selectors cannot return to Dart UI code', () {
    final source = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .where((File file) => !file.path.contains('/l10n/generated/'))
        .map((File file) => file.readAsStringSync())
        .join('\n');

    expect(source, isNot(contains('.localized(')));
    expect(source, isNot(contains('_localized(')));
    expect(source, isNot(contains('englishLabel')));
    expect(source, isNot(contains('chineseLabel')));
    expect(source, isNot(contains('useChinese')));
    expect(source, isNot(matches(RegExp(r'''confirmButtonText:\s*['"]'''))));
    expect(source, isNot(contains("title: 'Agent API'")));
    expect(source, isNot(contains("hintText: 'command, alias:build'")));
    expect(source, isNot(contains("hintText: 'HTTPS or GitHub file URL'")));
  });

  test('native macOS localization tables keep matching locale key sets', () {
    for (final String table in <String>[
      'AccessibilityPermissionAssistant',
      'AppDelegate',
      'InfoPlist',
    ]) {
      final Set<String> en = _nativeKeys('en', table);
      expect(_nativeKeys('zh-Hans', table), en, reason: table);
      expect(_nativeKeys('es', table), en, reason: table);
    }
  });
}

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _nativeKeys(String locale, String table) {
  final String source = File(
    'macos/Runner/$locale.lproj/$table.strings',
  ).readAsStringSync();
  return RegExp(
    r'^"([^"]+)"\s*=',
    multiLine: true,
  ).allMatches(source).map((Match match) => match.group(1)!).toSet();
}
