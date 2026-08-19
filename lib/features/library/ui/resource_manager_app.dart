import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_locale.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/platform/windows_auxiliary_window_close_behavior.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/activity/ui/agent_activity_manager_screen.dart';
import 'package:dingdong/features/agent_adapters/data/agent_adapter_repository.dart';
import 'package:dingdong/features/agent_adapters/ui/agent_adapter_controller.dart';
import 'package:dingdong/features/agent_adapters/ui/agent_adapter_screen.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_manager_screen.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/issue_center/domain/app_issue.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_screen.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:dingdong/features/library/ui/library_screen.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/library/ui/resource_editor.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/platform/file_selector_library_transfer_gateway.dart';
import 'package:dingdong/platform/native_agent_conversation_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    this.agentAdapterController,
    this.initialDestination = ResourceManagerDestination.resources,
    this.openClipboardCategoriesOnLaunch = false,
    this.resourceManagerLauncher,
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
  final AgentAdapterController? agentAdapterController;
  final AppSettings settings;
  final WindowController windowController;
  final ResourceManagerDestination initialDestination;
  final bool openClipboardCategoriesOnLaunch;
  final ResourceManagerLauncher? resourceManagerLauncher;
  final AgentConversationLauncher? agentConversationLauncher;
  final DesktopContextMenuGateway? desktopContextMenuGateway;
  final Future<List<AppIssue>> Function()? onLoadHostIssues;
  final Future<void> Function(Uri uri)? onOpenExternalLink;

  @override
  State<ResourceManagerApp> createState() => _ResourceManagerAppState();
}

