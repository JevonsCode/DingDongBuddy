import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_category_rules_dialog.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('category rules remain complete in the management window', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 520);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(),
    )..load();
    addTearDown(model.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.desktopPanelLight(),
        locale: const Locale('zh'),
        supportedLocales: const <Locale>[Locale('en'), Locale('zh')],
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          DingDongLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (BuildContext context) => Center(
            child: FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ClipboardCategoryRulesDialog(viewModel: model),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final Finder dialog = find.byKey(
      const Key('clipboard-category-rules-dialog'),
    );
    final Rect dialogRect = tester.getRect(dialog);
    final Rect listRect = tester.getRect(
      find.byKey(const Key('clipboard-category-list-surface')),
    );

    expect(dialogRect.width, closeTo(620, 0.1));
    expect(dialogRect.height, lessThanOrEqualTo(472));
    expect(find.byType(CompactSwitch), findsNWidgets(4));
    expect(find.text('匹配顺序 · 上方优先'), findsOneWidget);
    expect(find.byType(Divider), findsNothing);

    for (final String id in <String>['links', 'images', 'files', 'text']) {
      final Rect copyRect = tester.getRect(
        find.byKey(Key('clipboard-category-copy-$id')),
      );
      final Rect actionsRect = tester.getRect(
        find.byKey(Key('clipboard-category-actions-$id')),
      );
      expect(copyRect.width, greaterThan(250));
      expect(copyRect.right, lessThanOrEqualTo(actionsRect.left - 8));
      expect(listRect.contains(copyRect.center), isTrue);
      expect(listRect.contains(actionsRect.center), isTrue);
    }

    final Rect lastRowRect = tester.getRect(
      find.byKey(const ValueKey<String>('clipboard-category-rule-text')),
    );
    expect(lastRowRect.bottom, lessThanOrEqualTo(listRect.bottom));

    expect(tester.takeException(), isNull);
  });
}
