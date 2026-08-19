import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/agent_api/domain/agent_api_gateway.dart';
import 'package:dingdong/features/agent_api/ui/mcp_setup_card.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';

part 'agent_api_components.dart';

/// Truthful runtime status, verification, and advanced Agent setup details.
class AgentApiScreen extends StatefulWidget {
  const AgentApiScreen({
    required this.settingsViewModel,
    this.baseUri,
    this.clipboardGateway,
    this.apiGateway,
    this.activityController,
    this.issueCenterController,
    this.resourceManagerLauncher,
    this.focusMcpOnOpen = false,
    this.onMcpFocusHandled,
    this.onBack,
    super.key,
  });

  final SettingsViewModel settingsViewModel;

  /// The endpoint actually bound by the running server.
  ///
  /// A null value means the caller has not supplied a verified runtime
  /// endpoint. The configured preference must not be presented as listening.
  final Uri? baseUri;
  final ClipboardGateway? clipboardGateway;
  final AgentApiGateway? apiGateway;
  final ActivityController? activityController;
  final IssueCenterController? issueCenterController;
  final ResourceManagerLauncher? resourceManagerLauncher;
  final bool focusMcpOnOpen;
  final VoidCallback? onMcpFocusHandled;
  final VoidCallback? onBack;

  @override
  State<AgentApiScreen> createState() => _AgentApiScreenState();
}

enum _AgentHealthStatus { unknown, checking, healthy, unavailable }

