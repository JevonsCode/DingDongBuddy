import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/activity/ui/agent_activity_manager_screen.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_manager_screen.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/issue_center/domain/app_issue.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_screen.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:dingdong/features/library/ui/library_screen.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/platform/file_selector_library_transfer_gateway.dart';
import 'package:dingdong/platform/native_agent_conversation_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

/// Root application hosted by the dedicated resource manager Flutter engine.
class ResourceManagerApp extends StatefulWidget {
  const ResourceManagerApp({
    required this.viewModel,
    required this.clipboardViewModel,
    required this.activityController,
    required this.issueCenterController,
    required this.settings,
    required this.windowController,
    this.initialDestination = ResourceManagerDestination.resources,
    this.agentConversationLauncher,
    this.desktopContextMenuGateway,
    this.onLoadHostIssues,
    this.onOpenExternalLink,
    super.key,
  });

  final LibraryViewModel viewModel;
  final ClipboardViewModel clipboardViewModel;
  final ActivityController activityController;
  final IssueCenterController issueCenterController;
  final AppSettings settings;
  final WindowController windowController;
  final ResourceManagerDestination initialDestination;
  final AgentConversationLauncher? agentConversationLauncher;
  final DesktopContextMenuGateway? desktopContextMenuGateway;
  final Future<List<AppIssue>> Function()? onLoadHostIssues;
  final Future<void> Function(Uri uri)? onOpenExternalLink;

  @override
  State<ResourceManagerApp> createState() => _ResourceManagerAppState();
}

class _ResourceManagerAppState extends State<ResourceManagerApp> {
  int _selectedIndex = 0;
  late final AgentConversationLauncher _agentConversationLauncher;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialDestination.index;
    _agentConversationLauncher =
        widget.agentConversationLauncher ?? NativeAgentConversationLauncher();
    unawaited(_loadHostIssues());
    unawaited(
      widget.windowController.setWindowMethodHandler((call) async {
        switch (call.method) {
          case 'window_focus':
            await widget.viewModel.load();
            widget.clipboardViewModel.load();
            widget.activityController.reload();
            final ResourceManagerDestination destination =
                ResourceManagerDestination.parse(call.arguments);
            if (destination == ResourceManagerDestination.issues) {
              await _loadHostIssues();
            }
            _selectDestination(destination);
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

  void _selectDestination(ResourceManagerDestination destination) {
    if (destination == ResourceManagerDestination.issues) {
      unawaited(_loadHostIssues());
    }
    if (_selectedIndex != destination.index && mounted) {
      setState(() => _selectedIndex = destination.index);
    }
  }

  Future<void> _loadHostIssues() async {
    final Future<List<AppIssue>> Function()? load = widget.onLoadHostIssues;
    if (load == null) {
      return;
    }
    try {
      widget.issueCenterController.replaceSource(
        agentResourceSyncIssueSource,
        await load(),
      );
    } on Object {
      // The resource window remains usable if its parent is closing.
    }
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

  void _openIssueResource(String id) {
    _selectResource(id);
    if (_selectedIndex != ResourceManagerDestination.resources.index) {
      setState(
        () => _selectedIndex = ResourceManagerDestination.resources.index,
      );
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
          key: const Key('resource-manager-shell'),
          body: AnimatedBuilder(
            animation: widget.issueCenterController,
            builder: (BuildContext context, _) => Row(
              children: <Widget>[
                _WorkspaceSidebar(
                  selectedIndex: _selectedIndex,
                  issueCount: widget.issueCenterController.count,
                  onSelected: (int value) => _selectDestination(
                    ResourceManagerDestination.values[value],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: switch (ResourceManagerDestination
                      .values[_selectedIndex]) {
                    ResourceManagerDestination.resources => LibraryScreen(
                      viewModel: widget.viewModel,
                      transferGateway: FileSelectorLibraryTransferGateway(),
                      contextMenuGateway: widget.desktopContextMenuGateway,
                      onOpenExternalLink: widget.onOpenExternalLink,
                    ),
                    ResourceManagerDestination.clipboard =>
                      ClipboardManagerScreen(
                        viewModel: widget.clipboardViewModel,
                        contextMenuGateway: widget.desktopContextMenuGateway,
                      ),
                    ResourceManagerDestination.recentAgents =>
                      AgentActivityManagerScreen(
                        controller: widget.activityController,
                        conversationLauncher: _agentConversationLauncher,
                      ),
                    ResourceManagerDestination.issues => IssueCenterScreen(
                      controller: widget.issueCenterController,
                      onOpenResource: _openIssueResource,
                    ),
                  },
                ),
              ],
            ),
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
    required this.issueCount,
    required this.onSelected,
  });

  final int selectedIndex;
  final int issueCount;
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
              const SizedBox(height: 3),
              _SidebarItem(
                key: const Key('resource-manager-nav-agent-activity'),
                icon: Icons.smart_toy_outlined,
                label: _localized(context, 'Recent agents', '最近 Agent'),
                selected: selectedIndex == 2,
                onTap: () => onSelected(2),
              ),
              const SizedBox(height: 3),
              _SidebarItem(
                key: const Key('resource-manager-nav-issues'),
                icon: Icons.error_outline_rounded,
                label: _localized(context, 'Issues', '问题'),
                selected: selectedIndex == 3,
                badgeCount: issueCount,
                onTap: () => onSelected(3),
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
    this.badgeCount = 0,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

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
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    key: const Key('resource-manager-issue-count'),
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBE9E7),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Color(0xFFB93A32),
                        fontSize: 9,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
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
