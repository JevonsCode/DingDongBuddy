@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/widgets/desktop_back_to_top.dart';
import 'package:dingdong/core/widgets/desktop_selection_button.dart';
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
    testWidgets('shared list controls ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(560, 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controllers = [ScrollController(), ScrollController()];
      for (final controller in controllers) {
        addTearDown(controller.dispose);
      }
      // Synthetic rows for component comparison, no personal clipboard data.
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark
              ? AppTheme.desktopPanelDark()
              : AppTheme.desktopPanelLight(),
          locale: const Locale('en'),
          supportedLocales: DingDongLocalizations.supportedLocales,
          localizationsDelegates: DingDongLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Row(
              children: [
                for (var i = 0; i < 2; i++)
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(i == 0 ? 'Activity' : 'Clipboard'),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              ListView.builder(
                                controller: controllers[i],
                                itemCount: 40,
                                itemExtent: 32,
                                itemBuilder: (_, index) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text('Item $index'),
                                ),
                              ),
                              DesktopBackToTop(controller: controllers[i]),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DesktopSelectionButton(
                              selected: false,
                              onPressed: () {},
                            ),
                            DesktopSelectionButton(
                              selected: true,
                              onPressed: () {},
                            ),
                            const SizedBox(width: 12),
                            const DesktopSelectionButton(
                              selected: false,
                              onPressed: null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      for (final controller in controllers) {
        controller.jumpTo(400);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'goldens/shared_list_controls_${dark ? 'dark' : 'light'}.png',
        ),
      );
    });
  }
}
