import 'dart:convert';

import 'package:dingdong/platform/multi_window_settings_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const windows = MethodChannel('mixin.one/desktop_multi_window');
  const channels = MethodChannel('mixin.one/desktop_multi_window/channels');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('voice request creates settings with the selected issue', () async {
    MethodCall? created;
    messenger.setMockMethodCallHandler(windows, (call) async {
      if (call.method == 'getAllWindows') return <Object?>[];
      if (call.method == 'createWindow') {
        created = call;
        return 'settings';
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(windows, null));
    await MultiWindowSettingsLauncher(parentWindowId: 'main').showVoice(24);
    final config = created!.arguments as Map;
    final args = jsonDecode(config['arguments'] as String) as Map;
    expect(args['kind'], 'settings');
    expect(args['destination'], 'voice');
    expect(args['voiceIssueNumber'], 24);
  });

  test(
    'voice request focuses an existing settings window with the selected issue',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(windows, (call) async {
        if (call.method == 'getAllWindows') {
          return [
            {
              'windowId': 'settings',
              'windowArgument': jsonEncode({'kind': 'settings'}),
            },
          ];
        }
        return null;
      });
      messenger.setMockMethodCallHandler(channels, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(windows, null);
        messenger.setMockMethodCallHandler(channels, null);
      });
      await MultiWindowSettingsLauncher(parentWindowId: 'main').showVoice(24);
      final invocation = calls.single.arguments as Map;
      expect(invocation['method'], 'window_focus_voice');
      expect(invocation['arguments'], 24);
    },
  );
  test('rapid requests wait for a newly created settings handler', () async {
    var enumerations = 0;
    var attempts = 0;
    final delivered = <int>[];
    messenger.setMockMethodCallHandler(windows, (call) async {
      if (call.method == 'getAllWindows') {
        enumerations++;
        return enumerations == 1
            ? <Object?>[]
            : [
                {
                  'windowId': 'settings',
                  'windowArgument': jsonEncode({'kind': 'settings'}),
                },
              ];
      }
      if (call.method == 'createWindow') return 'settings';
      return null;
    });
    messenger.setMockMethodCallHandler(channels, (call) async {
      attempts++;
      if (attempts == 1) throw PlatformException(code: 'CHANNEL_UNREGISTERED');
      final invocation = call.arguments as Map;
      delivered.add(invocation['arguments'] as int);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(windows, null);
      messenger.setMockMethodCallHandler(channels, null);
    });
    final launcher = MultiWindowSettingsLauncher(parentWindowId: 'main');
    await Future.wait([launcher.showVoice(24), launcher.showVoice(23)]);
    expect(attempts, 2);
    expect(delivered, [23]);
  });
}
