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
    this.onClipboardMonitoringChanged,
    this.onClearClipboardHistory,
    this.onShowSettings,
  });

  final DesktopShellGateway gateway;
  final ShellController controller;
  final ActivityController activityController;
  final int Function() defaultWorkspaceIndex;
  final Future<void> Function(bool enabled)? onClipboardMonitoringChanged;
  final Future<void> Function()? onClearClipboardHistory;
  final Future<void> Function()? onShowSettings;
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
      case DesktopShellCommand.openApplication:
        _selectPrimaryWorkspace();
        await gateway.showAndFocus(acknowledgeUnread: true);
      case DesktopShellCommand.openTray:
        _selectPrimaryWorkspace();
        await gateway.toggleAndFocus(acknowledgeUnread: true);
      case DesktopShellCommand.showToday:
        controller.open(0);
        await gateway.showAndFocus();
      case DesktopShellCommand.showClipboard:
        controller.open(2);
        _refreshClipboard();
        await gateway.showAndFocus();
      case DesktopShellCommand.toggleClipboard:
        controller.open(2);
        _refreshClipboard();
        await gateway.toggleAndFocus();
      case DesktopShellCommand.toggleClipboardFilters:
        controller.requestClipboardFilterToggle();
      case DesktopShellCommand.focusClipboardSearch:
        controller.open(2);
        controller.requestClipboardSearchFocus();
      case DesktopShellCommand.showSettings:
        await onShowSettings?.call();
      case DesktopShellCommand.startClipboardMonitoring:
        await onClipboardMonitoringChanged?.call(true);
      case DesktopShellCommand.stopClipboardMonitoring:
        await onClipboardMonitoringChanged?.call(false);
      case DesktopShellCommand.clearClipboardHistory:
        await onClearClipboardHistory?.call();
        controller.requestClipboardRefresh();
      case DesktopShellCommand.quit:
        await gateway.quit();
    }
  }

  void _selectPrimaryWorkspace() {
    if (activityController.unseenCount > 0) {
      controller.open(0);
      activityController.requestReveal();
      return;
    }
    final int workspace = defaultWorkspaceIndex();
    controller.open(workspace);
    if (workspace == 2) {
      _refreshClipboard();
    }
  }

  void _refreshClipboard() {
    controller.requestClipboardRefresh();
  }
}
