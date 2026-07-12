import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/release_update.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:dingdong/features/settings/ui/settings_window_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reopening the settings window refreshes release metadata', (
    WidgetTester tester,
  ) async {
    const String windowId = 'settings-test';
    const MethodChannel windows = MethodChannel(
      'mixin.one/desktop_multi_window',
    );
    const MethodChannel channels = MethodChannel(
      'mixin.one/desktop_multi_window/channels',
    );
    const MethodChannel windowManager = MethodChannel('window_manager');
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(windows, (MethodCall call) async {
      if (call.method == 'getWindowDefinition') {
        return <String, String>{'windowId': windowId, 'windowArgument': ''};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(channels, (_) async => null);
    messenger.setMockMethodCallHandler(windowManager, (_) async => null);
    addTearDown(() async {
      messenger.setMockMethodCallHandler(windows, null);
      messenger.setMockMethodCallHandler(channels, null);
      messenger.setMockMethodCallHandler(windowManager, null);
    });
    final _CountingReleaseSource source = _CountingReleaseSource();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      releaseMetadataSource: source,
    );
    await tester.pumpWidget(
      SettingsWindowApp(
        viewModel: model,
        windowController: WindowController.fromWindowId(windowId),
      ),
    );
    await tester.pumpAndSettle();
    expect(source.fetchCount, 1);

    await _sendWindowMethod(
      messenger,
      channel: 'mixin.one/window_controller/$windowId',
      method: 'window_focus',
    );
    await tester.pumpAndSettle();

    expect(source.fetchCount, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Future<void> _sendWindowMethod(
  TestDefaultBinaryMessenger messenger, {
  required String channel,
  required String method,
}) async {
  final Completer<void> handled = Completer<void>();
  await messenger.handlePlatformMessage(
    'mixin.one/desktop_multi_window/channels',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall('methodCall', <String, Object?>{
        'channel': channel,
        'method': method,
        'arguments': null,
      }),
    ),
    (_) => handled.complete(),
  );
  await handled.future;
}

final class _CountingReleaseSource implements ReleaseMetadataSource {
  int fetchCount = 0;

  @override
  Future<ReleaseMetadata> fetch() async {
    fetchCount += 1;
    return ReleaseMetadata(
      app: 'DingDong',
      latestVersion: '0.8.0',
      website: Uri.parse('https://example.com'),
      releasePage: Uri.parse('https://example.com/releases/0.8.0'),
    );
  }
}
