import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_manager_screen.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/library/ui/library_screen.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/platform/file_selector_library_transfer_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

/// Root application hosted by the dedicated resource manager Flutter engine.
class ResourceManagerApp extends StatefulWidget {
  const ResourceManagerApp({
    required this.viewModel,
    required this.clipboardViewModel,
    required this.settings,
    required this.windowController,
    super.key,
  });

  final LibraryViewModel viewModel;
  final ClipboardViewModel clipboardViewModel;
  final AppSettings settings;
  final WindowController windowController;

  @override
  State<ResourceManagerApp> createState() => _ResourceManagerAppState();
}

class _ResourceManagerAppState extends State<ResourceManagerApp> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.windowController.setWindowMethodHandler((call) async {
        switch (call.method) {
          case 'window_focus':
            await widget.viewModel.load();
            widget.clipboardViewModel.load();
            await windowManager.focus();
          case 'edit_resource':
            final Object? arguments = call.arguments;
            final String? id = arguments is Map
                ? arguments['id'] as String?
                : null;
            if (id != null) {
              _selectResource(id);
            }
          default:
            return;
        }
      }),
    );
  }

  void _selectResource(String id) {
    for (final resource in widget.viewModel.allResources) {
      if (resource.id == id) {
        widget.viewModel.selectResource(resource);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DingDong · 资源管理',
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
      home: Scaffold(
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<int>(
                  key: const Key('resource-manager-navigation'),
                  segments: <ButtonSegment<int>>[
                    ButtonSegment<int>(
                      value: 0,
                      icon: const Icon(Icons.layers_outlined),
                      label: Text(_localized(context, 'Resources', '资源')),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      icon: const Icon(Icons.content_paste_outlined),
                      label: Text(_localized(context, 'Clipboard', '剪贴板')),
                    ),
                  ],
                  selected: <int>{_selectedIndex},
                  onSelectionChanged: (Set<int> value) =>
                      setState(() => _selectedIndex = value.single),
                ),
              ),
            ),
            Expanded(
              child: _selectedIndex == 0
                  ? LibraryScreen(
                      viewModel: widget.viewModel,
                      transferGateway: FileSelectorLibraryTransferGateway(),
                    )
                  : ClipboardManagerScreen(
                      viewModel: widget.clipboardViewModel,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _localized(BuildContext context, String english, String chinese) =>
    Localizations.localeOf(context).languageCode == 'zh' ? chinese : english;
