import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/features/settings/domain/settings_window_launcher.dart';

const String settingsWindowKind = 'settings';

/// Reuses one dedicated settings panel across repeated toolbar clicks.
final class MultiWindowSettingsLauncher implements SettingsWindowLauncher {
  MultiWindowSettingsLauncher({required this.parentWindowId});

  final String parentWindowId;
  Future<void> _pending = Future<void>.value();

  @override
  Future<void> show({
    SettingsWindowDestination destination = SettingsWindowDestination.top,
  }) => _enqueue(destination: destination);

  Future<void> showVoice(int issueNumber) => _enqueue(
    destination: SettingsWindowDestination.voice,
    issueNumber: issueNumber,
  );

  Future<void> _enqueue({
    required SettingsWindowDestination destination,
    int? issueNumber,
  }) {
    final next = _pending.then(
      (_) => _show(destination: destination, issueNumber: issueNumber),
    );
    // A failed request must not prevent later requests from being delivered.
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> _show({
    required SettingsWindowDestination destination,
    int? issueNumber,
  }) async {
    for (final WindowController controller in await WindowController.getAll()) {
      final Map<String, Object?> arguments = _decode(controller.arguments);
      if (arguments['kind'] == settingsWindowKind) {
        await controller.show();
        for (var attempt = 0; ; attempt++) {
          try {
            await controller.invokeMethod<void>(
              issueNumber == null ? 'window_focus' : 'window_focus_voice',
              issueNumber ?? destination.name,
            );
            break;
          } on WindowChannelException catch (error) {
            if (attempt >= 49 ||
                (error.code != 'CHANNEL_UNREGISTERED' &&
                    error.code != 'CHANNEL_NOT_FOUND')) {
              rethrow;
            }
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }
        return;
      }
    }

    await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode(<String, Object?>{
          'kind': settingsWindowKind,
          'parentWindowId': parentWindowId,
          'destination': destination.name,
          'voiceIssueNumber': ?issueNumber,
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
