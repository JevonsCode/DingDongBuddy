import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_content_launcher.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_preview_app.dart';
import 'package:dingdong/platform/multi_window_clipboard_preview_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'QR Escape hides the large window and focuses its detail window',
    (WidgetTester tester) async {
      const String qrWindowId = 'qr-preview-focus-test';
      const String detailWindowId = 'detail-preview-focus-test';
      final _WindowCalls calls = _installWindowMocks(
        tester,
        currentWindowId: qrWindowId,
      );

      await tester.pumpWidget(
        ClipboardQrPreviewApp(
          initialRecord: _record(),
          parentWindowId: detailWindowId,
          windowController: WindowController.fromWindowId(qrWindowId),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(calls.hasWindowCall('window_hide', qrWindowId), isTrue);
      expect(calls.hasWindowCall('window_show', detailWindowId), isTrue);
      expect(
        calls.hasChannelCall(
          channel: 'mixin.one/window_controller/$detailWindowId',
          method: clipboardPreviewFocusWindowMethod,
        ),
        isTrue,
      );
    },
  );

  testWidgets('detail Escape hides the focused detail window', (
    WidgetTester tester,
  ) async {
    const String detailWindowId = 'detail-preview-escape-test';
    final _WindowCalls calls = _installWindowMocks(
      tester,
      currentWindowId: detailWindowId,
    );

    await tester.pumpWidget(
      ClipboardPreviewApp(
        initialRecord: _record(),
        windowController: WindowController.fromWindowId(detailWindowId),
        clipboardGateway: _NoopClipboardGateway(),
        contentLauncher: _NoopClipboardContentLauncher(),
        shareGateway: null,
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(calls.hasWindowCall('window_hide', detailWindowId), isTrue);
  });
}

_WindowCalls _installWindowMocks(
  WidgetTester tester, {
  required String currentWindowId,
}) {
  const MethodChannel windows = MethodChannel('mixin.one/desktop_multi_window');
  const MethodChannel channels = MethodChannel(
    'mixin.one/desktop_multi_window/channels',
  );
  final List<MethodCall> windowCalls = <MethodCall>[];
  final List<MethodCall> channelCalls = <MethodCall>[];
  final TestDefaultBinaryMessenger messenger =
      tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(windows, (MethodCall call) async {
    if (call.method == 'getWindowDefinition') {
      return <String, String>{
        'windowId': currentWindowId,
        'windowArgument': '',
      };
    }
    if (call.method == 'getAllWindows') return <Object?>[];
    windowCalls.add(call);
    return null;
  });
  messenger.setMockMethodCallHandler(channels, (MethodCall call) async {
    channelCalls.add(call);
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(windows, null);
    messenger.setMockMethodCallHandler(channels, null);
  });
  return _WindowCalls(windowCalls: windowCalls, channelCalls: channelCalls);
}

final class _WindowCalls {
  const _WindowCalls({required this.windowCalls, required this.channelCalls});

  final List<MethodCall> windowCalls;
  final List<MethodCall> channelCalls;

  bool hasWindowCall(String method, String windowId) =>
      windowCalls.any((MethodCall call) {
        final Object? arguments = call.arguments;
        return call.method == method &&
            arguments is Map<Object?, Object?> &&
            arguments['windowId'] == windowId;
      });

  bool hasChannelCall({required String channel, required String method}) =>
      channelCalls.any((MethodCall call) {
        final Object? arguments = call.arguments;
        return call.method == 'invokeMethod' &&
            arguments is Map<Object?, Object?> &&
            arguments['channel'] == channel &&
            arguments['method'] == method;
      });
}

final class _NoopClipboardGateway implements ClipboardGateway {
  @override
  Future<ClipboardSnapshot> read() async => const ClipboardSnapshot();

  @override
  Future<void> writeFiles(List<String> paths) async {}

  @override
  Future<void> writeText(String text) async {}
}

final class _NoopClipboardContentLauncher implements ClipboardContentLauncher {
  @override
  Future<void> open(ClipboardRecord record) async {}
}

ClipboardRecord _record() {
  final DateTime now = DateTime.utc(2026, 8, 3);
  return ClipboardRecord(
    id: 'qr-focus',
    group: 'URLs',
    title: 'DingDong',
    content: 'https://example.com',
    tags: const <String>['clipboard', 'url'],
    pinned: false,
    enabled: true,
    activation: 'taskMatch',
    createdAt: now,
    updatedAt: now,
  );
}
