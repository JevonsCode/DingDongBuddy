import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';

const String developmentTestPanelWindowKind = 'development-test-panel';
const String developmentTestTraySleepingMethod =
    'development_test_tray_sleeping';
const String developmentTestTrayNudgeMethod = 'development_test_tray_nudge';

/// Reuses one DEV-only panel for exercising real desktop integration paths.
final class MultiWindowDevelopmentTestPanelLauncher {
  const MultiWindowDevelopmentTestPanelLauncher({required this.parentWindowId});

  final String parentWindowId;

  Future<void> show() async {
    for (final WindowController controller in await WindowController.getAll()) {
      final Map<String, Object?> arguments = _decode(controller.arguments);
      if (arguments['kind'] == developmentTestPanelWindowKind) {
        await controller.show();
        await controller.invokeMethod<void>('window_focus');
        return;
      }
    }

    await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode(<String, Object?>{
          'kind': developmentTestPanelWindowKind,
          'parentWindowId': parentWindowId,
        }),
      ),
    );
  }
}

Map<String, Object?> _decode(String arguments) {
  if (arguments.trim().isEmpty) {
    return const <String, Object?>{};
  }
  final Object? value = jsonDecode(arguments);
  return value is Map<String, Object?> ? value : const <String, Object?>{};
}
