import 'package:dingdong/features/screenshot/domain/screenshot_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final shortcut = ScreenshotConfiguration.defaultShortcut
      .toPlatformArguments();
  for (final legacyBackend in [null, 'editor', 'system', 'retired']) {
    test(
      'retired backend $legacyBackend preserves only shortcut and enabled',
      () {
        final configuration = ScreenshotConfiguration.fromArguments({
          'enabled': true,
          'backend': ?legacyBackend,
          'shortcut': shortcut,
        });
        expect(configuration.enabled, isTrue);
        expect(configuration.shortcut, ScreenshotConfiguration.defaultShortcut);
        expect(
          configuration.toArguments().keys,
          unorderedEquals(['enabled', 'shortcut']),
        );
        final restored = ScreenshotConfiguration.parse(configuration.encode());
        expect(restored.enabled, isTrue);
        expect(restored.shortcut, configuration.shortcut);
      },
    );
  }
}
