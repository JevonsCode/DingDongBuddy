import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/features/settings/domain/settings_window_launcher.dart';

const String settingsWindowKind = 'settings';

/// Reuses one dedicated settings panel across repeated toolbar clicks.
final class MultiWindowSettingsLauncher implements SettingsWindowLauncher {
  const MultiWindowSettingsLauncher({required this.parentWindowId});

  final String parentWindowId;

  @override
  Future<void> show() async {
    for (final WindowController controller in await WindowController.getAll()) {
      final Map<String, Object?> arguments = _decode(controller.arguments);
      if (arguments['kind'] == settingsWindowKind) {
        await controller.show();
        await controller.invokeMethod<void>('window_focus');
        return;
      }
    }

    await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode(<String, Object?>{
          'kind': settingsWindowKind,
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
