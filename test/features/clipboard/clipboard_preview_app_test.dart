import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_qr_payload.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_preview_app.dart';
import 'package:dingdong/platform/multi_window_clipboard_preview_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
              sources: const <String>['Cursor', 'Google Chrome'],
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
    expect(find.text('Google Chrome'), findsOneWidget);
    expect(find.text('分享'), findsOneWidget);
  });

  testWidgets('preview hides share when no platform handler is available', (
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
              title: 'Preview item',
              content: 'Preview content',
              tags: const <String>['clipboard', 'text'],
              pinned: false,
              enabled: true,
              activation: 'taskMatch',
              createdAt: now,
              updatedAt: now,
            ),
            onCopy: () {},
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.text('复制'), findsOneWidget);
    expect(find.text('分享'), findsNothing);
  });

  testWidgets('preview exposes the shared system-open action', (
    WidgetTester tester,
  ) async {
    var openCount = 0;
    final DateTime now = DateTime.utc(2026, 8, 3);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 304,
          height: 420,
          child: ClipboardPreviewCard(
            record: ClipboardRecord(
              id: 'link-preview',
              group: 'URLs',
              title: 'DingDong',
              content: 'https://example.com',
              tags: const <String>['clipboard', 'url'],
              pinned: false,
              enabled: true,
              activation: 'taskMatch',
              createdAt: now,
              updatedAt: now,
            ),
            onCopy: () {},
            onOpen: () => openCount += 1,
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('clipboard-preview-open')));
    await tester.pump();

    expect(openCount, 1);
    expect(find.text('打开'), findsOneWidget);
  });

  testWidgets('preview shows a QR action only for encodable content', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 8, 3);
    var qrExpandCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: const Key('clipboard-preview-window-frame'),
            width: clipboardPreviewWindowSize.width,
            height: clipboardPreviewWindowSize.height,
            child: ClipboardPreviewCard(
              record: ClipboardRecord(
                id: 'qr-preview',
                group: 'URLs',
                title: 'DingDong',
                content: 'https://example.com',
                tags: const <String>['clipboard', 'url', 'sensitive'],
                pinned: false,
                enabled: true,
                activation: 'taskMatch',
                createdAt: now,
                updatedAt: now,
              ),
              onCopy: () {},
              onOpen: () {},
              onShare: () {},
              onQrExpand: () async => qrExpandCount += 1,
              onClose: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('clipboard-preview-qr')), findsOneWidget);
    expect(find.text('二维码'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    final Rect copyRect = tester.getRect(
      find.byKey(const Key('clipboard-preview-copy')),
    );
    final Rect openRect = tester.getRect(
      find.byKey(const Key('clipboard-preview-open')),
    );
    final Rect shareRect = tester.getRect(
      find.byKey(const Key('clipboard-preview-share')),
    );
    final Rect qrRect = tester.getRect(
      find.byKey(const Key('clipboard-preview-qr')),
    );
    expect(copyRect.top, openRect.top);
    expect(shareRect.top, qrRect.top);
    expect(shareRect.top, greaterThan(copyRect.bottom));
    expect(copyRect.width, closeTo(openRect.width, 0.01));
    expect(shareRect.width, closeTo(qrRect.width, 0.01));

    await tester.tap(find.byKey(const Key('clipboard-preview-qr')));
    await tester.pump();

    expect(find.byKey(const Key('clipboard-preview-qr-view')), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('扫码分享 · 点击放大'), findsOneWidget);
    expect(find.byTooltip('点击放大二维码'), findsOneWidget);
    final Size compactQrSize = tester.getSize(
      find.byKey(const Key('clipboard-preview-qr-view')),
    );

    await tester.tap(find.byKey(const Key('clipboard-preview-qr-expand')));
    await tester.pump();

    expect(qrExpandCount, 1);
    expect(
      find.byKey(const Key('clipboard-preview-qr-expanded')),
      findsNothing,
    );
    expect(
      tester.getSize(find.byKey(const Key('clipboard-preview-window-frame'))),
      clipboardPreviewWindowSize,
    );
    expect(find.byKey(const Key('clipboard-preview-qr-view')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('clipboard-preview-qr-view'))),
      compactQrSize,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('large QR preview is a separate closeable image surface', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 740);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final DateTime now = DateTime.utc(2026, 8, 3);
    final ClipboardQrData data = clipboardQrData(
      ClipboardRecord(
        id: 'large-qr-preview',
        group: 'URLs',
        title: 'DingDong',
        content: 'https://example.com',
        tags: const <String>['clipboard', 'url'],
        pinned: false,
        enabled: true,
        activation: 'taskMatch',
        createdAt: now,
        updatedAt: now,
      ),
    )!;
    var closeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: clipboardQrPreviewWindowSize.width,
            height: clipboardQrPreviewWindowSize.height,
            child: ClipboardQrPreviewCard(
              data: data,
              onClose: () => closeCount += 1,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('clipboard-preview-qr-expanded')),
      findsOneWidget,
    );
    expect(find.text('点击任意处关闭大图 · Esc'), findsOneWidget);
    expect(find.byTooltip('关闭大图'), findsOneWidget);
    expect(
      tester.getSize(
        find.byKey(const Key('clipboard-preview-qr-expanded-view')),
      ),
      const Size.square(572),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 460,
            child: ClipboardQrPreviewCard(
              data: data,
              onClose: () => closeCount += 1,
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(
        find.byKey(const Key('clipboard-preview-qr-expanded-view')),
      ),
      const Size.square(352),
    );

    await tester.tap(
      find.byKey(const Key('clipboard-preview-qr-expanded-view')),
    );
    await tester.pump();

    expect(closeCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview hides QR for file-backed content', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 8, 3);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 304,
          height: 420,
          child: ClipboardPreviewCard(
            record: ClipboardRecord(
              id: 'file-preview',
              group: 'Files',
              title: 'Report',
              content: '/tmp/report.pdf',
              tags: const <String>['clipboard', 'file'],
              pinned: false,
              enabled: true,
              activation: 'taskMatch',
              createdAt: now,
              updatedAt: now,
            ),
            onCopy: () {},
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('clipboard-preview-qr')), findsNothing);
    expect(find.text('二维码'), findsNothing);
  });
}
