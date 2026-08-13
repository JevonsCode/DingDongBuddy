import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/features/shell/domain/development_test_action.dart';
import 'package:dingdong/features/shell/ui/development_test_panel_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('development test action IDs round-trip', () {
    for (final DevelopmentTestAction action in DevelopmentTestAction.values) {
      expect(DevelopmentTestAction.fromId(action.id), action);
    }
    expect(DevelopmentTestAction.fromId('unknown'), isNull);
    expect(DevelopmentTestAction.fromId(null), isNull);
  });

  testWidgets('Windows DEV panel close hides without exiting', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const String windowId = 'dev-panel-close-test';
    const MethodChannel registry = MethodChannel(
      'mixin.one/desktop_multi_window',
    );
    const MethodChannel channels = MethodChannel(
      'mixin.one/desktop_multi_window/channels',
    );
    const MethodChannel windowManager = MethodChannel('window_manager');
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    final List<MethodCall> windowCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(registry, (MethodCall call) async {
      if (call.method == 'getWindowDefinition') {
        return <String, String>{'windowId': windowId, 'windowArgument': ''};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(channels, (_) async => null);
    messenger.setMockMethodCallHandler(windowManager, (MethodCall call) async {
      windowCalls.add(call);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(registry, null);
      messenger.setMockMethodCallHandler(channels, null);
      messenger.setMockMethodCallHandler(windowManager, null);
    });

    await tester.pumpWidget(
      DevelopmentTestPanelApp(
        settings: const AppSettings(),
        animationsSupported: false,
        onRun: (_) async {},
        windowController: WindowController.fromWindowId(windowId),
      ),
    );
    await tester.pump();

    expect(
      windowCalls.any(
        (MethodCall call) =>
            call.method == 'setPreventClose' &&
            (call.arguments as Map<Object?, Object?>)['isPreventClose'] == true,
      ),
      isTrue,
    );
    windowCalls.clear();
    await _sendWindowManagerEvent(messenger, 'close');
    await tester.pump();
    expect(windowCalls.map((MethodCall call) => call.method), contains('hide'));
    expect(
      windowCalls.map((MethodCall call) => call.method),
      isNot(contains('destroy')),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('DEV test panel exposes and triggers integration actions', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final List<DevelopmentTestAction> actions = <DevelopmentTestAction>[];

    await tester.pumpWidget(
      DevelopmentTestPanelApp(
        settings: const AppSettings(language: AppLanguagePreference.chinese),
        animationsSupported: true,
        onRun: (DevelopmentTestAction action) async => actions.add(action),
      ),
    );

    expect(find.text('测试面板'), findsOneWidget);
    expect(find.text('DEV'), findsOneWidget);
    expect(find.byKey(const Key('dev-test-panel-data-notice')), findsOneWidget);
    expect(find.textContaining('绝不会读取真实手机剪贴板'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dev-test-panel-sleeping')));
    await tester.pumpAndSettle();
    expect(actions, <DevelopmentTestAction>[
      DevelopmentTestAction.traySleeping,
    ]);
    expect(find.text('已触发：睡眠状态'), findsOneWidget);

    final Finder richAlert = find.byKey(const Key('dev-test-panel-agent-rich'));
    await tester.ensureVisible(richAlert);
    await tester.tap(richAlert);
    await tester.pumpAndSettle();
    expect(actions.last, DevelopmentTestAction.agentRichCompletion);
    expect(find.text('已创建：手机端长描述 Agent 提醒'), findsOneWidget);

    final Finder phoneText = find.byKey(const Key('dev-test-panel-phone-text'));
    await tester.ensureVisible(phoneText);
    await tester.tap(phoneText);
    await tester.pumpAndSettle();
    expect(actions.last, DevelopmentTestAction.phoneClipboardText);
    expect(find.text('已创建：模拟手机文字记录'), findsOneWidget);

    const Map<String, DevelopmentTestAction>
    remainingActions = <String, DevelopmentTestAction>{
      'dev-test-panel-nudge': DevelopmentTestAction.trayNudge,
      'dev-test-panel-agent-basic': DevelopmentTestAction.agentCompletion,
      'dev-test-panel-agent-burst': DevelopmentTestAction.agentBurst,
      'dev-test-panel-phone-file': DevelopmentTestAction.phoneClipboardFile,
      'dev-test-panel-auto-send': DevelopmentTestAction.autoSendClipboard,
      'dev-test-panel-manual-share': DevelopmentTestAction.manualDeviceShare,
      'dev-test-panel-device-manager': DevelopmentTestAction.openDeviceManager,
    };
    for (final MapEntry<String, DevelopmentTestAction> entry
        in remainingActions.entries) {
      final Finder button = find.byKey(Key(entry.key));
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(actions.last, entry.value);
    }
    expect(actions, hasLength(DevelopmentTestAction.values.length));
    expect(actions.toSet(), DevelopmentTestAction.values.toSet());
  });

  testWidgets('unsupported platforms disable only tray animation actions', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final List<DevelopmentTestAction> actions = <DevelopmentTestAction>[];
    await tester.pumpWidget(
      DevelopmentTestPanelApp(
        settings: const AppSettings(language: AppLanguagePreference.chinese),
        animationsSupported: false,
        onRun: (DevelopmentTestAction action) async => actions.add(action),
      ),
    );

    final FilledButton sleeping = tester.widget(
      find.descendant(
        of: find.byKey(const Key('dev-test-panel-sleeping')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(sleeping.onPressed, isNull);

    final Finder agentBasic = find.byKey(
      const Key('dev-test-panel-agent-basic'),
    );
    await tester.ensureVisible(agentBasic);
    final FilledButton agentButton = tester.widget(
      find.descendant(of: agentBasic, matching: find.byType(FilledButton)),
    );
    expect(agentButton.onPressed, isNotNull);
    await tester.tap(agentBasic);
    await tester.pumpAndSettle();
    expect(actions, <DevelopmentTestAction>[
      DevelopmentTestAction.agentCompletion,
    ]);

    expect(find.textContaining('其余集成测试仍可使用'), findsOneWidget);
  });
}

Future<void> _sendWindowManagerEvent(
  TestDefaultBinaryMessenger messenger,
  String eventName,
) async {
  final Completer<void> handled = Completer<void>();
  await messenger.handlePlatformMessage(
    'window_manager',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall('onEvent', <String, Object?>{'eventName': eventName}),
    ),
    (_) => handled.complete(),
  );
  await handled.future;
}
