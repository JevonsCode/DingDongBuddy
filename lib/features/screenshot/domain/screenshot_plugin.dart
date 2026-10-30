import 'dart:convert';

import 'package:dingdong/features/settings/domain/global_hot_key.dart';

typedef ScreenshotAction =
    Future<Map<String, Object?>> Function(
      String action,
      Map<String, Object?> arguments,
    );

final class ScreenshotConfiguration {
  const ScreenshotConfiguration({
    this.enabled = false,
    this.shortcut = defaultShortcut,
  });

  static const defaultShortcut = GlobalHotKey(
    key: 'A',
    primary: true,
    shift: false,
    alt: true,
  );
  final bool enabled;
  final GlobalHotKey shortcut;

  static ScreenshotConfiguration parse(Object? source) {
    try {
      if (source is! String) return const ScreenshotConfiguration();
      final value = jsonDecode(source);
      if (value is! Map<String, dynamic>) {
        return const ScreenshotConfiguration();
      }
      return fromArguments(Map<String, Object?>.from(value));
    } on Object {
      return const ScreenshotConfiguration();
    }
  }

  static ScreenshotConfiguration fromArguments(Map<String, Object?> value) {
    // Retired backend fields are ignored; all shortcuts now use the system tool.
    final encoded = value['shortcut'];
    if (encoded is! Map) {
      throw const ScreenshotPluginException('invalid_shortcut');
    }
    final key = encoded['key'];
    if (key is! String) {
      throw const ScreenshotPluginException('invalid_shortcut');
    }
    final shortcut = GlobalHotKey(
      key: key,
      primary: encoded['primary'] == true,
      shift: encoded['shift'] == true,
      alt: encoded['alt'] == true,
      secondary: encoded['secondary'] == true,
    );
    if (!shortcut.isValid) {
      throw const ScreenshotPluginException('invalid_shortcut');
    }
    return ScreenshotConfiguration(
      enabled: value['enabled'] == true,
      shortcut: shortcut,
    );
  }

  Map<String, Object> toArguments() => {
    'enabled': enabled,
    'shortcut': shortcut.toPlatformArguments(),
  };
  String encode() => jsonEncode(toArguments());
}

final class ScreenshotRuntimeStatus {
  factory ScreenshotRuntimeStatus.fromPlatform(Object? source) {
    if (source is! Map ||
        source['supported'] is! bool ||
        source['running'] is! bool ||
        source['capturing'] is! bool) {
      throw const ScreenshotPluginException('unavailable');
    }
    return ScreenshotRuntimeStatus(
      supported: source['supported'] == true,
      running: source['running'] == true,
      capturing: source['capturing'] == true,
    );
  }
  const ScreenshotRuntimeStatus({
    required this.supported,
    required this.running,
    required this.capturing,
  });
  const ScreenshotRuntimeStatus.unavailable()
    : supported = false,
      running = false,
      capturing = false;
  final bool supported;
  final bool running;
  final bool capturing;
}

final class ScreenshotPluginException implements Exception {
  const ScreenshotPluginException(this.code);
  final String code;
  @override
  String toString() => 'screenshot:$code';
}

abstract interface class ScreenshotPluginGateway {
  Future<ScreenshotRuntimeStatus> apply(ScreenshotConfiguration configuration);
  Future<ScreenshotRuntimeStatus> status();
  Future<void> capture();
}
