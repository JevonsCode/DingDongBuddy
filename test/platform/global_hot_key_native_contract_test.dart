import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS runner registers the shortcut received from Flutter', () {
    final String source = File(
      'macos/Runner/AppDelegate.swift',
    ).readAsStringSync();

    expect(source, contains('GlobalHotKeyConfiguration'));
    expect(source, contains('arguments: call.arguments'));
    expect(source, contains('configuration.keyCode'));
    expect(source, contains('configuration.modifiers'));
    expect(source, contains('case "F12": return UInt32(kVK_F12)'));
    expect(source, contains('registerHotKeyOnly(previousConfiguration)'));
  });

  test('Windows runner registers and restores portable shortcuts', () {
    final String source = File(
      'windows/runner/flutter_window.cpp',
    ).readAsStringSync();

    expect(source, contains('ReadGlobalHotKeyConfiguration(call)'));
    expect(source, contains('configuration->modifiers'));
    expect(source, contains('configuration->virtual_key'));
    expect(source, contains('modifiers |= MOD_WIN'));
    expect(source, contains('previous.virtual_key'));
  });

  test('macOS Accessibility helper exposes the current app as a file drag', () {
    final String appDelegate = File(
      'macos/Runner/AppDelegate.swift',
    ).readAsStringSync();
    final String assistant = File(
      'macos/Runner/AccessibilityPermissionAssistant.swift',
    ).readAsStringSync();
    final String chinese = File(
      'macos/Runner/zh-Hans.lproj/AccessibilityPermissionAssistant.strings',
    ).readAsStringSync();

    expect(appDelegate, contains('accessibilityPermissionAssistant.show()'));
    expect(
      appDelegate,
      contains('accessibilityPermissionAssistant.onPermissionGranted'),
    );
    expect(appDelegate, contains('"pastePermissionGranted"'));
    expect(assistant, contains('com.apple.settings.PrivacySecurity.extension'));
    expect(assistant, contains('Privacy_Accessibility'));
    expect(assistant, contains('Bundle.main.bundleURL'));
    expect(assistant, contains('permissionWasGranted'));
    expect(assistant, contains('AXIsProcessTrusted()'));
    expect(assistant, contains('AppBundlePasteboardWriter'));
    expect(assistant, contains('.fileURL'));
    expect(assistant, contains('NSFilenamesPboardType'));
    expect(assistant, contains('com.apple.pasteboard.promised-file-url'));
    expect(
      assistant,
      contains('ddAccessibilityString("disabled_remove_guide")'),
    );
    expect(chinese, contains('先拖一次让它可用'));
    expect(chinese, contains('删除后再拖一次并打开开关'));
    expect(assistant, contains('RoundedVisualEffectContainer'));
    expect(assistant, contains('effectView.layer?.mask = effectMask'));
  });
}
