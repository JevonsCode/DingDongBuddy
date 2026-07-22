import 'dart:async';

import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/shell/domain/desktop_shell_gateway.dart';
import 'package:dingdong/features/shell/domain/desktop_shell_service.dart';
import 'package:dingdong/features/shell/ui/shell_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'tray and hotkey commands navigate and focus the desktop window',
    () async {
      final _FakeDesktopShellGateway gateway = _FakeDesktopShellGateway();
      final ShellController controller = ShellController();
      final DesktopShellService service = DesktopShellService(
        gateway: gateway,
        controller: controller,
        activityController: ActivityController(),
        defaultWorkspaceIndex: () => 0,
      );
      await service.start();

      gateway.emit(DesktopShellCommand.showClipboard);
      await Future<void>.delayed(Duration.zero);

      expect(controller.selectedIndex, 2);
      expect(gateway.showCount, 1);
      expect(controller.libraryRefreshRevision, 1);

      gateway.emit(DesktopShellCommand.showToday);
      await Future<void>.delayed(Duration.zero);
      expect(controller.selectedIndex, 0);

      await service.stop();
    },
  );

  test('global shortcut toggles the transient clipboard popup', () async {
    final _FakeDesktopShellGateway gateway = _FakeDesktopShellGateway();
    final ShellController controller = ShellController();
    final DesktopShellService service = DesktopShellService(
      gateway: gateway,
      controller: controller,
      activityController: ActivityController(),
      defaultWorkspaceIndex: () => 0,
    );
    await service.start();

    gateway.emit(DesktopShellCommand.toggleClipboard);
    await Future<void>.delayed(Duration.zero);

    expect(controller.selectedIndex, 2);
    expect(gateway.toggleCount, 1);
    expect(gateway.showCount, 0);
    expect(controller.clipboardRefreshRevision, 1);
    expect(controller.libraryRefreshRevision, 1);
    await service.stop();
  });

  test('opening the application shows rather than toggles the panel', () async {
    final _FakeDesktopShellGateway gateway = _FakeDesktopShellGateway();
    final ShellController controller = ShellController(initialIndex: 0);
    final DesktopShellService service = DesktopShellService(
      gateway: gateway,
      controller: controller,
      activityController: ActivityController(),
      defaultWorkspaceIndex: () => 2,
    );
    await service.start();

    gateway.emit(DesktopShellCommand.openApplication);
    await Future<void>.delayed(Duration.zero);

    expect(controller.selectedIndex, 2);
    expect(controller.clipboardRefreshRevision, 1);
    expect(controller.libraryRefreshRevision, 1);
    expect(gateway.showCount, 1);
    expect(gateway.toggleCount, 0);
    await service.stop();
  });

  test('showing Clipboard refreshes history without recapturing it', () async {
    final _FakeDesktopShellGateway gateway = _FakeDesktopShellGateway();
    final ShellController controller = ShellController();
    final DesktopShellService service = DesktopShellService(
      gateway: gateway,
      controller: controller,
      activityController: ActivityController(),
      defaultWorkspaceIndex: () => 0,
    );
    await service.start();

    gateway.emit(DesktopShellCommand.showClipboard);
    await Future<void>.delayed(Duration.zero);

    expect(controller.clipboardRefreshRevision, 1);
    expect(controller.libraryRefreshRevision, 1);
    expect(gateway.showCount, 1);
    await service.stop();
  });

  test('native filter shortcut reaches the clipboard callout state', () async {
    final _FakeDesktopShellGateway gateway = _FakeDesktopShellGateway();
    final ShellController controller = ShellController(initialIndex: 2);
    final DesktopShellService service = DesktopShellService(
      gateway: gateway,
      controller: controller,
      activityController: ActivityController(),
      defaultWorkspaceIndex: () => 0,
    );
    await service.start();

    gateway.emit(DesktopShellCommand.toggleClipboardFilters);
    await Future<void>.delayed(Duration.zero);

    expect(controller.clipboardFilterToggleRevision, 1);
    await service.stop();
  });

  test(
    'tray utility commands update monitoring, history, settings, and search',
    () async {
      final _FakeDesktopShellGateway gateway = _FakeDesktopShellGateway();
      final ShellController controller = ShellController();
      final List<bool> monitoringChanges = <bool>[];
      int clearCount = 0;
      int settingsCount = 0;
      final DesktopShellService service = DesktopShellService(
        gateway: gateway,
        controller: controller,
        activityController: ActivityController(),
        defaultWorkspaceIndex: () => 0,
        onClipboardMonitoringChanged: (bool enabled) async {
          monitoringChanges.add(enabled);
        },
        onClearClipboardHistory: () async {
          clearCount += 1;
        },
        onShowSettings: () async {
          settingsCount += 1;
        },
      );
      await service.start();

      gateway.emit(DesktopShellCommand.startClipboardMonitoring);
      gateway.emit(DesktopShellCommand.stopClipboardMonitoring);
      gateway.emit(DesktopShellCommand.clearClipboardHistory);
      gateway.emit(DesktopShellCommand.showSettings);
      gateway.emit(DesktopShellCommand.focusClipboardSearch);
      await Future<void>.delayed(Duration.zero);

      expect(monitoringChanges, <bool>[true, false]);
      expect(clearCount, 1);
      expect(settingsCount, 1);
      expect(controller.selectedIndex, 2);
      expect(controller.clipboardSearchFocusRevision, 1);
      await service.stop();
    },
  );

  test('tray click opens Dynamic when a completion is unseen', () async {
    final _FakeDesktopShellGateway gateway = _FakeDesktopShellGateway();
    final ShellController controller = ShellController(initialIndex: 2);
    final ActivityController activityController = ActivityController();
    activityController.record(source: 'Codex', message: 'Task complete');
    final DesktopShellService service = DesktopShellService(
      gateway: gateway,
      controller: controller,
      activityController: activityController,
      defaultWorkspaceIndex: () => 2,
    );
    await service.start();

    gateway.emit(DesktopShellCommand.openTray);
    await Future<void>.delayed(Duration.zero);

    expect(controller.selectedIndex, 0);
    expect(activityController.revealRevision, 1);
    expect(gateway.toggleCount, 1);
    expect(gateway.lastToggleAcknowledgesUnread, isTrue);
    await service.stop();
  });

  test(
    'tray click uses the configured workspace without notifications',
    () async {
      final _FakeDesktopShellGateway gateway = _FakeDesktopShellGateway();
      final ShellController controller = ShellController(initialIndex: 2);
      final DesktopShellService service = DesktopShellService(
        gateway: gateway,
        controller: controller,
        activityController: ActivityController(),
        defaultWorkspaceIndex: () => 1,
      );
      await service.start();

      gateway.emit(DesktopShellCommand.openTray);
      await Future<void>.delayed(Duration.zero);

      expect(controller.selectedIndex, 1);
      expect(gateway.toggleCount, 1);
      await service.stop();
    },
  );
}

final class _FakeDesktopShellGateway implements DesktopShellGateway {
  final StreamController<DesktopShellCommand> _commands =
      StreamController<DesktopShellCommand>.broadcast(sync: true);
  int showCount = 0;
  int toggleCount = 0;
  bool lastToggleAcknowledgesUnread = false;

  @override
  Stream<DesktopShellCommand> get commands => _commands.stream;

  void emit(DesktopShellCommand command) => _commands.add(command);

  @override
  Future<void> quit() async {}

  @override
  Future<void> showAndFocus({bool acknowledgeUnread = false}) async {
    showCount += 1;
  }

  @override
  Future<void> toggleAndFocus({bool acknowledgeUnread = false}) async {
    toggleCount += 1;
    lastToggleAcknowledgesUnread = acknowledgeUnread;
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
