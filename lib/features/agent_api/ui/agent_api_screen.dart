import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/agent_api/domain/agent_api_gateway.dart';
import 'package:dingdong/features/agent_api/ui/mcp_setup_card.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';

/// Local API status, endpoint reference, and MCP setup workspace.
class AgentApiScreen extends StatelessWidget {
  const AgentApiScreen({
    required this.settingsViewModel,
    this.baseUri,
    this.clipboardGateway,
    this.apiGateway,
    super.key,
  });

  final SettingsViewModel settingsViewModel;
  final Uri? baseUri;
  final ClipboardGateway? clipboardGateway;
  final AgentApiGateway? apiGateway;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settingsViewModel,
      builder: (BuildContext context, Widget? child) {
        final Uri endpoint =
            baseUri ??
            Uri(
              scheme: 'http',
              host: '127.0.0.1',
              port: settingsViewModel.settings.apiPort,
            );
        final String origin = endpoint.toString().replaceFirst(
          RegExp(r'/$'),
          '',
        );
        return CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(36, 32, 36, 48),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Agent API',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.localized(
                            'Local-only automation for Codex, Claude, scripts, and desktop agents.',
                            '面向 Codex、Claude、脚本与桌面 Agent 的本机自动化接口。',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        _ServerStatus(origin: origin),
                        const SizedBox(height: 26),
                        _SectionTitle(
                          title: context.localized('Quick check', '快速检查'),
                          description: context.localized(
                            'Verify the loopback server without exposing it to the network.',
                            '在不暴露到网络的前提下验证回环服务。',
                          ),
                        ),
                        const SizedBox(height: 10),
                        _CommandRow(
                          command:
                              'curl --noproxy 127.0.0.1 -sS $origin/health',
                          copyKey: const Key('agent-api-copy-health'),
                          onCopy: _copy,
                        ),
                        const SizedBox(height: 10),
                        FilledButton.tonalIcon(
                          key: const Key('agent-api-test-ding'),
                          onPressed: () => _testDing(context, endpoint),
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: Text(
                            context.localized(
                              'Send test notification',
                              '发送测试通知',
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        _SectionTitle(
                          title: context.localized('Core endpoints', '核心端点'),
                          description: context.localized(
                            'Clipboard content remains metadata-only unless explicitly requested.',
                            '除非明确请求，否则剪贴板接口仅返回元数据。',
                          ),
                        ),
                        const SizedBox(height: 10),
                        const _EndpointTable(),
                        const SizedBox(height: 30),
                        _SectionTitle(
                          title: context.localized('MCP bridge', 'MCP 桥接'),
                          description: context.localized(
                            'Run the bundled stdio bridge from this checkout or package it with the release.',
                            '可从当前项目运行内置 stdio 桥接，也可随发行包一起分发。',
                          ),
                        ),
                        const SizedBox(height: 10),
                        _CommandRow(
                          command: settingsViewModel.mcpCommandPath,
                          onCopy: _copy,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.localized(
                            'The bridge advertises DingDong prompts, skills, MCP references, and notifications through JSON-RPC.',
                            '桥接通过 JSON-RPC 提供 DingDong 提示词、技能、MCP 引用与通知能力。',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        McpSetupCard(
                          settingsViewModel: settingsViewModel,
                          clipboardGateway: clipboardGateway,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _copy(String value) async {
    await clipboardGateway?.writeText(value);
  }

  Future<void> _testDing(BuildContext context, Uri endpoint) async {
    try {
      await (apiGateway ?? HttpAgentApiGateway()).testDing(endpoint);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localized('Test notification sent', '测试通知已发送'),
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localized(
                'Connection test failed: $error',
                '连接测试失败：$error',
              ),
            ),
          ),
        );
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(context.localized('Loopback service', '回环服务')),
                const SizedBox(height: 2),
                SelectableText(origin),
              ],
            ),
          ),
          Chip(label: Text(context.localized('Local only', '仅限本机'))),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 3),
        Text(description, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({
    required this.command,
    required this.onCopy,
    this.copyKey,
  });

  final String command;
  final ValueChanged<String> onCopy;
  final Key? copyKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SelectableText(
              command,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
            ),
          ),
          IconButton(
            key: copyKey,
            tooltip: context.localized('Copy', '复制'),
            onPressed: () => onCopy(command),
            icon: const Icon(Icons.copy_outlined, size: 18),
          ),
        ],
      ),
    );
  }
}

class _EndpointTable extends StatelessWidget {
  const _EndpointTable();

  @override
  Widget build(BuildContext context) {
    final List<(String, String, String)> rows = <(String, String, String)>[
      ('GET', '/health', context.localized('Service health', '服务健康状态')),
      ('POST', '/ding', context.localized('Desktop notification', '桌面通知')),
      ('GET', '/library', context.localized('Search resources', '搜索资源')),
      ('POST', '/library', context.localized('Create resource', '创建资源')),
      (
        'GET',
        '/clipboard/history',
        context.localized('Private history metadata', '私有历史元数据'),
      ),
      (
        'POST',
        '/clipboard/capture',
        context.localized('Capture current clipboard', '捕获当前剪贴板'),
      ),
      (
        'POST',
        '/clipboard/restore/{id}',
        context.localized('Restore one history item', '恢复单个历史条目'),
      ),
    ];
    return Column(
      children: rows
          .map(
            ((String, String, String) row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 54,
                    child: Text(
                      row.$1,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  SizedBox(width: 260, child: SelectableText(row.$2)),
                  Expanded(
                    child: Text(
                      row.$3,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
