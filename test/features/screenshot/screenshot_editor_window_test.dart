import 'dart:async';
import 'dart:ui' as ui;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/features/screenshot/ui/screenshot_editor_app.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const manager = MethodChannel('window_manager');
  const windows = MethodChannel('mixin.one/desktop_multi_window');
  const bridge = MethodChannel('mixin.one/desktop_multi_window/channels');

  void expectOpaqueBackground(WidgetTester tester, Size size) {
    final background = find.descendant(
      of: find.byType(ScreenshotEditorBackground),
      matching: find.byType(ColoredBox),
    );
    expect(background, findsOneWidget);
    expect(tester.getSize(background), size);
    expect(
      tester.renderObject<RenderBox>(background),
      paints..rect(color: const Color(0xFF1D282E)),
    );
    expect(tester.widget<ColoredBox>(background).color.a, 1);
  }

  testWidgets('startup paints opaque non-square scene before native resize', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final messenger = tester.binding.defaultBinaryMessenger;
    final nativeCalls = <String>[];
    // Stop at the first resize so the test never reaches native centering.
    final rasterized = Completer<void>();
    RenderBox? paintedBackground;
    Size? sizeAtResize;
    Map? resizeArguments;
    bool? needsPaintAtResize;
    messenger.setMockMethodCallHandler(manager, (call) async {
      nativeCalls.add(call.method);
      if (call.method == 'setBounds') {
        sizeAtResize = paintedBackground?.size;
        needsPaintAtResize = paintedBackground?.debugNeedsPaint;
        resizeArguments = call.arguments as Map;
        throw PlatformException(code: 'test-resize-reached');
      }
      if (call.method.startsWith('is')) return false;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(manager, null));
    Object? preparationError;
    final prepared =
        prepareScreenshotEditorWindow(
          waitForFirstRaster: () => rasterized.future,
        ).catchError((Object error) {
          preparationError = error;
        });
    expect(nativeCalls, isEmpty);
    await tester.pump();
    await tester.pump();
    expectOpaqueBackground(tester, const Size(800, 600));
    paintedBackground = tester.renderObject<RenderBox>(
      find.descendant(
        of: find.byType(ScreenshotEditorBackground),
        matching: find.byType(ColoredBox),
      ),
    );
    // A framework frame has completed, but resizing still waits for raster.
    expect(nativeCalls, isEmpty);
    rasterized.complete();
    await tester.pump();
    await prepared;
    expect(
      preparationError,
      isA<PlatformException>().having(
        (error) => error.code,
        'code',
        'test-resize-reached',
      ),
    );
    expect(sizeAtResize, const Size(800, 600));
    expect(needsPaintAtResize, false);
    expect(resizeArguments?['width'], 1120);
    expect(resizeArguments?['height'], 780);
    expect(nativeCalls, containsAllInOrder(['ensureInitialized', 'setBounds']));
    tester.view.physicalSize = const Size(1120, 780);
    await tester.pump();
    expectOpaqueBackground(tester, const Size(1120, 780));
  });

  testWidgets('hidden editor paints the new capture before showing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1120, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final recorder = ui.PictureRecorder();
    Canvas(
      recorder,
    ).drawRect(const Rect.fromLTWH(0, 0, 16, 8), Paint()..color = Colors.blue);
    final picture = recorder.endRecording();
    final image = await tester.runAsync(() => picture.toImage(16, 8));
    final data = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    final bytes = data!.buffer.asUint8List();
    image!.dispose();
    picture.dispose();
    final messenger = tester.binding.defaultBinaryMessenger;
    final showsWithFramesEnabled = <bool>[];
    final shownSessions = <Key?>[];
    final finishedSessions = <int>[];
    messenger.setMockMethodCallHandler(manager, (call) async {
      if (call.method.startsWith('is')) return false;
      if (call.method == 'show') {
        showsWithFramesEnabled.add(tester.binding.framesEnabled);
        shownSessions.add(
          tester.widget<ScreenshotEditor>(find.byType(ScreenshotEditor)).key,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
      return null;
    });
    messenger.setMockMethodCallHandler(windows, (call) async {
      if (call.method == 'getWindowDefinition') {
        return {'windowId': 'screenshot-reuse', 'windowArgument': ''};
      }
      if (call.method == 'window_hide') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(bridge, (call) async {
      if (call.method == 'invokeMethod') {
        final args = call.arguments as Map;
        if (args['method'] == 'read') return bytes;
        if (args['method'] == 'finish') {
          finishedSessions.add(args['arguments'] as int);
        }
      }
      return null;
    });
    addTearDown(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      messenger.setMockMethodCallHandler(manager, null);
      messenger.setMockMethodCallHandler(windows, null);
      messenger.setMockMethodCallHandler(bridge, null);
    });
    await tester.pumpWidget(
      ScreenshotEditorWindow(
        controller: WindowController.fromWindowId('screenshot-reuse'),
        initialSession: 1,
        settings: const AppSettings(),
        loadSettings: () async => const AppSettings(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ScreenshotEditor), findsOneWidget);
    expect(showsWithFramesEnabled, [true]);
    final firstEditor = tester.widget<ScreenshotEditor>(
      find.byType(ScreenshotEditor),
    );
    expect(firstEditor.isCaptureCurrent!(), true);
    final closed = firstEditor.onClose();
    // Invalidation does not depend on pumping the removal frame.
    expect(firstEditor.isCaptureCurrent!(), false);
    await closed;
    await tester.pump();
    expect(finishedSessions, [1]);
    expect(tester.binding.framesEnabled, false);
    expectOpaqueBackground(tester, const Size(1120, 780));
    tester.view.physicalSize = const Size(1536, 864);
    await tester.pump();
    expectOpaqueBackground(tester, const Size(1536, 864));
    // Invoke the real child-window load handler while frames are suspended.
    // idle flushes messages/microtasks without forcing a frame like pump does.
    const codec = StandardMethodCodec();
    final reopened = Completer<void>();
    ServicesBinding.instance.channelBuffers.push(
      bridge.name,
      codec.encodeMethodCall(
        const MethodCall('methodCall', {
          'channel': 'mixin.one/window_controller/screenshot-reuse',
          'method': 'load',
          'arguments': 2,
        }),
      ),
      (reply) {
        codec.decodeEnvelope(reply!);
        reopened.complete();
      },
    );
    await tester.idle();
    await tester.pumpAndSettle();
    expect(showsWithFramesEnabled, [true, false]);
    expect(shownSessions, [const ValueKey(1), const ValueKey(2)]);
    expect(reopened.isCompleted, true);
    await tester.pumpAndSettle();
    expect(find.byType(ScreenshotEditor), findsOneWidget);
    expect(
      tester.widget<ScreenshotEditor>(find.byType(ScreenshotEditor)).key,
      const ValueKey(2),
    );
    expect(tester.takeException(), isNull);
  });
}
