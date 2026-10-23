import 'dart:async';
import 'dart:convert';

import 'package:dingdong/platform/windows_selection_plugin_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const windows = MethodChannel('mixin.one/desktop_multi_window');
  const bridge = MethodChannel('mixin.one/desktop_multi_window/channels');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late MultiWindowSelectionOverlayHost host;
  late int creations;
  late List<String> liveWindows;
  late List<MethodCall> messages;
  Object? creationFailure;
  bool messageFails = false;
  bool lookupFails = false;
  bool hideFails = false;

  setUp(() {
    host = MultiWindowSelectionOverlayHost('main');
    creations = 0;
    liveWindows = [];
    messages = [];
    creationFailure = null;
    messageFails = lookupFails = hideFails = false;
    messenger.setMockMethodCallHandler(windows, (call) async {
      switch (call.method) {
        case 'createWindow':
          creations++;
          final args = call.arguments as Map;
          expect(args['hiddenAtLaunch'], isTrue);
          expect(jsonDecode(args['arguments'] as String), {
            'kind': selectionOverlayWindowKind,
            'parentWindowId': 'main',
          });
          if (creationFailure != null) throw creationFailure!;
          final id = 'child-$creations';
          liveWindows.add(id);
          return id;
        case 'getAllWindows':
          if (lookupFails) throw PlatformException(code: 'lookup-unavailable');
          return [
            for (final id in liveWindows)
              {'windowId': id, 'windowArgument': ''},
          ];
        case 'window_hide':
          if (hideFails) throw PlatformException(code: '-1');
          return null;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(bridge, (call) async {
      if (call.method == 'invokeMethod') {
        messages.add(call);
        if (messageFails) throw PlatformException(code: 'CHANNEL_NOT_FOUND');
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(windows, null);
    messenger.setMockMethodCallHandler(bridge, null);
  });

  test('a failed creation does not poison the next selection', () async {
    creationFailure = PlatformException(code: 'create-failed');
    await expectLater(
      host.present({'text': 'first'}),
      throwsA(isA<PlatformException>()),
    );
    creationFailure = null;
    await host.present({'text': 'second'});
    host.ready('child-2');
    await host.present({'text': 'second'});
    expect(creations, 2);
    expect((messages.single.arguments as Map)['arguments'], {'text': 'second'});
  });

  test(
    'concurrent callers share a failed creation but can retry later',
    () async {
      final result = Completer<String>();
      messenger.setMockMethodCallHandler(windows, (call) async {
        creations++;
        return result.future;
      });
      final first = expectLater(
        host.present({}),
        throwsA(isA<PlatformException>()),
      );
      final second = expectLater(
        host.present({}),
        throwsA(isA<PlatformException>()),
      );
      await Future<void>.delayed(Duration.zero);
    result.completeError(PlatformException(code: 'create-failed'));
      await Future.wait([first, second]);
      expect(creations, 1);
      messenger.setMockMethodCallHandler(windows, (call) async {
        creations++;
        return 'recovered';
      });
      await host.present({});
      expect(creations, 2);
    },
  );

  test(
    'a confirmed destroyed child is replaced only on the next selection',
    () async {
      await host.present({});
      host.ready('child-1');
      liveWindows.clear();
      messageFails = true;
      await expectLater(host.present({}), throwsA(anything));
      expect(creations, 1);
      messageFails = false;
      await host.present({});
      expect(creations, 2);
      host.ready('child-1'); // Delayed readiness must not target a new child.
      await host.present({});
      expect(messages, hasLength(1));
      host.ready('child-2');
      await host.present({'text': 'new'});
      expect((messages.last.arguments as Map)['channel'], endsWith('/child-2'));
    },
  );

  for (final uncertainLookup in [false, true]) {
    test(
      'a live or uncertain child is not duplicated ($uncertainLookup)',
      () async {
        await host.present({});
        host.ready('child-1');
        messageFails = true;
        lookupFails = uncertainLookup;
        await expectLater(host.present({}), throwsA(anything));
        messageFails = false;
        await host.present({});
        expect(creations, 1);
        expect(messages, hasLength(2));
      },
    );
  }

  test('a child destroyed before ready can be recreated', () async {
    await host.present({});
    liveWindows.clear();
    await host.present({});
    expect(creations, 2);
    expect(messages, isEmpty);
    host.ready('child-2');
    await host.present({'text': 'fresh'});
    expect(messages, hasLength(1));
  });

  test('hide clears a confirmed destroyed child and its readiness', () async {
    await host.present({});
    host.ready('child-1');
    liveWindows.clear();
    hideFails = true;
    await expectLater(host.hide(), throwsA(isA<PlatformException>()));
    await host.present({});
    expect(creations, 2);
    expect(messages, isEmpty);
  });
}
