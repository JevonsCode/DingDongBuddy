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

    final AlertDialog dialog = tester.widget<AlertDialog>(
      find.byType(AlertDialog),
    );
    final RoundedRectangleBorder shape =
        dialog.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(14));
    expect(shape.side.style, BorderStyle.solid);
    expect(dialog.elevation, 3);
    expect(dialog.constraints?.maxWidth, 460);
    expect(dialog.titlePadding, const EdgeInsets.fromLTRB(20, 18, 20, 0));
    expect(dialog.titleTextStyle?.fontSize, 16);
    expect(dialog.titleTextStyle?.fontWeight, FontWeight.w700);
    expect(dialog.actionsPadding, const EdgeInsets.fromLTRB(14, 8, 14, 14));

    final FilledButton delete = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete'),
    );
    expect(
      delete.style?.backgroundColor?.resolve(<WidgetState>{}),
      Theme.of(tester.element(find.byType(AlertDialog))).colorScheme.error,
    );
  });
}
