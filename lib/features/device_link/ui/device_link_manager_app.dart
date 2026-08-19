import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_locale.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/platform/windows_auxiliary_window_close_behavior.dart';
import 'package:dingdong/features/device_link/ui/device_link_dialog.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/platform/multi_window_device_link_manager.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Root application hosted by the dedicated connection-manager engine.
final class DeviceLinkManagerApp extends StatefulWidget {
  const DeviceLinkManagerApp({
    required this.controller,
    required this.settings,
    required this.windowController,
    super.key,
  });

  final RemoteDeviceLinkManagement controller;
  final AppSettings settings;
  final WindowController windowController;

  @override
  State<DeviceLinkManagerApp> createState() => _DeviceLinkManagerAppState();
}

class _DeviceLinkManagerAppState extends State<DeviceLinkManagerApp>
    with
        WindowListener,
        WindowsAuxiliaryWindowCloseBehavior<DeviceLinkManagerApp> {
  @override
  void initState() {
    super.initState();
    enableWindowsHideOnClose();
    unawaited(
      widget.windowController.setWindowMethodHandler((call) async {
        switch (call.method) {
          case 'window_focus':
          case deviceLinkManagerChangedMethod:
            await widget.controller.reload();
            if (call.method == 'window_focus') await windowManager.focus();
          default:
            return;
        }
      }),
    );
  }

  @override
  void dispose() {
    unawaited(widget.windowController.setWindowMethodHandler(null));
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (BuildContext context) =>
          context.l10n.connectedDevicesWindowTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.desktopPanelLight(),
      darkTheme: AppTheme.desktopPanelDark(),
      themeMode: switch (widget.settings.themeMode) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      },
      locale: configuredAppLocale(widget.settings.language),
      supportedLocales: DingDongLocalizations.supportedLocales,
      localizationsDelegates: DingDongLocalizations.localizationsDelegates,
      home: Builder(
        builder: (BuildContext context) => Semantics(
          container: true,
          explicitChildNodes: true,
          label: context.l10n.dingdongDeviceConnectionManager,
          child: DeviceLinkManagerScreen(controller: widget.controller),
        ),
      ),
    );
  }
}
