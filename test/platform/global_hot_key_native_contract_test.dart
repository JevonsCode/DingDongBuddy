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
}
