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
    expect(shape.borderRadius, BorderRadius.circular(18));
    expect(shape.side, BorderSide.none);
    expect(dialog.elevation, 12);

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
    expect(cancelSize.width, closeTo(deleteSize.width, 0.01));
    expect(cancelSize.height, 38);
    expect(deleteSize.height, 38);

    final FilledButton delete = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete'),
    );
    expect(
      delete.style?.backgroundColor?.resolve(<WidgetState>{}),
      Theme.of(tester.element(find.byType(Dialog))).colorScheme.error,
    );
  });
}
