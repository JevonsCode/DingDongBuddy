import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/features/agent_api/domain/agent_api_gateway.dart';
import 'package:dingdong/features/agent_api/ui/mcp_setup_card.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';

/// Local API status, endpoint reference, and MCP setup workspace.
class AgentApiScreen extends StatefulWidget {
  const AgentApiScreen({
    required this.settingsViewModel,
    this.baseUri,
    this.clipboardGateway,
    this.apiGateway,
    this.focusMcpOnOpen = false,
    this.onMcpFocusHandled,
    super.key,
  });

  final SettingsViewModel settingsViewModel;
  final Uri? baseUri;
  final ClipboardGateway? clipboardGateway;
  final AgentApiGateway? apiGateway;
  final bool focusMcpOnOpen;
  final VoidCallback? onMcpFocusHandled;

  @override
  State<AgentApiScreen> createState() => _AgentApiScreenState();
}

class _AgentApiScreenState extends State<AgentApiScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _mcpAccessKey = GlobalKey();
  Timer? _copyResetTimer;
  String? _copiedCommand;
  String? _testStatus;
  bool _testFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusMcpOnOpen) _scheduleMcpFocus();
  }

  @override
  void didUpdateWidget(covariant AgentApiScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.focusMcpOnOpen && widget.focusMcpOnOpen) {
      _scheduleMcpFocus();
    }
  }

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleMcpFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final BuildContext? target = _mcpAccessKey.currentContext;
      if (!mounted || target == null) return;
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOutCubic,
        alignment: 0.04,
      );
      if (mounted) widget.onMcpFocusHandled?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.settingsViewModel,
      builder: (BuildContext context, Widget? child) {
        final Uri endpoint =
            widget.baseUri ??
            Uri(
              scheme: 'http',
              host: '127.0.0.1',
              port: widget.settingsViewModel.settings.apiPort,
            );
        final String origin = endpoint.toString().replaceFirst(
          RegExp(r'/$'),
          '',
        );
        final String healthCommand =
            'curl --noproxy 127.0.0.1 -sS $origin/health';
        final String mcpCommand = widget.settingsViewModel.mcpCommandPath;
        return CustomScrollView(
          key: const Key('agent-api-scroll'),
          controller: _scrollController,
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Agent API',
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
                        'Local automation and MCP access for desktop agents.',
                        '面向桌面 Agent 的本机自动化与 MCP 接入。',
                      ),
                      style: const TextStyle(
                        color: PopupStyle.textSecondary,
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ServerStatus(origin: origin),
                    const SizedBox(height: 24),
                    _SectionTitle(
                      title: context.localized('Quick check', '快速检查'),
                      description: context.localized(
                        'Verify the local service without exposing it to the network.',
                        '无需暴露到网络即可验证本机服务。',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CommandRow(
                      command: healthCommand,
                      copyKey: const Key('agent-api-copy-health'),
                      copied: _copiedCommand == healthCommand,
                      onCopy: () => _copy(healthCommand),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          key: const Key('agent-api-test-ding'),
                          onPressed: () => _testDing(endpoint),
                          style: FilledButton.styleFrom(
                            elevation: 0,
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            size: 17,
                          ),
                          label: Text(
                            context.localized(
                              'Send test notification',
                              '发送测试通知',
                            ),
                          ),
                        ),
                        if (_testStatus != null) ...<Widget>[
                          const SizedBox(height: 7),
                          Text(
                            _testStatus!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _testFailed
                                  ? Theme.of(context).colorScheme.error
                                  : PopupStyle.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 26),
                    _SectionTitle(
                      title: context.localized('Core endpoints', '核心端点'),
                      description: context.localized(
                        'Clipboard content stays metadata-only unless explicitly requested.',
                        '除非明确请求，否则剪贴板内容只返回元数据。',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _EndpointList(),
                    const SizedBox(height: 28),
                    Column(
                      key: _mcpAccessKey,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _SectionTitle(
                          key: const Key('agent-api-mcp-access'),
                          title: context.localized('MCP access', 'MCP 接入'),
                          description: context.localized(
                            'Connect the current Agent to DingDong and verify it with a real notification.',
                            '让当前 Agent 接入 DingDong，并通过真实通知完成验证。',
                          ),
                        ),
                        const SizedBox(height: 10),
                        _CommandRow(
                          command: mcpCommand,
                          copied: _copiedCommand == mcpCommand,
                          onCopy: () => _copy(mcpCommand),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          context.localized(
                            'The bundled bridge exposes prompts, skills, MCP references, and notifications through JSON-RPC.',
                            '内置桥接通过 JSON-RPC 提供提示词、技能、MCP 引用与通知能力。',
                          ),
                          style: const TextStyle(
                            color: PopupStyle.textSecondary,
                            fontSize: 10,
                            height: 1.35,
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
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _copy(String value) async {
    final ClipboardGateway? clipboard = widget.clipboardGateway;
    if (clipboard == null) return;
    await clipboard.writeText(value);
    if (!mounted) return;
    _copyResetTimer?.cancel();
    setState(() => _copiedCommand = value);
    _copyResetTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted && _copiedCommand == value) {
        setState(() => _copiedCommand = null);
      }
    });
  }

  Future<void> _testDing(Uri endpoint) async {
    try {
      await (widget.apiGateway ?? HttpAgentApiGateway()).testDing(endpoint);
      if (mounted) {
        setState(() {
          _testFailed = false;
          _testStatus = context.localized('Test notification sent', '测试通知已发送');
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _testFailed = true;
          _testStatus = context.localized(
            'Connection test failed: $error',
            '连接测试失败：$error',
          );
        });
      }
    }
  }
}

class _ServerStatus extends StatelessWidget {
  const _ServerStatus({required this.origin});

  final String origin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
      decoration: BoxDecoration(
        color: PopupStyle.accentSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PopupStyle.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 17,
              color: PopupStyle.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.localized('Local service is online', '本机服务已在线'),
                  style: const TextStyle(
                    color: PopupStyle.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  origin,
                  style: const TextStyle(
                    color: PopupStyle.textSecondary,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: PopupStyle.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              context.localized('LOCAL', '本机'),
              style: const TextStyle(
                color: PopupStyle.accent,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
            fontSize: 10,
            height: 1.35,
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
          TextButton.icon(
            key: copyKey,
            onPressed: onCopy,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: copied
                  ? PopupStyle.success
                  : PopupStyle.textSecondary,
              backgroundColor: copied
                  ? PopupStyle.success.withValues(alpha: 0.10)
                  : PopupStyle.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            icon: Icon(
              copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 15,
            ),
            label: Text(
              copied
                  ? context.localized('Copied', '已复制')
                  : context.localized('Copy', '复制'),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
            ),
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
                fontSize: 8,
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
                    fontSize: 9,
                    height: 1.25,
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
