import 'dart:async';

import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/shell/domain/desktop_shell_gateway.dart';
import 'package:dingdong/features/shell/ui/shell_controller.dart';

/// Coordinates native desktop commands with framework navigation state.
final class DesktopShellService {
  DesktopShellService({
    required this.gateway,
    required this.controller,
    required this.activityController,
    required this.defaultWorkspaceIndex,
  });

  final DesktopShellGateway gateway;
  final ShellController controller;
  final ActivityController activityController;
  final int Function() defaultWorkspaceIndex;
  StreamSubscription<DesktopShellCommand>? _subscription;

  Future<void> start() async {
    _subscription ??= gateway.commands.listen(_handleCommand);
    await gateway.start();
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await gateway.stop();
  }

  Future<void> _handleCommand(DesktopShellCommand command) async {
    switch (command) {
      case DesktopShellCommand.openTray:
        if (activityController.unseenCount > 0) {
          controller.open(0);
          activityController.requestReveal();
        } else {
          controller.open(defaultWorkspaceIndex());
        }
        await gateway.toggleAndFocus();
      case DesktopShellCommand.showToday:
        controller.open(0);
        await gateway.showAndFocus();
      case DesktopShellCommand.showClipboard:
        controller.open(2);
        await gateway.showAndFocus();
      case DesktopShellCommand.toggleClipboard:
        controller.open(2);
        await gateway.toggleAndFocus();
      case DesktopShellCommand.toggleClipboardFilters:
        controller.requestClipboardFilterToggle();
      case DesktopShellCommand.quit:
        await gateway.quit();
    }
  }
}