class _AgentApiScreenState extends State<AgentApiScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _mcpAccessKey = GlobalKey();
  Timer? _copyResetTimer;
  String? _copiedCommand;
  String? _testStatus;
  String? _healthError;
  bool _testFailed = false;
  bool _advancedExpanded = false;
  _AgentHealthStatus _healthStatus = _AgentHealthStatus.unknown;
  late AgentApiGateway _gateway;
  late bool _ownsGateway;

  @override
  void initState() {
    super.initState();
    _setGateway();
    _advancedExpanded = widget.focusMcpOnOpen;
    _scheduleHealthCheck();
    if (widget.focusMcpOnOpen) {
      _scheduleMcpFocus();
    }
  }

  @override
  void didUpdateWidget(covariant AgentApiScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiGateway != widget.apiGateway) {
      _closeOwnedGateway();
      _setGateway();
    }
    if (oldWidget.baseUri != widget.baseUri ||
        oldWidget.apiGateway != widget.apiGateway) {
      _scheduleHealthCheck();
    }
    if (!oldWidget.focusMcpOnOpen && widget.focusMcpOnOpen) {
      setState(() => _advancedExpanded = true);
      _scheduleMcpFocus();
    }
  }

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    _scrollController.dispose();
    _closeOwnedGateway();
    super.dispose();
  }

  void _setGateway() {
    _ownsGateway = widget.apiGateway == null;
    _gateway = widget.apiGateway ?? HttpAgentApiGateway();
  }

  void _closeOwnedGateway() {
    if (_ownsGateway && _gateway is HttpAgentApiGateway) {
      (_gateway as HttpAgentApiGateway).close();
    }
  }

  void _scheduleHealthCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_checkHealth());
      }
    });
  }

  Future<void> _checkHealth() async {
    final Uri? endpoint = widget.baseUri;
    if (endpoint == null) {
      if (mounted) {
        setState(() {
          _healthStatus = _AgentHealthStatus.unknown;
          _healthError = null;
        });
      }
      return;
    }
    setState(() {
      _healthStatus = _AgentHealthStatus.checking;
      _healthError = null;
    });
    try {
      await _gateway.checkHealth(endpoint);
      if (mounted) {
        setState(() => _healthStatus = _AgentHealthStatus.healthy);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _healthStatus = _AgentHealthStatus.unavailable;
          _healthError = error.toString();
        });
      }
    }
  }

  void _scheduleMcpFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final BuildContext? target = _mcpAccessKey.currentContext;
      if (!mounted || target == null) {
        return;
      }
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
        alignment: 0.04,
      );
      if (mounted) {
        widget.onMcpFocusHandled?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Listenable> listenables = <Listenable>[
      widget.settingsViewModel,
      if (widget.activityController != null) widget.activityController!,
      if (widget.issueCenterController != null) widget.issueCenterController!,
    ];
    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (BuildContext context, Widget? child) {
        final int preferredPort = widget.settingsViewModel.settings.apiPort;
        final Uri preferredEndpoint = Uri(
          scheme: 'http',
          host: '127.0.0.1',
          port: preferredPort,
        );
        final Uri displayEndpoint = widget.baseUri ?? preferredEndpoint;
        final String origin = displayEndpoint.toString().replaceFirst(
          RegExp(r'/$'),
          '',
        );
        final String healthCommand =
            'curl --noproxy 127.0.0.1 -sS $origin/health';
        final String mcpCommand = widget.settingsViewModel.mcpCommandPath;
        final List<AgentActivity> activities =
            widget.activityController?.activities ?? const <AgentActivity>[];
        final AgentActivity? latestActivity = activities.isEmpty
            ? null
            : activities.first;
        final int issueCount = widget.issueCenterController?.count ?? 0;
        return Semantics(
          container: true,
          explicitChildNodes: true,
          label: context.l10n.agentConnectionCenter,
          child: CustomScrollView(
            key: const Key('agent-api-scroll'),
            controller: _scrollController,
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _ConnectionHeader(onBack: widget.onBack),
                      const SizedBox(height: 14),
                      _ConnectionHealthCard(
                        status: _healthStatus,
                        origin: origin,
                        endpointIsVerified: widget.baseUri != null,
                        preferredPort: preferredPort,
                        actualPort: widget.baseUri?.port,
                        error: _healthError,
                        onRetry: widget.baseUri == null ? null : _checkHealth,
                      ),
                      const SizedBox(height: 12),
                      _ConnectionChecklist(
                        healthStatus: _healthStatus,
                        latestActivity: latestActivity,
                        issueCount: issueCount,
                        clipboardContentAllowed: widget
                            .settingsViewModel
                            .settings
                            .allowAgentClipboardContent,
                        onManageAgents: widget.resourceManagerLauncher == null
                            ? null
                            : () => unawaited(
                                widget.resourceManagerLauncher!.show(
                                  destination:
                                      ResourceManagerDestination.agentAdapters,
                                ),
                              ),
                        onOpenIssues:
                            widget.resourceManagerLauncher == null ||
                                issueCount == 0
                            ? null
                            : () => unawaited(
                                widget.resourceManagerLauncher!.show(
                                  destination:
                                      ResourceManagerDestination.issues,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          DesktopActionButton(
                            key: const Key('agent-api-test-ding'),
                            onPressed: widget.baseUri == null
                                ? null
                                : _testDing,
                            icon: Icon(
                              Icons.notifications_none_rounded,
                              size: 17,
                            ),
                            label: context.l10n.sendTestNotification,
                            tone: DesktopActionTone.soft,
                          ),
                          if (widget.resourceManagerLauncher != null)
                            DesktopActionButton(
                              key: const Key('agent-api-manage-agents'),
                              onPressed: () => unawaited(
                                widget.resourceManagerLauncher!.show(
                                  destination:
                                      ResourceManagerDestination.agentAdapters,
                                ),
                              ),
                              icon: Icon(Icons.hub_outlined, size: 17),
                              label: context.l10n.manageAgents,
                              tone: DesktopActionTone.neutral,
                            ),
                        ],
                      ),
                      if (_testStatus != null) ...<Widget>[
                        const SizedBox(height: 7),
                        Text(
                          _testStatus!,
                          key: const Key('agent-api-test-status'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _testFailed
                                ? Theme.of(context).colorScheme.error
                                : const Color(0xFF426A4B),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _AdvancedDisclosure(
                        expanded: _advancedExpanded,
                        onToggle: () {
                          setState(
                            () => _advancedExpanded = !_advancedExpanded,
                          );
                        },
                      ),
                      if (_advancedExpanded) ...<Widget>[
                        const SizedBox(height: 14),
                        _SectionTitle(
                          title: context.l10n.runtimeCheck,
                          description: context
                              .l10n
                              .theCommandBelowUsesTheActualEndpointWhenTheRuntime_0a3909c7,
                        ),
                        const SizedBox(height: 9),
                        _CommandRow(
                          command: healthCommand,
                          copyKey: const Key('agent-api-copy-health'),
                          copied: _copiedCommand == healthCommand,
                          onCopy: () => _copy(healthCommand),
                        ),
                        const SizedBox(height: 22),
                        _SectionTitle(
                          title: context.l10n.coreEndpoints,
                          description: context
                              .l10n
                              .clipboardContentStaysMetadataOnlyUnlessExplicitlyEnabled_df1d930e,
                        ),
                        const SizedBox(height: 8),
                        const _EndpointList(),
                        const SizedBox(height: 24),
                        Column(
                          key: _mcpAccessKey,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _SectionTitle(
                              key: const Key('agent-api-mcp-access'),
                              title: context.l10n.mcpAccess,
                              description: context
                                  .l10n
                                  .advancedCommandsAndTheInstallationPromptTheirPresence_b84b4903,
                            ),
                            const SizedBox(height: 10),
                            _CommandRow(
                              command: mcpCommand,
                              copied: _copiedCommand == mcpCommand,
                              onCopy: () => _copy(mcpCommand),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              context
                                  .l10n
                                  .theBundledBridgeExposesPromptsSkillsMCPReferencesAnd_a0f4fd67,
                              style: TextStyle(
                                color: PopupStyle.of(context).textSecondary,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 18),
                            McpSetupCard(
                              settingsViewModel: widget.settingsViewModel,
                              clipboardGateway: widget.clipboardGateway,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _copy(String value) async {
    final ClipboardGateway? clipboard = widget.clipboardGateway;
    if (clipboard == null) {
      return;
    }
    await clipboard.writeText(value);
    if (!mounted) {
      return;
    }
    _copyResetTimer?.cancel();
    setState(() => _copiedCommand = value);
    _copyResetTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted && _copiedCommand == value) {
        setState(() => _copiedCommand = null);
      }
    });
  }

  Future<void> _testDing() async {
    final Uri? endpoint = widget.baseUri;
    if (endpoint == null) {
      return;
    }
    try {
      await _gateway.testDing(endpoint);
      if (mounted) {
        setState(() {
          _testFailed = false;
          _testStatus = context.l10n.testNotificationSent;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _testFailed = true;
          _testStatus = context.l10n.connectionTestFailedError(error);
        });
      }
    }
  }
}
