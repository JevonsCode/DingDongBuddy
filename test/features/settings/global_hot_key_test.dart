import 'package:dingdong/features/settings/domain/global_hot_key.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default shortcut is portable and keeps platform-native labels', () {
    expect(GlobalHotKey.defaultValue.label(TargetPlatform.macOS), '⌘⇧V');
    expect(
      GlobalHotKey.defaultValue.label(TargetPlatform.windows),
      'Ctrl+Shift+V',
    );
  });

  test('shortcut round-trips through the preference representation', () {
    const GlobalHotKey shortcut = GlobalHotKey(
      key: 'K',
      primary: true,
      shift: false,
      alt: true,
      secondary: true,
    );

    expect(GlobalHotKey.parse(shortcut.encode()), shortcut);
    expect(shortcut.toPlatformArguments(), <String, Object>{
      'key': 'K',
      'primary': true,
      'shift': false,
      'alt': true,
      'secondary': true,
    });
  });

  test('unsafe or malformed shortcuts fall back to Command Shift V', () {
    expect(GlobalHotKey.parse('not-json'), GlobalHotKey.defaultValue);
    expect(
      GlobalHotKey.parse(
        '{"key":"V","primary":false,"shift":false,'
        '"alt":false,"secondary":false}',
      ),
      GlobalHotKey.defaultValue,
    );
    expect(
      GlobalHotKey.parse(
        '{"key":"TAB","primary":true,"shift":false,'
        '"alt":false,"secondary":false}',
      ),
      GlobalHotKey.defaultValue,
    );
  });
}
