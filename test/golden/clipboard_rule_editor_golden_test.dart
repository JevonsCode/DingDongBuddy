@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_category_rules_dialog.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final config =
        jsonDecode(await File('.dart_tool/package_config.json').readAsString())
            as Map;
    final sdk = Uri.parse('${config['flutterRoot']}/');
    for (final family in ['Roboto', '.AppleSystemUIFont', 'Segoe UI']) {
      final font = FontLoader(family);
      for (final face in [
        'Roboto-Regular.ttf',
        'Roboto-Medium.ttf',
        'Roboto-Bold.ttf',
      ]) {
        font.addFont(
          File.fromUri(
            sdk.resolve('bin/cache/artifacts/material_fonts/$face'),
          ).readAsBytes().then(ByteData.sublistView),
        );
      }
      await font.load();
    }
    await (FontLoader('MaterialIcons')..addFont(
          File.fromUri(
            sdk.resolve(
              'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ),
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });

  for (final dark in [false, true]) {
    for (final width in [390.0, 700.0]) {
      testWidgets('clipboard rule editor $dark $width', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 700);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model = ClipboardViewModel(InMemoryClipboardStore())..load();
        addTearDown(model.dispose);
        // Illustrative matching rule, independent of any user's clipboard.
        final rule = model.categoryRules.first.copyWith(
          name: 'Bookmarks',
          contentPattern: 'example\\.com',
        );
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark
                ? AppTheme.desktopPanelDark()
                : AppTheme.desktopPanelLight(),
            locale: const Locale('en'),
            localizationsDelegates:
                DingDongLocalizations.localizationsDelegates,
            supportedLocales: DingDongLocalizations.supportedLocales,
            home: Scaffold(
              body: ClipboardCategoryRulesDialog(
                viewModel: model,
                initialRule: rule,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
            'goldens/clipboard_rule_editor_${dark ? 'dark' : 'light'}_${width.toInt()}.png',
          ),
        );
      });
    }
  }
}
