import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/features/screenshot/ui/screenshot_editor_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

Future<Uint8List> imageBytes() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 2400, 240),
    Paint()..color = Colors.blue,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(2400, 240);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  late Uint8List bytes;
  setUpAll(() async {
    bytes = await imageBytes();
    if (const bool.fromEnvironment('SCREENSHOT_PREVIEW')) {
      for (final family in ['Segoe UI', 'Roboto', 'Ahem']) {
        await (FontLoader(family)..addFont(
              Future.value(
                ByteData.sublistView(
                  File('C:/Windows/Fonts/msyh.ttc').readAsBytesSync(),
                ),
              ),
            ))
            .load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  Future<void> open(
    WidgetTester tester, {
    required Future<void> Function() close,
    Future<void> Function(Uint8List)? copy,
    Future<bool> Function(Uint8List)? save,
    Future<String?> Function()? selectSavePath,
    bool Function()? isCaptureCurrent,
    Future<Uint8List> Function()? captureImage,
  }) async {
    tester.view.physicalSize = const Size(1120, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.desktopPanelLight(),
        home: RepaintBoundary(
          key: const ValueKey('editor-preview'),
          child: ScreenshotEditor(
            bytes: bytes,
            language: 'zh',
            onClose: close,
            copyImage: copy,
            saveImage: save,
            selectSavePath: selectSavePath,
            isCaptureCurrent: isCaptureCurrent,
            captureImage: captureImage,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      tester
          .state<ProImageEditorState>(find.byType(ProImageEditor))
          .decodeImage,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'desktop tools contain focused annotation modes and Chinese labels',
    (tester) async {
      await open(tester, close: () async {});
      expect(find.text('复制图片'), findsOneWidget);
      expect(find.text('另存为'), findsOneWidget);
      expect(find.text('标注 / 遮挡'), findsOneWidget);
      expect(find.text('Filter'), findsNothing);
      if (const bool.fromEnvironment('SCREENSHOT_PREVIEW')) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('editor-preview')),
          );
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'build/screenshot-editor-preview.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('标注 / 遮挡'));
      await tester.pumpAndSettle();
      for (final label in ['箭头', '矩形', '椭圆', '画笔', '马赛克', '模糊', '线宽']) {
        expect(find.text(label), findsOneWidget);
      }
      if (const bool.fromEnvironment('SCREENSHOT_PREVIEW')) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('editor-preview')),
          );
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'build/screenshot-paint-preview.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'copy preserves physical PNG dimensions above default 2000px cap',
    (tester) async {
      Uint8List? exported;
      var closed = 0;
      await open(
        tester,
        close: () async {
          closed++;
        },
        copy: (value) async {
          exported = value;
        },
      );
      await tester.tap(find.text('复制图片'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();
      expect(exported, isNotNull);
      expect(exported!.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final data = ByteData.sublistView(exported!);
      expect(data.getUint32(16), 2400);
      expect(data.getUint32(20), 240);
      expect(closed, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('edited export preserves physical pixels and undo/redo history', (
    tester,
  ) async {
    Uint8List? exported;
    await open(
      tester,
      close: () async {},
      copy: (value) async {
        exported = value;
      },
    );
    final editor = tester.state<ProImageEditorState>(
      find.byType(ProImageEditor),
    );
    editor.addLayer(
      TextLayer(text: 'TEST', color: Colors.red),
      blockSelectLayer: true,
    );
    await tester.pumpAndSettle();
    expect(editor.canUndo, isTrue);
    editor.undoAction();
    await tester.pumpAndSettle();
    expect(editor.canRedo, isTrue);
    editor.redoAction();
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制图片'));
    for (var i = 0; i < 50 && exported == null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    expect(exported, isNotNull);
    final data = ByteData.sublistView(exported!);
    expect(data.getUint32(16), 2400);
    expect(data.getUint32(20), 240);
    expect(exported, isNot(orderedEquals(bytes)));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'a save picker returning after disposal cannot write the old capture',
    (tester) async {
      final chosenPath = Completer<String?>();
      final opened = Completer<void>();
      final directory = Directory.systemTemp.createTempSync(
        'dingdong-stale-capture-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final output = File('${directory.path}/stale.png');
      var closed = 0;
      await open(
        tester,
        close: () async {
          closed++;
        },
        selectSavePath: () {
          opened.complete();
          return chosenPath.future;
        },
      );
      await tester.tap(find.text('另存为'));
      await tester.runAsync(() async {
        await opened.future.timeout(const Duration(seconds: 3));
      });
      // Mirrors plugin disable, which clears the image and disposes this editor.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      chosenPath.complete(output.path);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(output.existsSync(), isFalse);
      expect(closed, 0);
    },
  );

  testWidgets(
    'invalidated capture cannot save while its editor is still mounted',
    (tester) async {
      final chosenPath = Completer<String?>();
      final opened = Completer<void>();
      final directory = Directory.systemTemp.createTempSync('dingdong-cancel-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final output = File('${directory.path}/stale.png');
      var current = true;
      var closed = 0;
      await open(
        tester,
        close: () async {
          closed++;
        },
        isCaptureCurrent: () => current,
        selectSavePath: () {
          opened.complete();
          return chosenPath.future;
        },
      );
      await tester.tap(find.text('另存为'));
      await tester.runAsync(() async {
        await opened.future.timeout(const Duration(seconds: 3));
      });
      // Dismiss/disable invalidates synchronously, before any teardown frame.
      current = false;
      chosenPath.complete(output.path);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(find.byType(ScreenshotEditor), findsOneWidget);
      expect(output.existsSync(), isFalse);
      expect(closed, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('invalidated export never writes to the clipboard', (
    tester,
  ) async {
    var current = true;
    var copied = 0;
    var closed = 0;
    final rendered = Completer<Uint8List>();
    await open(
      tester,
      close: () async {
        closed++;
      },
      isCaptureCurrent: () => current,
      copy: (_) async {
        copied++;
      },
      captureImage: () => rendered.future,
    );
    await tester.tap(find.text('复制图片'));
    current = false;
    rendered.complete(bytes);
    await tester.idle();
    await tester.pumpAndSettle();
    expect(copied, 0);
    expect(closed, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('cancelled save and failed copy retain the editor for retry', (
    tester,
  ) async {
    var closed = 0;
    await open(
      tester,
      close: () async {
        closed++;
      },
      save: (_) async => false,
      copy: (_) async {
        throw StateError('clipboard busy');
      },
    );
    await tester.tap(find.text('另存为'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pumpAndSettle();
    expect(closed, 0);
    await tester.tap(find.text('复制图片'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pumpAndSettle();
    expect(closed, 0);
    expect(find.text('导出失败，编辑内容仍保留，请重试。'), findsOneWidget);
    expect(find.byType(ProImageEditor), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
