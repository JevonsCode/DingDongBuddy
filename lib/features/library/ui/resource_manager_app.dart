import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
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
    this.desktopContextMenuGateway,
    this.onOpenExternalLink,
    super.key,
  });

  final LibraryViewModel viewModel;
  final ClipboardViewModel clipboardViewModel;
  final AppSettings settings;
  final WindowController windowController;
  final DesktopContextMenuGateway? desktopContextMenuGateway;
  final Future<void> Function(Uri uri)? onOpenExternalLink;

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
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
        }
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
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Row(
            children: <Widget>[
              _WorkspaceSidebar(
                selectedIndex: _selectedIndex,
                onSelected: (int value) =>
                    setState(() => _selectedIndex = value),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _selectedIndex == 0
                    ? LibraryScreen(
                        viewModel: widget.viewModel,
                        transferGateway: FileSelectorLibraryTransferGateway(),
                        contextMenuGateway: widget.desktopContextMenuGateway,
                        onOpenExternalLink: widget.onOpenExternalLink,
                      )
                    : ClipboardManagerScreen(
                        viewModel: widget.clipboardViewModel,
                        contextMenuGateway: widget.desktopContextMenuGateway,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _localized(BuildContext context, String english, String chinese) =>
    Localizations.localeOf(context).languageCode == 'zh' ? chinese : english;

class _WorkspaceSidebar extends StatelessWidget {
  const _WorkspaceSidebar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('resource-manager-navigation'),
      color: colors.surfaceContainerLowest,
      child: SizedBox(
        width: 184,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 18, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 17,
                      color: colors.onSurface,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _localized(context, 'Resource manager', '资源管理'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  _localized(context, 'WORKSPACE', '工作区'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              _SidebarItem(
                key: const Key('resource-manager-nav-resources'),
                icon: Icons.layers_outlined,
                label: _localized(context, 'Resources', '资源'),
                selected: selectedIndex == 0,
                onTap: () => onSelected(0),
              ),
              const SizedBox(height: 3),
              _SidebarItem(
                key: const Key('resource-manager-nav-clipboard'),
                icon: Icons.content_paste_outlined,
                label: _localized(context, 'Clipboard', '剪贴板'),
                selected: selectedIndex == 1,
                onTap: () => onSelected(1),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  _localized(context, 'Stored on this device', '数据保存在本机'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.09)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onTap,
        child: SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 9),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