class _ResourceManagerAppState extends State<ResourceManagerApp>
    with
        WindowListener,
        WindowsAuxiliaryWindowCloseBehavior<ResourceManagerApp> {
  int _selectedIndex = 0;
  int _clipboardCategoryRequestRevision = 0;
  final GlobalKey<LibraryScreenState> _libraryScreenKey =
      GlobalKey<LibraryScreenState>();
  late final AgentConversationLauncher _agentConversationLauncher;

  @override
  void initState() {
    super.initState();
    enableWindowsHideOnClose();
    _selectedIndex = widget.initialDestination.index;
    _clipboardCategoryRequestRevision = widget.openClipboardCategoriesOnLaunch
        ? 1
        : 0;
    _agentConversationLauncher =
        widget.agentConversationLauncher ?? NativeAgentConversationLauncher();
    _preflightActivityTargets();
    unawaited(_loadHostIssues());
    unawaited(
      widget.windowController.setWindowMethodHandler((call) async {
        switch (call.method) {
          case 'window_focus':
            await widget.viewModel.load();
            widget.clipboardViewModel.load();
            widget.activityController.reload();
            _preflightActivityTargets();
            await widget.agentAdapterController?.load();
            final ResourceManagerDestination destination =
                ResourceManagerDestination.parse(call.arguments);
            if (destination == ResourceManagerDestination.issues) {
              await _loadHostIssues();
            }
            await _selectDestination(destination);
            await windowManager.focus();
          case 'clipboard_changed':
            widget.clipboardViewModel.load();
          case manageClipboardCategoriesMethod:
            await _selectDestination(ResourceManagerDestination.clipboard);
            if (mounted &&
                _selectedIndex == ResourceManagerDestination.clipboard.index) {
              setState(() => _clipboardCategoryRequestRevision += 1);
            }
          case 'edit_resource':
            final Object? arguments = call.arguments;
            final String? id = arguments is Map
                ? arguments['id'] as String?
                : null;
            if (id != null && await _confirmDiscardLibraryChanges()) {
              _selectResource(id);
            }
          case 'create_resource':
            final ResourceManagerCreateRequest? request =
                ResourceManagerCreateRequest.fromJson(call.arguments);
            if (request != null && await _confirmDiscardLibraryChanges()) {
              await widget.viewModel.load();
              await _selectDestination(ResourceManagerDestination.resources);
              widget.viewModel.startCreating(
                type: request.type,
                title: request.title,
                content: request.content,
              );
            }
          default:
            return;
        }
      }),
    );
  }

  void _preflightActivityTargets() {
    final AgentConversationLauncher launcher = _agentConversationLauncher;
    if (launcher is! NativeAgentConversationLauncher) {
      return;
    }
    unawaited(
      launcher.preflight(
        widget.activityController.activities
            .map((AgentActivity activity) => activity.conversationTarget)
            .whereType<AgentConversationTarget>(),
      ),
    );
  }

  Future<bool> _confirmDiscardLibraryChanges() async {
    final LibraryScreenState? library = _libraryScreenKey.currentState;
    return library == null || await library.confirmDiscardChanges();
  }

  @override
  void dispose() {
    widget.agentAdapterController?.dispose();
    super.dispose();
  }

  Future<void> _selectDestination(
    ResourceManagerDestination destination,
  ) async {
    if (destination.index != _selectedIndex &&
        _selectedIndex == ResourceManagerDestination.resources.index) {
      if (!await _confirmDiscardLibraryChanges()) {
        return;
      }
    }
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
      onGenerateTitle: (BuildContext context) =>
          context.l10n.resourceManagerWindowTitle,
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
          label: context.l10n.dingdongResourceManagerWindow,
          child: Scaffold(
            key: const Key('resource-manager-shell'),
            body: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[
                widget.issueCenterController,
                if (widget.agentAdapterController != null)
                  widget.agentAdapterController!,
              ]),
              builder: (BuildContext context, _) => Row(
                children: <Widget>[
                  _WorkspaceSidebar(
                    selectedIndex: _selectedIndex,
                    issueCount: widget.issueCenterController.count,
                    onSelected: (int value) => unawaited(
                      _selectDestination(
                        ResourceManagerDestination.values[value],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: switch (ResourceManagerDestination
                        .values[_selectedIndex]) {
                      ResourceManagerDestination.resources => LibraryScreen(
                        key: _libraryScreenKey,
                        viewModel: widget.viewModel,
                        skillAgents: _skillDeliveryAgents(),
                        transferGateway: FileSelectorLibraryTransferGateway(
                          () => appLocalizationsFor(widget.settings.language),
                        ),
                        contextMenuGateway: widget.desktopContextMenuGateway,
                        onOpenExternalLink: widget.onOpenExternalLink,
                      ),
                      ResourceManagerDestination.clipboard =>
                        ClipboardManagerScreen(
                          viewModel: widget.clipboardViewModel,
                          contextMenuGateway: widget.desktopContextMenuGateway,
                          resourceManagerLauncher:
                              widget.resourceManagerLauncher,
                          categoryManagementRequestRevision:
                              _clipboardCategoryRequestRevision,
                        ),
                      ResourceManagerDestination.recentAgents =>
                        AgentActivityManagerScreen(
                          controller: widget.activityController,
                          conversationLauncher: _agentConversationLauncher,
                          showConversationTokenUsage:
                              widget.settings.showConversationTokenUsage,
                        ),
                      ResourceManagerDestination.agentAdapters =>
                        widget.agentAdapterController == null
                            ? const SizedBox.shrink()
                            : AgentAdapterScreen(
                                controller: widget.agentAdapterController!,
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
      ),
    );
  }

  List<SkillDeliveryAgentOption> _skillDeliveryAgents() {
    final List<SkillDeliveryAgentOption> result =
        (widget.agentAdapterController?.entries ?? const <AgentAdapterEntry>[])
            .where(
              (AgentAdapterEntry entry) =>
                  entry.isValid &&
                  entry.adapter!.globalSkillPath != null &&
                  entry.adapter!.projectSkillPath != null,
            )
            .map(
              (AgentAdapterEntry entry) => SkillDeliveryAgentOption(
                id: entry.id,
                label: entry.displayName,
                available: entry.installed,
              ),
            )
            .toList(growable: false);
    return widget.agentAdapterController == null
        ? ResourceEditor.defaultSkillDeliveryAgents
        : result;
  }
}

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
        width: 176,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 20, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'DingDong',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  context.l10n.workspace,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.45,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _SidebarItem(
                key: const Key('resource-manager-nav-resources'),
                symbol: 'library',
                label: context.l10n.resources,
                selected:
                    selectedIndex == ResourceManagerDestination.resources.index,
                onTap: () =>
                    onSelected(ResourceManagerDestination.resources.index),
              ),
              const SizedBox(height: 3),
              _SidebarItem(
                key: const Key('resource-manager-nav-clipboard'),
                symbol: 'clipboard',
                label: context.l10n.clipboard,
                selected:
                    selectedIndex == ResourceManagerDestination.clipboard.index,
                onTap: () =>
                    onSelected(ResourceManagerDestination.clipboard.index),
              ),
              const SizedBox(height: 3),
              _SidebarItem(
                key: const Key('resource-manager-nav-agent-activity'),
                icon: Icons.smart_toy_outlined,
                label: context.l10n.recentAgents,
                selected:
                    selectedIndex ==
                    ResourceManagerDestination.recentAgents.index,
                onTap: () =>
                    onSelected(ResourceManagerDestination.recentAgents.index),
              ),
              const SizedBox(height: 3),
              _SidebarItem(
                key: const Key('resource-manager-nav-agent-adapters'),
                icon: Icons.hub_outlined,
                label: context.l10n.agentAccess,
                selected:
                    selectedIndex ==
                    ResourceManagerDestination.agentAdapters.index,
                onTap: () =>
                    onSelected(ResourceManagerDestination.agentAdapters.index),
              ),
              const SizedBox(height: 3),
              _SidebarItem(
                key: const Key('resource-manager-nav-issues'),
                icon: Icons.error_outline_rounded,
                label: context.l10n.issues,
                selected:
                    selectedIndex == ResourceManagerDestination.issues.index,
                badgeCount: issueCount,
                onTap: () =>
                    onSelected(ResourceManagerDestination.issues.index),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  context.l10n.storedOnThisDevice,
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

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    this.icon,
    this.symbol,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
    super.key,
  });

  final IconData? icon;
  final String? symbol;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;
  bool _focused = false;

  void _activate() => widget.onTap();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool selected = widget.selected;
    final Color fill = selected
        ? colors.primary.withValues(alpha: 0.085)
        : (_hovered || _focused)
        ? colors.onSurface.withValues(alpha: 0.038)
        : Colors.transparent;
    return Semantics(
      button: true,
      selected: selected,
      label: widget.label,
      onTap: _activate,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _activate();
                return null;
              },
            ),
          },
          onShowFocusHighlight: (bool value) {
            if (_focused != value) setState(() => _focused = value);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _activate,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _focused
                      ? colors.primary.withValues(alpha: 0.5)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: <Widget>[
                  if (widget.symbol != null)
                    PopupSymbolIcon(
                      widget.symbol!,
                      size: 16,
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    )
                  else
                    Icon(
                      widget.icon,
                      size: 16,
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (widget.badgeCount > 0)
                    Container(
                      key: const Key('resource-manager-issue-count'),
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        widget.badgeCount > 99 ? '99+' : '${widget.badgeCount}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.error,
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
      ),
    );
  }
}
