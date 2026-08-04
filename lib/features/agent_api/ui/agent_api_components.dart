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
            label: context.localized('Back to Dynamic', '返回动态'),
            child: ExcludeSemantics(
              child: DesktopIconButton(
                key: const Key('agent-api-back'),
                tooltip: context.localized('Back to Dynamic', '返回动态'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
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
                context.localized('Agent connections', 'Agent 连接'),
                style: const TextStyle(
                  color: PopupStyle.textPrimary,
                  fontSize: 18,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                context.localized(
                  'Verify the local service and inspect real Agent signals.',
                  '验证本机服务，并查看真实的 Agent 信号。',
                ),
                style: const TextStyle(
                  color: PopupStyle.textSecondary,
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
        const Color(0xFF426A4B),
        const Color(0xFFEAF3EC),
        context.localized('Local service verified', '本机服务已验证'),
      ),
      _AgentHealthStatus.checking => (
        Icons.sync_rounded,
        PopupStyle.accent,
        PopupStyle.accentSoft,
        context.localized('Checking local service', '正在检查本机服务'),
      ),
      _AgentHealthStatus.unavailable => (
        Icons.error_outline_rounded,
        Theme.of(context).colorScheme.error,
        Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5),
        context.localized('Local service unavailable', '本机服务不可用'),
      ),
      _AgentHealthStatus.unknown => (
        Icons.help_outline_rounded,
        PopupStyle.textSecondary,
        PopupStyle.field,
        context.localized('Runtime status unverified', '运行状态尚未验证'),
      ),
    };
    final bool usingFallback =
        endpointIsVerified && actualPort != null && actualPort != preferredPort;
    final String statusDescription = switch (status) {
      _AgentHealthStatus.healthy => context.localized(
        'The /health endpoint responded successfully.',
        '/health 已成功响应。',
      ),
      _AgentHealthStatus.checking => context.localized(
        'Waiting for the loopback health response.',
        '正在等待本机回环健康检查。',
      ),
      _AgentHealthStatus.unavailable => context.localized(
        'The runtime endpoint did not pass its health check.',
        '实际运行地址未通过健康检查。',
      ),
      _AgentHealthStatus.unknown => context.localized(
        'Only the configured preferred port is known.',
        '目前只知道设置中的首选端口。',
      ),
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
                color: PopupStyle.surface,
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
                    style: const TextStyle(
                      color: PopupStyle.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SelectableText(
                    origin,
                    key: const Key('agent-api-runtime-endpoint'),
                    style: const TextStyle(
                      color: PopupStyle.textSecondary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    usingFallback
                        ? context.localized(
                            'Preferred port $preferredPort was unavailable; using $actualPort.',
                            '首选端口 $preferredPort 不可用，当前使用 $actualPort。',
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
                          : PopupStyle.textSecondary,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                  if (error != null && status == _AgentHealthStatus.unavailable)
                    Tooltip(
                      message: error!,
                      child: Text(
                        context.localized(
                          'Open for details or retry.',
                          '可查看详情或重新检查。',
                        ),
                        style: TextStyle(color: color, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            if (onRetry != null)
              Semantics(
                button: true,
                label: context.localized('Recheck local service', '重新检查本机服务'),
                child: ExcludeSemantics(
                  child: DesktopIconButton(
                    key: const Key('agent-api-recheck'),
                    tooltip: context.localized(
                      'Recheck local service',
                      '重新检查本机服务',
                    ),
                    onPressed: status == _AgentHealthStatus.checking
                        ? null
                        : () => unawaited(onRetry!()),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
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
        ? context.localized(
            'No real Agent completion has been received yet',
            '尚未收到真实 Agent 完成回执',
          )
        : context.localized(
            'Last received from ${activity.source} at ${TimeOfDay.fromDateTime(activity.completedAt.toLocal()).format(context)}',
            '最近收到 ${activity.source} 回执 · ${TimeOfDay.fromDateTime(activity.completedAt.toLocal()).format(context)}',
          );
    return Container(
      key: const Key('agent-connection-checklist'),
      decoration: PopupStyle.card(radius: 8),
      child: Column(
        children: <Widget>[
          _ConnectionRow(
            icon: Icons.dns_outlined,
            title: context.localized('Local API', '本机 API'),
            detail: switch (healthStatus) {
              _AgentHealthStatus.healthy => context.localized(
                'Health check passed',
                '健康检查已通过',
              ),
              _AgentHealthStatus.checking => context.localized(
                'Checking',
                '检查中',
              ),
              _AgentHealthStatus.unavailable => context.localized(
                'Health check failed',
                '健康检查失败',
              ),
              _AgentHealthStatus.unknown => context.localized(
                'Not verified',
                '尚未验证',
              ),
            },
            good: healthStatus == _AgentHealthStatus.healthy,
          ),
          const Divider(height: 1),
          _ConnectionRow(
            icon: Icons.notifications_active_outlined,
            title: context.localized('Agent completion signal', 'Agent 完成回执'),
            detail: activityDetail,
            good: activity != null,
            onTap: onManageAgents,
          ),
          const Divider(height: 1),
          _ConnectionRow(
            icon: issueCount == 0
                ? Icons.fact_check_outlined
                : Icons.warning_amber_rounded,
            title: context.localized('Known configuration issues', '已知配置问题'),
            detail: issueCount == 0
                ? context.localized(
                    'No known issue; this is not a connection guarantee',
                    '未发现已知问题；不代表连接已验证',
                  )
                : context.localized(
                    '$issueCount issue(s) need attention',
                    '$issueCount 个问题需要处理',
                  ),
            good: issueCount == 0,
            warning: issueCount > 0,
            onTap: onOpenIssues,
          ),
          const Divider(height: 1),
          _ConnectionRow(
            icon: Icons.content_paste_outlined,
            title: context.localized('Clipboard body access', '剪贴板正文访问'),
            detail: clipboardContentAllowed
                ? context.localized(
                    'Allowed by the explicit Settings switch',
                    '已通过设置中的明确开关允许',
                  )
                : context.localized('Metadata only', '仅允许元数据'),
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
        : PopupStyle.textSecondary;
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
                  style: const TextStyle(
                    color: PopupStyle.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PopupStyle.textSecondary,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 17,
              color: PopupStyle.textSecondary,
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
    final String label = context.localized(
      'Advanced API and MCP details',
      '高级 API 与 MCP 信息',
    );
    return Semantics(
      button: true,
      expanded: expanded,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: PopupStyle.field,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            key: const Key('agent-api-toggle-advanced'),
            onTap: onToggle,
            borderRadius: BorderRadius.circular(7),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.terminal_rounded,
                    size: 17,
                    color: PopupStyle.textSecondary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          label,
                          style: const TextStyle(
                            color: PopupStyle.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.localized(
                            'Endpoints, commands, and setup prompt',
                            '端点、命令与接入提示词',
                          ),
                          style: const TextStyle(
                            color: PopupStyle.textSecondary,
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
                    color: PopupStyle.textSecondary,
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
          style: const TextStyle(
            color: PopupStyle.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          description,
          style: const TextStyle(
            color: PopupStyle.textSecondary,
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
        color: PopupStyle.field,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SelectableText(
              command,
              style: const TextStyle(
                color: PopupStyle.textPrimary,
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
            label: copied
                ? context.localized('Copied', '已复制')
                : context.localized('Copy', '复制'),
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
        description: context.localized('Service health', '服务健康状态'),
      ),
      _EndpointData(
        id: 'ding',
        method: 'POST',
        path: '/ding',
        description: context.localized('Desktop notification', '桌面通知'),
      ),
      _EndpointData(
        id: 'library-search',
        method: 'GET',
        path: '/library',
        description: context.localized('Search resources', '搜索资源'),
      ),
      _EndpointData(
        id: 'library-create',
        method: 'POST',
        path: '/library',
        description: context.localized('Create resource', '创建资源'),
      ),
      _EndpointData(
        id: 'clipboard-history',
        method: 'GET',
        path: '/clipboard/history',
        description: context.localized('Private history metadata', '私有历史元数据'),
      ),
      _EndpointData(
        id: 'clipboard-capture',
        method: 'POST',
        path: '/clipboard/capture',
        description: context.localized('Capture current clipboard', '捕获当前剪贴板'),
      ),
      _EndpointData(
        id: 'clipboard-restore',
        method: 'POST',
        path: '/clipboard/restore/{id}',
        description: context.localized('Restore one history item', '恢复单个历史条目'),
      ),
    ];
    return Column(
      children: <Widget>[
        for (int index = 0; index < rows.length; index += 1) ...<Widget>[
          _EndpointRow(data: rows[index]),
          if (index != rows.length - 1)
            const Divider(height: 1, color: Color(0xFFE7E7E3)),
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
              color: get ? PopupStyle.accentSoft : const Color(0xFFF1EBDD),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              data.method,
              style: TextStyle(
                color: get ? PopupStyle.accent : const Color(0xFF75684F),
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
                  style: const TextStyle(
                    color: PopupStyle.textPrimary,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.description,
                  style: const TextStyle(
                    color: PopupStyle.textSecondary,
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
