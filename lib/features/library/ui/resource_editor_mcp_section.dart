part of 'resource_editor.dart';

// MCP transport, credentials, and trigger-scope fields.
class _McpEditor extends StatelessWidget {
  const _McpEditor({
    required this.transport,
    required this.onTransportChanged,
    required this.commandController,
    required this.argumentsController,
    required this.environmentController,
    required this.urlController,
    required this.headersController,
    required this.tokenController,
    required this.rawController,
  });

  final McpTransport transport;
  final ValueChanged<McpTransport> onTransportChanged;
  final TextEditingController commandController;
  final TextEditingController argumentsController;
  final TextEditingController environmentController;
  final TextEditingController urlController;
  final TextEditingController headersController;
  final TextEditingController tokenController;
  final TextEditingController rawController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FieldLabel(text: context.l10n.connectionType),
        const SizedBox(height: 7),
        _FlatChoiceRow<McpTransport>(
          selected: transport,
          choices: <_Choice<McpTransport>>[
            const _Choice<McpTransport>(
              value: McpTransport.stdio,
              keyName: 'resource-mcp-transport-stdio',
              label: 'STDIO',
            ),
            const _Choice<McpTransport>(
              value: McpTransport.streamableHttp,
              keyName: 'resource-mcp-transport-http',
              label: 'HTTP',
            ),
            _Choice<McpTransport>(
              value: McpTransport.raw,
              keyName: 'resource-mcp-transport-raw',
              label: context.l10n.pasteConfig,
            ),
          ],
          onSelected: onTransportChanged,
        ),
        const SizedBox(height: 16),
        switch (transport) {
          McpTransport.stdio => _McpStdioFields(
            commandController: commandController,
            argumentsController: argumentsController,
            environmentController: environmentController,
          ),
          McpTransport.streamableHttp => _McpHttpFields(
            urlController: urlController,
            headersController: headersController,
            tokenController: tokenController,
          ),
          McpTransport.raw => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _FieldLabel(text: context.l10n.jsonTOMLOrYAMLConfiguration),
              const SizedBox(height: 7),
              _MultilineField(
                key: const Key('resource-mcp-raw'),
                controller: rawController,
                hintText: '{ "mcpServers": { ... } }',
                height: 220,
                monospace: true,
              ),
            ],
          ),
        },
      ],
    );
  }
}

class _McpStdioFields extends StatelessWidget {
  const _McpStdioFields({
    required this.commandController,
    required this.argumentsController,
    required this.environmentController,
  });

  final TextEditingController commandController;
  final TextEditingController argumentsController;
  final TextEditingController environmentController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FieldLabel(text: context.l10n.command),
        const SizedBox(height: 7),
        DesktopTextField(
          key: const Key('resource-mcp-command'),
          controller: commandController,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: context.l10n.executablePathNpxUvx,
          ),
        ),
        const SizedBox(height: 14),
        _ResponsivePair(
          left: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _FieldLabel(text: context.l10n.argumentsOnePerLine),
              const SizedBox(height: 7),
              _MultilineField(
                key: const Key('resource-mcp-args'),
                controller: argumentsController,
                hintText: '-y\n@company/mcp',
                height: 104,
                monospace: true,
              ),
            ],
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _FieldLabel(text: context.l10n.environment),
              const SizedBox(height: 7),
              _MultilineField(
                key: const Key('resource-mcp-env'),
                controller: environmentController,
                hintText: 'TOKEN=value',
                height: 104,
                monospace: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _McpHttpFields extends StatelessWidget {
  const _McpHttpFields({
    required this.urlController,
    required this.headersController,
    required this.tokenController,
  });

  final TextEditingController urlController;
  final TextEditingController headersController;
  final TextEditingController tokenController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FieldLabel(text: context.l10n.serverURL),
        const SizedBox(height: 7),
        DesktopTextField(
          key: const Key('resource-mcp-url'),
          controller: urlController,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: const InputDecoration(hintText: 'https://…/mcp'),
        ),
        const SizedBox(height: 14),
        _ResponsivePair(
          left: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _FieldLabel(text: context.l10n.headers),
              const SizedBox(height: 7),
              _MultilineField(
                key: const Key('resource-mcp-headers'),
                controller: headersController,
                hintText: 'X-Region=cn',
                height: 92,
                monospace: true,
              ),
            ],
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _FieldLabel(text: context.l10n.bearerTokenEnv),
              const SizedBox(height: 7),
              DesktopTextField(
                key: const Key('resource-mcp-token-env'),
                controller: tokenController,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(hintText: 'MCP_TOKEN'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KnowledgeContentEditor extends StatelessWidget {
  const _KnowledgeContentEditor({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context
              .l10n
              .knowledgeIsCollectedFromImportsAndAgentContextItCannotBe_08bd7ed0,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        _MultilineField(
          key: const Key('resource-content'),
          controller: controller,
          height: 220,
        ),
      ],
    );
  }
}

class _TriggerScopeField extends StatelessWidget {
  const _TriggerScopeField({
    required this.groups,
    required this.selectedIds,
    required this.onTap,
    this.nativeProject = false,
    super.key,
  });

  final List<TriggerGroup> groups;
  final Set<String> selectedIds;
  final VoidCallback onTap;
  final bool nativeProject;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<String> names = groups
        .where((TriggerGroup group) => selectedIds.contains(group.id))
        .map((TriggerGroup group) => group.name)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FieldLabel(
          text: nativeProject
              ? context.l10n.projectInstallationScope
              : context.l10n.triggerScope,
        ),
        if (nativeProject) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            context
                .l10n
                .dingdongCopiesTheCompleteSkillPackageIntoEachSelected_de26f089,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 7),
        Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(5),
          child: InkWell(
            key: const Key('resource-trigger-groups'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 42,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11),
                child: Row(
                  children: <Widget>[
                    Icon(
                      nativeProject
                          ? Icons.folder_copy_outlined
                          : Icons.filter_alt_outlined,
                      size: 16,
                      color: names.isEmpty
                          ? colors.onSurfaceVariant
                          : colors.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        names.isEmpty
                            ? nativeProject
                                  ? context.l10n.noProjectSelected
                                  : context.l10n.allProjectsNoRestriction
                            : names.join('、'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: names.isEmpty
                              ? colors.onSurfaceVariant
                              : colors.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      names.isEmpty
                          ? nativeProject
                                ? context.l10n.configureProjects
                                : context.l10n.chooseRules
                          : context.l10n.lengthSelected(names.length),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
