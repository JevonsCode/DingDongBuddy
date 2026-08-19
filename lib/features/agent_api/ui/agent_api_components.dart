part of 'agent_api_screen.dart';

class _ConnectionHeader extends StatelessWidget {
  const _ConnectionHeader({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (onBack != null) ...<Widget>[
          Semantics(
            button: true,
            label: context.l10n.backToDynamic,
            child: ExcludeSemantics(
              child: DesktopIconButton(
                key: const Key('agent-api-back'),
                tooltip: context.l10n.backToDynamic,
                onPressed: onBack,
                icon: Icon(Icons.arrow_back_rounded, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.agentConnections,
                style: TextStyle(
                  color: PopupStyle.of(context).textPrimary,
                  fontSize: 18,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                context.l10n.verifyTheLocalServiceAndInspectRealAgentSignals,
                style: TextStyle(
                  color: PopupStyle.of(context).textSecondary,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConnectionHealthCard extends StatelessWidget {
  const _ConnectionHealthCard({
    required this.status,
    required this.origin,
    required this.endpointIsVerified,
    required this.preferredPort,
    required this.actualPort,
    required this.error,
    required this.onRetry,
  });

  final _AgentHealthStatus status;
  final String origin;
  final bool endpointIsVerified;
  final int preferredPort;
  final int? actualPort;
  final String? error;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final (
      IconData icon,
      Color color,
      Color background,
      String title,
    ) = switch (status) {
      _AgentHealthStatus.healthy => (
        Icons.check_circle_outline_rounded,
        PopupStyle.of(context).success,
        PopupStyle.of(context).success.withValues(alpha: 0.14),
        context.l10n.localServiceVerified,
      ),
      _AgentHealthStatus.checking => (
        Icons.sync_rounded,
        PopupStyle.of(context).accent,
        PopupStyle.of(context).accentSoft,
        context.l10n.checkingLocalService,
      ),
      _AgentHealthStatus.unavailable => (
        Icons.error_outline_rounded,
        Theme.of(context).colorScheme.error,
        Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5),
        context.l10n.localServiceUnavailable,
      ),
      _AgentHealthStatus.unknown => (
        Icons.help_outline_rounded,
        PopupStyle.of(context).textSecondary,
        PopupStyle.of(context).field,
        context.l10n.runtimeStatusUnverified,
      ),
    };
    final bool usingFallback =
        endpointIsVerified && actualPort != null && actualPort != preferredPort;
    final String statusDescription = switch (status) {
      _AgentHealthStatus.healthy =>
        context.l10n.theHealthEndpointRespondedSuccessfully,
      _AgentHealthStatus.checking =>
        context.l10n.waitingForTheLoopbackHealthResponse,
      _AgentHealthStatus.unavailable =>
        context.l10n.theRuntimeEndpointDidNotPassItsHealthCheck,
      _AgentHealthStatus.unknown =>
        context.l10n.onlyTheConfiguredPreferredPortIsKnown,
    };
    return Semantics(
      container: true,
      label: '$title. $origin. $statusDescription',
      child: Container(
        key: const Key('agent-connection-health'),
        padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PopupStyle.of(context).surface,
                borderRadius: BorderRadius.circular(7),
              ),
              child: status == _AgentHealthStatus.checking
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      color: PopupStyle.of(context).textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SelectableText(
                    origin,
                    key: const Key('agent-api-runtime-endpoint'),
                    style: TextStyle(
                      color: PopupStyle.of(context).textSecondary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    usingFallback
                        ? context.l10n
                              .preferredPortPreferredPortWasUnavailableUsingActualPort(
                                preferredPort,
                                actualPort!,
                              )
                        : statusDescription,
                    key: usingFallback
                        ? const Key('agent-api-fallback-port')
                        : null,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: status == _AgentHealthStatus.unavailable
                          ? color
                          : PopupStyle.of(context).textSecondary,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                  if (error != null && status == _AgentHealthStatus.unavailable)
                    Tooltip(
                      message: error!,
                      child: Text(
                        context.l10n.openForDetailsOrRetry,
                        style: TextStyle(color: color, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            if (onRetry != null)
              Semantics(
                button: true,
                label: context.l10n.recheckLocalService,
                child: ExcludeSemantics(
                  child: DesktopIconButton(
                    key: const Key('agent-api-recheck'),
                    tooltip: context.l10n.recheckLocalService,
                    onPressed: status == _AgentHealthStatus.checking
                        ? null
                        : () => unawaited(onRetry!()),
                    icon: Icon(Icons.refresh_rounded, size: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionChecklist extends StatelessWidget {
  const _ConnectionChecklist({
    required this.healthStatus,
    required this.latestActivity,
    required this.issueCount,
    required this.clipboardContentAllowed,
    required this.onManageAgents,
    required this.onOpenIssues,
  });

  final _AgentHealthStatus healthStatus;
  final AgentActivity? latestActivity;
  final int issueCount;
  final bool clipboardContentAllowed;
  final VoidCallback? onManageAgents;
  final VoidCallback? onOpenIssues;

  @override
  Widget build(BuildContext context) {
    final AgentActivity? activity = latestActivity;
    final String activityDetail = activity == null
        ? context.l10n.noRealAgentCompletionHasBeenReceivedYet
        : context.l10n.lastReceivedFromSourceAtCompletedAt(
            activity.source,
            TimeOfDay.fromDateTime(
              activity.completedAt.toLocal(),
            ).format(context),
          );
    return Container(
      key: const Key('agent-connection-checklist'),
      decoration: PopupStyle.of(context).card(radius: 8),
      child: Column(
        children: <Widget>[
          _ConnectionRow(
            icon: Icons.dns_outlined,
            title: context.l10n.localAPI,
            detail: switch (healthStatus) {
              _AgentHealthStatus.healthy => context.l10n.healthCheckPassed,
              _AgentHealthStatus.checking => context.l10n.checking,
              _AgentHealthStatus.unavailable => context.l10n.healthCheckFailed,
              _AgentHealthStatus.unknown => context.l10n.notVerified,
            },
            good: healthStatus == _AgentHealthStatus.healthy,
          ),
          const Divider(height: 1),
          _ConnectionRow(
            icon: Icons.notifications_active_outlined,
            title: context.l10n.agentCompletionSignal,
            detail: activityDetail,
            good: activity != null,
            onTap: onManageAgents,
          ),
          const Divider(height: 1),
          _ConnectionRow(
            icon: issueCount == 0
                ? Icons.fact_check_outlined
                : Icons.warning_amber_rounded,
            title: context.l10n.knownConfigurationIssues,
            detail: issueCount == 0
                ? context.l10n.noKnownIssueThisIsNotAConnectionGuarantee
                : context.l10n.issuecountIssueSNeedAttention(issueCount),
            good: issueCount == 0,
            warning: issueCount > 0,
            onTap: onOpenIssues,
          ),
          const Divider(height: 1),
          _ConnectionRow(
            icon: Icons.content_paste_outlined,
            title: context.l10n.clipboardBodyAccess,
            detail: clipboardContentAllowed
                ? context.l10n.allowedByTheExplicitSettingsSwitch
                : context.l10n.metadataOnly,
            good: clipboardContentAllowed,
          ),
        ],
      ),
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.good,
    this.warning = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool good;
  final bool warning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = warning
        ? Theme.of(context).colorScheme.error
        : good
        ? const Color(0xFF426A4B)
        : PopupStyle.of(context).textSecondary;
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: PopupStyle.of(context).textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PopupStyle.of(context).textSecondary,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 17,
              color: PopupStyle.of(context).textSecondary,
            ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: '$title. $detail',
      child: ExcludeSemantics(
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

class _AdvancedDisclosure extends StatelessWidget {
  const _AdvancedDisclosure({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final String label = context.l10n.advancedAPIAndMCPDetails;
    return Semantics(
      button: true,
      expanded: expanded,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: PopupStyle.of(context).field,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            key: const Key('agent-api-toggle-advanced'),
            onTap: onToggle,
            borderRadius: BorderRadius.circular(7),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.terminal_rounded,
                    size: 17,
                    color: PopupStyle.of(context).textSecondary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          label,
                          style: TextStyle(
                            color: PopupStyle.of(context).textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.endpointsCommandsAndSetupPrompt,
                          style: TextStyle(
                            color: PopupStyle.of(context).textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 19,
                    color: PopupStyle.of(context).textSecondary,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.description,
    super.key,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            color: PopupStyle.of(context).textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          description,
          style: TextStyle(
            color: PopupStyle.of(context).textSecondary,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({
    required this.command,
    required this.copied,
    required this.onCopy,
    this.copyKey,
  });

  final String command;
  final bool copied;
  final VoidCallback onCopy;
  final Key? copyKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 8, 6, 8),
      decoration: BoxDecoration(
        color: PopupStyle.of(context).field,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SelectableText(
              command,
              style: TextStyle(
                color: PopupStyle.of(context).textPrimary,
                fontFamily: 'monospace',
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 6),
          DesktopActionButton(
            key: copyKey,
            onPressed: onCopy,
            icon: Icon(
              copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 15,
            ),
            label: copied ? context.l10n.copied : context.l10n.copy,
            tone: copied ? DesktopActionTone.soft : DesktopActionTone.neutral,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _EndpointList extends StatelessWidget {
  const _EndpointList();

  @override
  Widget build(BuildContext context) {
    final List<_EndpointData> rows = <_EndpointData>[
      _EndpointData(
        id: 'health',
        method: 'GET',
        path: '/health',
        description: context.l10n.serviceHealth,
      ),
      _EndpointData(
        id: 'ding',
        method: 'POST',
        path: '/ding',
        description: context.l10n.desktopNotification,
      ),
      _EndpointData(
        id: 'library-search',
        method: 'GET',
        path: '/library',
        description: context.l10n.searchResources,
      ),
      _EndpointData(
        id: 'library-create',
        method: 'POST',
        path: '/library',
        description: context.l10n.createResource,
      ),
      _EndpointData(
        id: 'clipboard-history',
        method: 'GET',
        path: '/clipboard/history',
        description: context.l10n.privateHistoryMetadata,
      ),
      _EndpointData(
        id: 'clipboard-capture',
        method: 'POST',
        path: '/clipboard/capture',
        description: context.l10n.captureCurrentClipboard,
      ),
      _EndpointData(
        id: 'clipboard-restore',
        method: 'POST',
        path: '/clipboard/restore/{id}',
        description: context.l10n.restoreOneHistoryItem,
      ),
    ];
    return Column(
      children: <Widget>[
        for (int index = 0; index < rows.length; index += 1) ...<Widget>[
          _EndpointRow(data: rows[index]),
          if (index != rows.length - 1)
            Divider(height: 1, color: PopupStyle.of(context).border),
        ],
      ],
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({required this.data});

  final _EndpointData data;

  @override
  Widget build(BuildContext context) {
    final bool get = data.method == 'GET';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: get
                  ? PopupStyle.of(context).accentSoft
                  : PopupStyle.of(context).warmSurface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              data.method,
              style: TextStyle(
                color: get
                    ? PopupStyle.of(context).accent
                    : PopupStyle.of(context).warmAccent,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            key: Key('agent-api-endpoint-description-${data.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SelectableText(
                  data.path,
                  style: TextStyle(
                    color: PopupStyle.of(context).textPrimary,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.description,
                  style: TextStyle(
                    color: PopupStyle.of(context).textSecondary,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EndpointData {
  const _EndpointData({
    required this.id,
    required this.method,
    required this.path,
    required this.description,
  });

  final String id;
  final String method;
  final String path;
  final String description;
}
