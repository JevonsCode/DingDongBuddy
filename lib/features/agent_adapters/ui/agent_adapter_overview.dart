part of 'agent_adapter_screen.dart';

class _AdapterCatalogSummary extends StatelessWidget {
  const _AdapterCatalogSummary({required this.entries});

  final List<AgentAdapterEntry> entries;

  @override
  Widget build(BuildContext context) {
    final int detected = entries
        .where((AgentAdapterEntry entry) => entry.installed)
        .length;
    final int invalid = entries
        .where((AgentAdapterEntry entry) => !entry.isValid)
        .length;
    final String summary = _localized(
      context,
      '${entries.length} configurations · $detected directories detected'
          '${invalid == 0 ? '' : ' · $invalid invalid'}',
      '${entries.length} 个配置 · 检测到 $detected 个目录'
          '${invalid == 0 ? '' : ' · $invalid 个无效'}',
    );
    return Semantics(
      container: true,
      label: summary,
      child: Container(
        key: const Key('agent-adapter-catalog-summary'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerLow.withValues(alpha: 0.55),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              _localized(
                context,
                'Detection is not connection verification',
                '检测不等于连接验证',
              ),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdapterOverview extends StatelessWidget {
  const _AdapterOverview({required this.entry});

  final AgentAdapterEntry entry;

  @override
  Widget build(BuildContext context) {
    final AgentAdapter? adapter = entry.adapter;
    final bool hasSkills =
        adapter?.globalSkillPath != null && adapter?.projectSkillPath != null;
    final bool hasMcp = adapter?.mcpFilePath != null;
    final bool hasPrompt = adapter?.promptFilePath != null;
    return ListView(
      key: const Key('agent-adapter-status-overview'),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      children: <Widget>[
        _VerificationBoundaryNotice(entry: entry),
        const SizedBox(height: 14),
        Text(
          _localized(context, 'Configuration evidence', '配置证据'),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _EvidenceCard(
          children: <Widget>[
            _EvidenceRow(
              icon: entry.isValid
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              title: _localized(context, 'Adapter document', 'Adapter 文档'),
              value: entry.isValid
                  ? _localized(context, 'Valid', '有效')
                  : _localized(context, 'Invalid', '无效'),
              detail:
                  entry.error ??
                  _localized(
                    context,
                    'YAML structure and declared paths passed validation.',
                    'YAML 结构和声明路径已通过校验。',
                  ),
              positive: entry.isValid,
              warning: !entry.isValid,
            ),
            const Divider(height: 1),
            _EvidenceRow(
              icon: Icons.folder_outlined,
              title: _localized(context, 'Agent directory', 'Agent 目录'),
              value: entry.installed
                  ? _localized(context, 'Detected', '已检测到')
                  : _localized(context, 'Not detected', '未检测到'),
              detail:
                  adapter?.detectDirectory ??
                  _localized(
                    context,
                    'Unavailable because the Adapter is invalid.',
                    'Adapter 无效，无法读取检测路径。',
                  ),
              positive: entry.installed,
            ),
            const Divider(height: 1),
            _EvidenceRow(
              icon: Icons.hub_outlined,
              title: _localized(context, 'MCP configuration path', 'MCP 配置路径'),
              value: hasMcp
                  ? _localized(context, 'Declared', '已声明')
                  : _localized(context, 'Not declared', '未声明'),
              detail:
                  adapter?.mcpFilePath ??
                  _localized(
                    context,
                    'This Adapter does not declare an MCP file.',
                    '这个 Adapter 没有声明 MCP 文件。',
                  ),
              positive: hasMcp,
            ),
            const Divider(height: 1),
            _EvidenceRow(
              icon: Icons.description_outlined,
              title: _localized(
                context,
                'Prompt configuration path',
                'Prompt 配置路径',
              ),
              value: hasPrompt
                  ? _localized(context, 'Declared', '已声明')
                  : _localized(context, 'Not declared', '未声明'),
              detail:
                  adapter?.promptFilePath ??
                  _localized(
                    context,
                    'This Adapter does not declare a prompt file.',
                    '这个 Adapter 没有声明 Prompt 文件。',
                  ),
              positive: hasPrompt,
            ),
            const Divider(height: 1),
            _EvidenceRow(
              icon: Icons.layers_outlined,
              title: _localized(context, 'Skill paths', 'Skill 路径'),
              value: hasSkills
                  ? _localized(context, 'Declared', '已声明')
                  : _localized(context, 'Not declared', '未声明'),
              detail: hasSkills
                  ? '${adapter!.globalSkillPath}\n${adapter.projectSkillPath}'
                  : _localized(
                      context,
                      'This Adapter does not declare both global and project Skill paths.',
                      '这个 Adapter 没有同时声明全局与项目 Skill 路径。',
                    ),
              positive: hasSkills,
            ),
          ],
        ),
      ],
    );
  }
}

class _VerificationBoundaryNotice extends StatelessWidget {
  const _VerificationBoundaryNotice({required this.entry});

  final AgentAdapterEntry entry;

  @override
  Widget build(BuildContext context) {
    final String message = _localized(
      context,
      'What is known: DingDong ${entry.installed ? 'found' : 'did not find'} the declared Agent directory. A detected directory or declared path does not verify MCP, Hook, Bridge, authentication, or completion callbacks. Use Agent connections to verify the running local API and real completion signals.',
      '当前已知：DingDong ${entry.installed ? '检测到' : '未检测到'}声明的 Agent 目录。检测到目录或声明了路径，都不能证明 MCP、Hook、Bridge、鉴权或完成回调已连通；请在“Agent 连接”中验证本机 API 和真实完成回执。',
    );
    return Semantics(
      container: true,
      label: message,
      child: Container(
        key: const Key('agent-adapter-verification-boundary'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.tertiaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.tertiary.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.rule_folder_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _localized(
                      context,
                      'Connection has not been inferred',
                      '未推断连接成功',
                    ),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.positive,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final bool positive;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color accent = warning
        ? colors.error
        : positive
        ? colors.primary
        : colors.onSurfaceVariant;
    return Semantics(
      container: true,
      label: '$title. $value. $detail',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontFamily: detail.contains('/') ? 'Menlo' : null,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetectionBadge extends StatelessWidget {
  const _DetectionBadge({required this.installed});

  final bool? installed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String label = switch (installed) {
      true => _localized(context, 'Detected', '已检测'),
      false => _localized(context, 'Not detected', '未检测'),
      null => _localized(context, 'Not checked', '未检查'),
    };
    final Color foreground = installed == true
        ? colors.primary
        : colors.onSurfaceVariant;
    return Container(
      key: const Key('agent-adapter-detection-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: foreground.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
