import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_preview_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preview close action uses the compact desktop control size', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 7, 16);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 304,
          height: 420,
          child: ClipboardPreviewCard(
            record: ClipboardRecord(
              id: 'preview',
              group: 'Clipboard',
              groups: const <String>['Project'],
              title: 'Preview item',
              content: 'Preview content',
              tags: const <String>['clipboard', 'text'],
              pinned: false,
              enabled: true,
              activation: 'taskMatch',
              source: 'Cursor',
              createdAt: now,
              updatedAt: now,
            ),
            onCopy: () {},
            onShare: () {},
            onClose: () {},
          ),
        ),
      ),
    );

    final Finder close = find.byKey(const Key('clipboard-preview-close'));
    expect(close, findsOneWidget);
    expect(tester.getSize(close), const Size.square(30));
    expect(find.byTooltip('关闭'), findsOneWidget);
    expect(find.text('text'), findsOneWidget);
    expect(find.text('Clipboard'), findsOneWidget);
    expect(find.text('Project'), findsOneWidget);
    expect(find.text('Cursor'), findsOneWidget);
  });
}
