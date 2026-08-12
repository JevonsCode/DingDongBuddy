import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desktop alerts use the compact shared modal treatment', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (BuildContext context) => DesktopAlertDialog(
                title: const Text('Delete this item?'),
                content: const Text('This cannot be undone.'),
                actions: <Widget>[
                  TextButton(onPressed: () {}, child: const Text('Cancel')),
                  FilledButton(
                    style: DesktopDialogStyle.destructiveButtonStyle(context),
                    onPressed: () {},
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final Dialog dialog = tester.widget<Dialog>(find.byType(Dialog));
    final RoundedRectangleBorder shape =
        dialog.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(14));
    expect(shape.side, BorderSide.none);
    expect(dialog.elevation, 10);

    final ConstrainedBox frame = tester
        .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
        .singleWhere(
          (ConstrainedBox box) =>
              box.constraints.minWidth == 420 &&
              box.constraints.maxWidth == 420,
        );
    expect(frame.constraints.maxHeight, greaterThan(240));

    final Size cancelSize = tester.getSize(
      find.widgetWithText(TextButton, 'Cancel'),
    );
    final Size deleteSize = tester.getSize(
      find.widgetWithText(FilledButton, 'Delete'),
    );
    expect(cancelSize.width, isNot(closeTo(deleteSize.width, 0.01)));
    expect(cancelSize.height, 34);
    expect(deleteSize.height, 34);

    final FilledButton delete = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete'),
    );
    expect(
      delete.style?.backgroundColor?.resolve(<WidgetState>{}),
      Theme.of(tester.element(find.byType(Dialog))).colorScheme.error,
    );

    final ThemeData dialogTheme = Theme.of(tester.element(find.byType(Dialog)));
    expect(
      dialogTheme.filledButtonTheme.style?.splashFactory,
      NoSplash.splashFactory,
    );
    expect(
      dialogTheme.filledButtonTheme.style?.overlayColor?.resolve(<WidgetState>{
        WidgetState.hovered,
      }),
      Colors.transparent,
    );
  });

  testWidgets('dialog densities expose alert, chooser, and editor spacing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const DesktopDialogFrame(
          width: 620,
          density: DesktopDialogDensity.editor,
          header: DesktopDialogHeader(
            title: Text('Edit resource'),
            density: DesktopDialogDensity.editor,
          ),
          body: Text('Editor body'),
          footer: DesktopDialogFooter(
            density: DesktopDialogDensity.editor,
            actions: <Widget>[TextButton(onPressed: null, child: Text('Save'))],
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Padding &&
            widget.padding == const EdgeInsets.fromLTRB(24, 20, 24, 24),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Container &&
            widget.padding == const EdgeInsets.fromLTRB(24, 22, 18, 18),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(find.widgetWithText(TextButton, 'Save')).height, 36);
  });
}
