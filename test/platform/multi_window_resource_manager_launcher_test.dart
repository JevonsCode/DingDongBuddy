import 'dart:convert';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:dingdong/platform/multi_window_resource_manager_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clipboard capture refreshes an open resource manager window', () async {
    const MethodChannel windows = MethodChannel(
      'mixin.one/desktop_multi_window',
    );
    const MethodChannel channels = MethodChannel(
      'mixin.one/desktop_multi_window/channels',
    );
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final List<MethodCall> channelCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(windows, (MethodCall call) async {
      if (call.method == 'getAllWindows') {
        return <Object?>[
          <String, String>{
            'windowId': 'settings-window',
            'windowArgument': jsonEncode(<String, String>{'kind': 'settings'}),
          },
          <String, String>{
            'windowId': 'resource-window',
            'windowArgument': jsonEncode(<String, String>{
              'kind': resourceManagerWindowKind,
            }),
          },
        ];
      }
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

    await const MultiWindowResourceManagerLauncher(
      parentWindowId: 'main-window',
    ).refreshClipboard();

    expect(channelCalls, hasLength(1));
    expect(channelCalls.single.method, 'invokeMethod');
    expect(channelCalls.single.arguments, <String, Object?>{
      'channel': 'mixin.one/window_controller/resource-window',
      'method': 'clipboard_changed',
      'arguments': null,
    });
  });

  test('prompt creation focuses an open manager and sends the draft', () async {
    const MethodChannel windows = MethodChannel(
      'mixin.one/desktop_multi_window',
    );
    const MethodChannel channels = MethodChannel(
      'mixin.one/desktop_multi_window/channels',
    );
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final List<MethodCall> channelCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(windows, (MethodCall call) async {
      if (call.method == 'getAllWindows') {
        return <Object?>[
          <String, String>{
            'windowId': 'resource-window',
            'windowArgument': jsonEncode(<String, String>{
              'kind': resourceManagerWindowKind,
            }),
          },
        ];
      }
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

    const ResourceManagerCreateRequest request = ResourceManagerCreateRequest(
      type: ResourceType.prompt,
      title: 'Clipboard draft',
      content: 'Review this before saving.',
    );
    await const MultiWindowResourceManagerLauncher(
      parentWindowId: 'main-window',
    ).show(createRequest: request);

    final List<MethodCall> invocations = channelCalls
        .where((MethodCall call) => call.method == 'invokeMethod')
        .toList();
    expect(
      invocations.map(
        (MethodCall call) =>
            (call.arguments as Map<Object?, Object?>)['method'],
      ),
      containsAll(<String>['window_focus', 'create_resource']),
    );
    final MethodCall creation = invocations.firstWhere(
      (MethodCall call) =>
          (call.arguments as Map<Object?, Object?>)['method'] ==
          'create_resource',
    );
    expect(
      (creation.arguments as Map<Object?, Object?>)['arguments'],
      request.toJson(),
    );
  });

  test(
    'category management focuses clipboard then sends the deep-link request',
    () async {
      const MethodChannel windows = MethodChannel(
        'mixin.one/desktop_multi_window',
      );
      const MethodChannel channels = MethodChannel(
        'mixin.one/desktop_multi_window/channels',
      );
      final TestDefaultBinaryMessenger messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final List<MethodCall> channelCalls = <MethodCall>[];
      messenger.setMockMethodCallHandler(windows, (MethodCall call) async {
        if (call.method == 'getAllWindows') {
          return <Object?>[
            <String, String>{
              'windowId': 'resource-window',
              'windowArgument': jsonEncode(<String, String>{
                'kind': resourceManagerWindowKind,
              }),
            },
          ];
        }
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

      await const MultiWindowResourceManagerLauncher(
        parentWindowId: 'main-window',
      ).showClipboardCategories();

      final List<Map<Object?, Object?>> invocations = channelCalls
          .where((MethodCall call) => call.method == 'invokeMethod')
          .map((MethodCall call) => call.arguments! as Map<Object?, Object?>)
          .toList(growable: false);
      expect(
        invocations.map((Map<Object?, Object?> call) => call['method']),
        <String>['window_focus', manageClipboardCategoriesMethod],
      );
      expect(invocations.first['arguments'], 'clipboard');
    },
  );

  test('new category manager window carries the clipboard deep-link', () async {
    const MethodChannel windows = MethodChannel(
      'mixin.one/desktop_multi_window',
    );
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MethodCall? creationCall;
    messenger.setMockMethodCallHandler(windows, (MethodCall call) async {
      switch (call.method) {
        case 'getAllWindows':
          return <Object?>[];
        case 'createWindow':
          creationCall = call;
          return 'created-resource-window';
        default:
          return null;
      }
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(windows, null);
    });

    await const MultiWindowResourceManagerLauncher(
      parentWindowId: 'main-window',
    ).showClipboardCategories();

    expect(creationCall, isNotNull);
    final Map<Object?, Object?> configuration =
        creationCall!.arguments! as Map<Object?, Object?>;
    final Map<String, Object?> arguments = decodeDesktopWindowArguments(
      configuration['arguments']! as String,
    );
    expect(arguments['kind'], resourceManagerWindowKind);
    expect(arguments['destination'], 'clipboard');
    expect(arguments['openClipboardCategories'], true);
  });
}
