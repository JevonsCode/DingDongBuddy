import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/features/settings/domain/settings_window_launcher.dart';
import 'package:dingdong/features/settings/domain/sound_file_gateway.dart';
import 'package:dingdong/features/settings/domain/sound_preview_gateway.dart';
import 'package:dingdong/features/settings/ui/settings_screen.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

/// Root application hosted by the dedicated settings Flutter engine.
class SettingsWindowApp extends StatefulWidget {
  const SettingsWindowApp({
    required this.viewModel,
    required this.windowController,
    this.initialDestination = SettingsWindowDestination.top,
    this.onSettingsChanged,
    this.soundFileGateway,
    this.soundPreviewGateway,
    this.onRestartApplication,
    super.key,
  });

  final SettingsViewModel viewModel;
  final WindowController windowController;
  final SettingsWindowDestination initialDestination;
  final Future<void> Function()? onSettingsChanged;
  final SoundFileGateway? soundFileGateway;
  final SoundPreviewGateway? soundPreviewGateway;
  final Future<void> Function()? onRestartApplication;

  @override
  State<SettingsWindowApp> createState() => _SettingsWindowAppState();
}

class _SettingsWindowAppState extends State<SettingsWindowApp> {
  late final SettingsNavigationController _navigationController;

  @override
  void initState() {
    super.initState();
    _navigationController = SettingsNavigationController(
      initialDestination: widget.initialDestination,
    );
    unawaited(widget.viewModel.load());
    widget.viewModel.addListener(_handleSettingsChanged);
    unawaited(
      widget.windowController.setWindowMethodHandler((call) async {
        if (call.method == 'window_focus') {
          _navigationController.navigateTo(
            SettingsWindowDestination.fromValue(call.arguments),
          );
          await widget.viewModel.checkForUpdates();
          await windowManager.focus();
        }
      }),
    );
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_handleSettingsChanged);
    unawaited(widget.windowController.setWindowMethodHandler(null));
    _navigationController.dispose();
    widget.viewModel.dispose();
    super.dispose();
  }

  void _handleSettingsChanged() {
    if (widget.viewModel.isLoaded) {
      unawaited(widget.onSettingsChanged?.call());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (BuildContext context, Widget? child) {
        final AppSettings settings = widget.viewModel.settings;
        return MaterialApp(
          title: 'DingDong · 设置',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.desktopPanelLight(),
          darkTheme: AppTheme.desktopPanelDark(),
          themeMode: switch (settings.themeMode) {
            AppThemePreference.system => ThemeMode.system,
            AppThemePreference.light => ThemeMode.light,
            AppThemePreference.dark => ThemeMode.dark,
          },
          locale: switch (settings.language) {
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
          home: SettingsScreen(
            viewModel: widget.viewModel,
            navigationController: _navigationController,
            soundFileGateway: widget.soundFileGateway,
            soundPreviewGateway: widget.soundPreviewGateway,
            onRestartApplication: widget.onRestartApplication,
          ),
        );
      },
    );
  }
}
