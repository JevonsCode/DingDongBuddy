import 'dart:async';
import 'dart:ui' as ui;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/features/selection/ui/selection_overlay_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'opaque startup raster precedes native changes and active frame precedes resize',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(480, 460);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final raster = Completer<void>();
      final events = <String>[];
      final nativeCalls = <MethodCall>[];
      const manager = MethodChannel('window_manager');
      const windows = MethodChannel('mixin.one/desktop_multi_window');
      const channels = MethodChannel('mixin.one/desktop_multi_window/channels');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(manager, (call) async {
        nativeCalls.add(call);
        events.add(call.method);
        if (call.method == 'isMinimized') return false;
        return null;
      });
      messenger.setMockMethodCallHandler(
        windows,
        (call) async => {'windowId': 'selection-test', 'windowArgument': ''},
      );
      messenger.setMockMethodCallHandler(channels, (call) async {
        final args = call.arguments as Map;
        if (call.method == 'invokeMethod' &&
            args['method'] == 'selection_ready') {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => events.add('active_frame'),
          );
          return {
            'active': true,
            'version': 1,
            'selectionId': 1,
            'action': 'translate',
            'text': 'selected source',
            'result': 'visible answer',
            'languageCode': 'en',
            'themeMode': 'light',
            'anchor': {
              'x': 10.0,
              'y': 10.0,
              'width': 40.0,
              'height': 20.0,
              'coordinateScale': 1.0,
              'workAreaX': 0.0,
              'workAreaY': 0.0,
              'workAreaWidth': 1920.0,
              'workAreaHeight': 1080.0,
            },
          };
        }
        if (call.method == 'invokeMethod' &&
            args['method'] == 'selection_action') {
          return {
            'active': false,
            'version': 2,
            'selectionId': 2,
            'text': '',
            'result': '',
          };
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(manager, null);
        messenger.setMockMethodCallHandler(windows, null);
        messenger.setMockMethodCallHandler(channels, null);
      });

      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: SelectionOverlayApp(
            windowController: WindowController.fromWindowId('selection-test'),
            parentWindowId: 'parent',
            waitForFirstRaster: () =>
                raster.future.then((_) => events.add('raster')),
          ),
        ),
      );
      await tester.pump();
      expect(nativeCalls, isEmpty);
      expect(find.byType(SelectionOverlayPanel), findsNothing);

      Future<void> expectOpaqueSurface() async {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final pixels = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          for (final point in [
            Offset.zero,
            const Offset(479, 0),
            const Offset(0, 459),
            const Offset(479, 459),
            const Offset(240, 230),
          ]) {
            final alpha =
                (point.dy.toInt() * image.width + point.dx.toInt()) * 4 + 3;
            expect(pixels!.getUint8(alpha), 255);
          }
          image.dispose();
        });
      }

      await expectOpaqueSurface();

      raster.complete();
      await tester.pumpAndSettle();
      expect(
        events.indexOf('raster'),
        lessThan(events.indexOf('ensureInitialized')),
      );
      expect(
        events.indexOf('raster'),
        lessThan(events.indexOf('setAsFrameless')),
      );
      expect(events.indexOf('active_frame'), greaterThanOrEqualTo(0));
      expect(
        events.indexOf('active_frame'),
        lessThan(events.indexOf('setBounds')),
      );
      expect(find.text('visible answer'), findsOneWidget);
      expect(nativeCalls.singleWhere((c) => c.method == 'show').arguments, {
        'inactive': true,
      });
      expect(nativeCalls.where((c) => c.method == 'focus'), isEmpty);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectionOverlayPanel), findsNothing);
      expect(find.text('selected source'), findsNothing);
      expect(find.text('visible answer'), findsNothing);
      expect(nativeCalls.last.method, 'hide');
      await expectOpaqueSurface();

      // Production hidden windows suppress normal frames. Deliver the native
      // message without tester.pump: only the overlay's explicit warm-up can
      // paint and finish its pre-resize barrier in this lifecycle state.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(tester.binding.framesEnabled, isFalse);
      try {
        const codec = StandardMethodCodec();
        final response = Completer<Object?>();
        // ignore: deprecated_member_use
        await messenger.handlePlatformMessage(
          channels.name,
          codec.encodeMethodCall(
            const MethodCall('methodCall', {
              'channel': 'mixin.one/window_controller/selection-test',
              'method': 'selection_state',
              'arguments': {
                'active': true,
                'version': 3,
                'selectionId': 3,
                'action': 'translate',
                'text': 'new source',
                'result': 'reopened answer',
                'languageCode': 'en',
                'themeMode': 'light',
                'anchor': {
                  'x': 20.0,
                  'y': 20.0,
                  'width': 40.0,
                  'height': 20.0,
                  'coordinateScale': 1.0,
                  'workAreaX': 0.0,
                  'workAreaY': 0.0,
                  'workAreaWidth': 1920.0,
                  'workAreaHeight': 1080.0,
                },
              },
            }),
          ),
          (reply) => response.complete(codec.decodeEnvelope(reply!)),
        );
        await response.future;
        expect(nativeCalls.where((c) => c.method == 'show'), hasLength(2));
        expect(nativeCalls.where((c) => c.method == 'setBounds'), hasLength(2));
        expect(nativeCalls.where((c) => c.method == 'focus'), isEmpty);
        expect(find.text('reopened answer'), findsOneWidget);
        expect(find.text('visible answer'), findsNothing);
      } finally {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
