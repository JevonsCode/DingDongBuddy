import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/features/device_link/ui/device_link_dialog.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/platform/multi_window_device_link_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

class _DeviceLinkManagerAppState extends State<DeviceLinkManagerApp> {
  @override
  void initState() {
    super.initState();
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
      title: 'DingDong · 连接设备',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.desktopPanelLight(),
      darkTheme: AppTheme.desktopPanelDark(),
      themeMode: switch (widget.settings.themeMode) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      },
      locale: switch (widget.settings.language) {
        AppLanguagePreference.system => null,
        AppLanguagePreference.english => const Locale('en'),
        AppLanguagePreference.chinese => const Locale('zh'),
      },
      supportedLocales: const <Locale>[Locale('en'), Locale('zh')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        DingDongLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (BuildContext context) => Semantics(
          container: true,
          explicitChildNodes: true,
          label: context.localized(
            'DingDong device connection manager',
            'DingDong 设备连接管理窗口',
          ),
          child: DeviceLinkManagerScreen(controller: widget.controller),
        ),
      ),
    );
  }
}
