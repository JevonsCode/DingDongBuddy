import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'macOS hosts selection tools under DingDong permission and Keychain',
    () {
      final String appDelegate = File(
        'macos/Runner/AppDelegate.swift',
      ).readAsStringSync();
      final String controller = File(
        'macos/Runner/SelectionPlugin/SelectionPluginController.swift',
      ).readAsStringSync();
      final String runtime = File(
        'macos/Runner/SelectionPlugin/SelectionPluginRuntime.swift',
      ).readAsStringSync();

      expect(appDelegate, contains('dingdong/selection_plugin'));
      expect(appDelegate, contains('SelectionPluginController()'));
      expect(appDelegate, contains('accessibilityPermissionAssistant.show()'));
      expect(appDelegate, contains('selectionPluginController?.shutdown()'));
      expect(controller, contains('guard enabled else'));
      expect(controller, contains('stopListening()'));
      expect(controller, contains('monitor = nil'));
      expect(controller, contains('modelTask?.cancel()'));
      expect(runtime, contains('AXIsProcessTrusted()'));
      expect(runtime, contains('kSecClassGenericPassword'));
      expect(runtime, contains('URLSessionConfiguration.ephemeral'));
      expect(runtime, isNot(contains('Timer.scheduledTimer')));
    },
  );

  test('Xcode compiles both native selection plugin sources', () {
    final String project = File(
      'macos/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(project, contains('SelectionPluginRuntime.swift in Sources'));
    expect(project, contains('SelectionPluginController.swift in Sources'));
  });
}
