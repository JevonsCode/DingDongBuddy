import 'dart:async';
import 'dart:io';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_disclosure.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/features/library/domain/resource_configuration.dart';
import 'package:dingdong/features/library/domain/resource_scope_policy.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:dingdong/features/library/ui/resource_usage_summary.dart';
import 'package:dingdong/features/library/ui/trigger_group_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class SkillDeliveryAgentOption {
  const SkillDeliveryAgentOption({
    required this.id,
    required this.label,
    this.available = true,
  });

  final String id;
  final String label;
  final bool available;
}

/// Details pane with distinct authoring flows for prompts, skills, and MCP.
class ResourceEditor extends StatefulWidget {
  const ResourceEditor({
    required this.resource,
    required this.isCreating,
    required this.onCreate,
    required this.onDelete,
    required this.onSave,
    this.initialType = ResourceType.prompt,
    this.initialTitle = '',
    this.initialContent = '',
    this.triggerGroups = const <TriggerGroup>[],
    this.onCreateWithAgentSessionName,
    this.onCreateTriggerGroup,
    this.onUpdateTriggerGroup,
    this.onDeleteTriggerGroup,
    this.onSyncUpdate,
    this.onResolveSkillSource,
    this.onOpenExternalLink,
    this.onDirtyChanged,
    this.skillAgents = defaultSkillDeliveryAgents,
    super.key,
  });

  final Resource? resource;
  final bool isCreating;
  final Future<void> Function({
    required ResourceType type,
    required String title,
    required String content,
    String? group,
    List<String>? tags,
    String? updateUrl,
    String? packagePath,
    String? skillPackageDigest,
    String? note,
    bool? pinned,
    bool? enabled,
    ResourceActivation? activation,
    List<String>? triggerGroupIds,
  })
  onCreate;
  final Future<void> Function({
    required ResourceType type,
    required String title,
    required String content,
    String? group,
    List<String>? tags,
    String? updateUrl,
    String? packagePath,
    String? skillPackageDigest,
    String? note,
    String? agentSessionName,
    bool? hideInAgentConversation,
    bool? pinned,
    bool? enabled,
    ResourceActivation? activation,
    List<String>? triggerGroupIds,
  })?
  onCreateWithAgentSessionName;
  final Future<void> Function()? onDelete;
  final Future<void> Function(Resource resource) onSave;
  final ResourceType initialType;
  final String initialTitle;
  final String initialContent;
  final List<TriggerGroup> triggerGroups;
  final CreateTriggerGroup? onCreateTriggerGroup;
  final Future<void> Function(TriggerGroup group)? onUpdateTriggerGroup;
  final Future<void> Function(String id)? onDeleteTriggerGroup;
  final Future<void> Function(String updateUrl)? onSyncUpdate;
  final Future<SkillPackageInstallResult> Function(String updateUrl)?
  onResolveSkillSource;
  final Future<void> Function(Uri uri)? onOpenExternalLink;
  final ValueChanged<bool>? onDirtyChanged;
  final List<SkillDeliveryAgentOption> skillAgents;

  static const List<SkillDeliveryAgentOption> defaultSkillDeliveryAgents =
      <SkillDeliveryAgentOption>[
        SkillDeliveryAgentOption(id: 'codex', label: 'Codex'),
        SkillDeliveryAgentOption(id: 'claude-code', label: 'Claude Code'),
        SkillDeliveryAgentOption(id: 'cursor', label: 'Cursor'),
        SkillDeliveryAgentOption(id: 'gemini', label: 'Gemini CLI'),
        SkillDeliveryAgentOption(
          id: 'grok-build',
          label: 'Grok Build',
          available: false,
        ),
        SkillDeliveryAgentOption(id: 'kiro', label: 'Kiro'),
        SkillDeliveryAgentOption(id: 'pi', label: 'Pi', available: false),
      ];

  @override
  State<ResourceEditor> createState() => _ResourceEditorState();
}

class _ResourceEditorState extends State<ResourceEditor> {
  late final TextEditingController _titleController;
  late final TextEditingController _promptController;
  late final TextEditingController _skillDocumentController;
  late final TextEditingController _skillNameController;
  late final TextEditingController _skillDescriptionController;
  late final TextEditingController _updateUrlController;
  late final TextEditingController _noteController;
  late final TextEditingController _agentSessionNameController;
  late final TextEditingController _mcpCommandController;
  late final TextEditingController _mcpArgumentsController;
  late final TextEditingController _mcpEnvironmentController;
  late final TextEditingController _mcpUrlController;
  late final TextEditingController _mcpHeadersController;
  late final TextEditingController _mcpTokenController;
  late final TextEditingController _mcpRawController;
  Set<String> _selectedTriggerGroupIds = <String>{};
  Map<String, SkillDeliveryMode> _skillDeliveryByAgent =
      <String, SkillDeliveryMode>{};
  Map<String, bool> _skillHooksEnabledByAgent = <String, bool>{};
  bool _pinned = false;
  bool _enabled = true;
  bool _hideInAgentConversation = false;
  ResourceActivation _activation = ResourceActivation.taskMatch;
  ResourceType _draftType = ResourceType.prompt;
  SkillSourceMode _skillSourceMode = SkillSourceMode.local;
  McpTransport _mcpTransport = McpTransport.stdio;
  String? _saveError;
  bool _saving = false;
  bool _saved = false;
  bool _updatingSkill = false;
  bool _skillUpdated = false;
  bool _loading = false;
  bool _dirty = false;
  Resource? _locallySubmittedResource;

  List<TextEditingController> get _controllers => <TextEditingController>[
    _titleController,
    _promptController,
    _skillDocumentController,
    _skillNameController,
    _skillDescriptionController,
    _updateUrlController,
    _noteController,
    _agentSessionNameController,
    _mcpCommandController,
    _mcpArgumentsController,
    _mcpEnvironmentController,
    _mcpUrlController,
    _mcpHeadersController,
    _mcpTokenController,
    _mcpRawController,
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _promptController = TextEditingController();
    _skillDocumentController = TextEditingController();
    _skillNameController = TextEditingController();
    _skillDescriptionController = TextEditingController();
    _updateUrlController = TextEditingController();
    _noteController = TextEditingController();
    _agentSessionNameController = TextEditingController();
    _mcpCommandController = TextEditingController();
    _mcpArgumentsController = TextEditingController();
    _mcpEnvironmentController = TextEditingController();
    _mcpUrlController = TextEditingController();
    _mcpHeadersController = TextEditingController();
    _mcpTokenController = TextEditingController();
    _mcpRawController = TextEditingController();
    for (final TextEditingController controller in _controllers) {
      controller.addListener(_markDirty);
    }
    _load(widget.resource);
  }

  @override
  void didUpdateWidget(covariant ResourceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool acknowledgesLocalSave =
        widget.resource != null && widget.resource == _locallySubmittedResource;
    if (acknowledgesLocalSave) {
      _locallySubmittedResource = null;
      return;
    }
    if (oldWidget.resource != widget.resource ||
        oldWidget.isCreating != widget.isCreating ||
        oldWidget.initialType != widget.initialType ||
        oldWidget.initialTitle != widget.initialTitle ||
        oldWidget.initialContent != widget.initialContent) {
      _load(widget.resource);
    }
  }

  @override
  void dispose() {
    if (_dirty) {
      widget.onDirtyChanged?.call(false);
    }
    for (final TextEditingController controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _load(Resource? resource) {
    _loading = true;
    final bool creating = resource == null && widget.isCreating;
    _titleController.text =
        resource?.title ?? (creating ? widget.initialTitle : '');
    _promptController.clear();
    _skillDocumentController.clear();
    _skillNameController.clear();
    _skillDescriptionController.clear();
    _updateUrlController.text = resource?.updateUrl ?? '';
    _noteController.text = resource?.note ?? '';
    _agentSessionNameController.text = resource?.agentSessionName ?? '';
    _mcpCommandController.clear();
    _mcpArgumentsController.clear();
    _mcpEnvironmentController.clear();
    _mcpUrlController.clear();
    _mcpHeadersController.clear();
    _mcpTokenController.clear();
    _mcpRawController.clear();
    _selectedTriggerGroupIds = <String>{...?resource?.triggerGroupIds};
    _skillDeliveryByAgent = <String, SkillDeliveryMode>{
      ...?resource?.skillDeliveryByAgent,
    };
    _skillHooksEnabledByAgent = <String, bool>{
      ...?resource?.skillHooksEnabledByAgent,
    };
    _pinned = resource?.pinned ?? false;
    _enabled = resource?.enabled ?? true;
    _hideInAgentConversation = resource?.hideInAgentConversation ?? false;
    _activation = resource?.activation ?? ResourceActivation.taskMatch;
    _draftType = resource?.type ?? widget.initialType;
    _skillSourceMode = resource?.updateUrl == null
        ? SkillSourceMode.local
        : SkillSourceMode.online;
    _mcpTransport = McpTransport.stdio;
    _saveError = null;
    _saving = false;
    _saved = false;
    _updatingSkill = false;
    _skillUpdated = false;
    switch (_draftType) {
      case ResourceType.prompt:
        _promptController.text =
            resource?.content ?? (creating ? widget.initialContent : '');
      case ResourceType.skill:
        _skillDocumentController.text =
            resource?.content ??
            SkillConfiguration.template(
              resource?.title ?? 'untitled-skill',
            ).encode();
        final SkillConfiguration skill = SkillConfiguration.parse(
          _skillDocumentController.text,
          fallbackName: resource?.title ?? 'untitled-skill',
        );
        _skillNameController.text = skill.name;
        _skillDescriptionController.text = skill.description;
      case ResourceType.mcp:
        _loadMcp(McpConfiguration.parse(resource?.content ?? ''));
      case ResourceType.knowledge:
      case ResourceType.clipboard:
        _promptController.text =
            resource?.content ?? (creating ? widget.initialContent : '');
    }
    _loading = false;
    _setDirty(false);
  }

  void _markDirty() {
    if (_loading || !mounted) {
      return;
    }
    _setDirty(true);
    if (_saved) {
      setState(() => _saved = false);
    }
  }

  void _setDirty(bool value) {
    if (_dirty == value) {
      return;
    }
    _dirty = value;
    widget.onDirtyChanged?.call(value);
  }

  void _loadMcp(McpConfiguration configuration) {
    _mcpTransport = configuration.transport;
    _mcpCommandController.text = configuration.command;
    _mcpArgumentsController.text = configuration.arguments.join('\n');
    _mcpEnvironmentController.text = formatConfigurationPairs(
      configuration.environment,
    );
    _mcpUrlController.text = configuration.url;
    _mcpHeadersController.text = formatConfigurationPairs(
      configuration.headers,
    );
    _mcpTokenController.text = configuration.tokenEnvironmentVariable;
    _mcpRawController.text = configuration.raw;
  }

  @override
  Widget build(BuildContext context) {
    final Resource? resource = widget.resource;
    final bool hasProjectNative = _skillDeliveryByAgent.values.any(
      (SkillDeliveryMode mode) => mode == SkillDeliveryMode.nativeProject,
    );
    if (resource == null && !widget.isCreating) {
      return _EmptyEditor();
    }
    return Padding(
      key: const Key('resource-editor'),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ResourceEditorHeading(resource: resource, type: _draftType),
          const SizedBox(height: 17),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (resource == null) ...<Widget>[
                    _ResourceTypePicker(
                      selected: _draftType,
                      onSelected: _selectType,
                    ),
                    const SizedBox(height: 20),
                  ] else ...<Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _TypeBadge(type: _draftType),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (!(_draftType == ResourceType.skill &&
                      resource != null &&
                      _skillSourceMode == SkillSourceMode.online)) ...<Widget>[
                    _FieldLabel(text: _titleLabel(context, _draftType)),
                    const SizedBox(height: 7),
                    DesktopTextField(
                      key: const Key('resource-title'),
                      controller: _titleController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: _titleHint(context, _draftType),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  _buildPrimaryEditor(context),
                  if (_draftType == ResourceType.skill &&
                      resource != null) ...<Widget>[
                    const SizedBox(height: 18),
                    _SkillDeliveryEditor(
                      agents: _resolvedSkillAgents(),
                      deliveryByAgent: _skillDeliveryByAgent,
                      hooksEnabledByAgent: _skillHooksEnabledByAgent,
                      impeccable: _skillNameController.text == 'impeccable',
                      onDeliveryChanged:
                          (String agentId, SkillDeliveryMode mode) {
                            _setDirty(true);
                            setState(() {
                              _skillDeliveryByAgent[agentId] = mode;
                              if (mode != SkillDeliveryMode.nativeProject) {
                                _skillHooksEnabledByAgent.remove(agentId);
                              }
                              _saved = false;
                            });
                          },
                      onHookChanged: (String agentId, bool enabled) {
                        _setDirty(true);
                        setState(() {
                          if (enabled) {
                            _skillHooksEnabledByAgent[agentId] = true;
                          } else {
                            _skillHooksEnabledByAgent.remove(agentId);
                          }
                          _saved = false;
                        });
                      },
                    ),
                    if (hasProjectNative) ...<Widget>[
                      const SizedBox(height: 14),
                      _TriggerScopeField(
                        key: const Key('skill-native-project-scope'),
                        groups: widget.triggerGroups,
                        selectedIds: _selectedTriggerGroupIds,
                        onTap: () =>
                            _selectTriggerGroups(exactProjectOnly: true),
                        nativeProject: true,
                      ),
                    ],
                  ],
                  if (_draftType.isConfigurableAgentResource) ...<Widget>[
                    const SizedBox(height: 18),
                    _AgentSessionNameField(
                      controller: _agentSessionNameController,
                      hideInAgentConversation: _hideInAgentConversation,
                      onHideInAgentConversationChanged: (bool value) {
                        _setDirty(true);
                        setState(() {
                          _hideInAgentConversation = value;
                          _saved = false;
                        });
                      },
                    ),
                  ],
                  if (!(_draftType == ResourceType.skill &&
                      hasProjectNative)) ...<Widget>[
                    const SizedBox(height: 18),
                    _TriggerScopeField(
                      groups: widget.triggerGroups,
                      selectedIds: _selectedTriggerGroupIds,
                      onTap: _selectTriggerGroups,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ResourceOptions(
                    updateUrlController: _updateUrlController,
                    pinned: _pinned,
                    enabled: _enabled,
                    showSync:
                        resource != null &&
                        widget.onSyncUpdate != null &&
                        _draftType != ResourceType.skill,
                    showUpdateLink: _draftType != ResourceType.skill,
                    onPinnedChanged: (bool value) => setState(() {
                      _setDirty(true);
                      _pinned = value;
                      _saved = false;
                    }),
                    onEnabledChanged: (bool value) => setState(() {
                      _setDirty(true);
                      _enabled = value;
                      _saved = false;
                    }),
                    onSync: () =>
                        widget.onSyncUpdate?.call(_updateUrlController.text),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_saveError != null) ...<Widget>[
            Container(
              key: const Key('resource-save-error'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _saveError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          _EditorActions(
            existing: resource != null,
            onDelete: widget.onDelete,
            onReset: _reset,
            onSave: _save,
            saving: _saving,
            saved: _saved,
            syncing:
                _draftType == ResourceType.skill &&
                _skillSourceMode == SkillSourceMode.online &&
                resource == null,
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryEditor(BuildContext context) {
    switch (_draftType) {
      case ResourceType.prompt:
        return _PromptEditor(
          controller: _promptController,
          activation: _activation,
          onActivationChanged: (ResourceActivation value) => setState(() {
            _setDirty(true);
            _activation = value;
            _saved = false;
          }),
        );
      case ResourceType.skill:
        return _SkillEditor(
          name: normalizeSkillName(_titleController.text),
          sourceMode: _skillSourceMode,
          onSourceModeChanged: (SkillSourceMode value) => setState(() {
            _setDirty(true);
            _skillSourceMode = value;
            _saved = false;
            _skillUpdated = false;
          }),
          updateUrlController: _updateUrlController,
          documentController: _skillDocumentController,
          parsedNameController: _skillNameController,
          parsedDescriptionController: _skillDescriptionController,
          noteController: _noteController,
          installedOnline:
              widget.resource != null &&
              _skillSourceMode == SkillSourceMode.online,
          updating: _updatingSkill,
          updated: _skillUpdated,
          onOpenSource: _openSkillSource,
          onUpdate: _updateOnlineSkill,
        );
      case ResourceType.mcp:
        return _McpEditor(
          transport: _mcpTransport,
          onTransportChanged: (McpTransport value) => setState(() {
            _setDirty(true);
            _mcpTransport = value;
            _saved = false;
          }),
          commandController: _mcpCommandController,
          argumentsController: _mcpArgumentsController,
          environmentController: _mcpEnvironmentController,
          urlController: _mcpUrlController,
          headersController: _mcpHeadersController,
          tokenController: _mcpTokenController,
          rawController: _mcpRawController,
        );
      case ResourceType.knowledge:
      case ResourceType.clipboard:
        return _KnowledgeContentEditor(controller: _promptController);
    }
  }

  void _selectType(ResourceType type) {
    if (_draftType == type) {
      return;
    }
    _setDirty(true);
    setState(() {
      _draftType = type;
      _activation = ResourceActivation.taskMatch;
      _skillSourceMode = SkillSourceMode.local;
      _saved = false;
      if (type == ResourceType.skill &&
          _skillDocumentController.text.trim().isEmpty) {
        _skillDocumentController.text = SkillConfiguration.template(
          _titleController.text,
        ).encode();
      }
    });
  }

  void _reset() {
    setState(() {
      if (widget.resource != null) {
        _load(widget.resource);
        return;
      }
      _titleController.clear();
      _promptController.clear();
      _skillDocumentController.text = SkillConfiguration.template(
        'untitled-skill',
      ).encode();
      _updateUrlController.clear();
      _noteController.clear();
      _agentSessionNameController.clear();
      _selectedTriggerGroupIds.clear();
      _pinned = false;
      _enabled = true;
      _hideInAgentConversation = false;
      _activation = ResourceActivation.taskMatch;
      _skillSourceMode = SkillSourceMode.local;
      _saveError = null;
      _saved = false;
      _updatingSkill = false;
      _skillUpdated = false;
      _loadMcp(
        McpConfiguration(
          transport: _mcpTransport == McpTransport.raw
              ? McpTransport.raw
              : _mcpTransport,
        ),
      );
    });
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final Resource? resource = widget.resource;
    setState(() {
      _saving = true;
      _saved = false;
      _saveError = null;
    });
    try {
      final bool onlineSkill =
          _draftType == ResourceType.skill &&
          _skillSourceMode == SkillSourceMode.online;
      final bool installingOnlineSkill = onlineSkill && resource == null;
      SkillConfiguration? onlineConfiguration;
      String? packagePath = resource?.packagePath;
      String? skillPackageDigest = resource?.skillPackageDigest;
      if (_draftType == ResourceType.skill && !onlineSkill) {
        packagePath = '';
      }
      String content = onlineSkill
          ? resource?.content ?? ''
          : _serializedContent();
      final String updateUrl = onlineSkill
          ? _updateUrlController.text.trim()
          : (_draftType == ResourceType.skill
                ? ''
                : _updateUrlController.text.trim());
      if (installingOnlineSkill) {
        final Future<SkillPackageInstallResult> Function(String updateUrl)?
        resolve = widget.onResolveSkillSource;
        if (resolve == null || updateUrl.isEmpty) {
          throw const FormatException('Enter a Skill folder or SKILL.md URL.');
        }
        final SkillPackageInstallResult installed = await resolve(updateUrl);
        content = installed.skillDocument;
        packagePath = installed.directoryPath;
        skillPackageDigest = installed.packageDigest.isEmpty
            ? null
            : installed.packageDigest;
        onlineConfiguration = _validateOnlineSkill(content);
      }
      final String title = onlineConfiguration?.name ?? _titleController.text;
      final String resolvedSkillName = _draftType == ResourceType.skill
          ? SkillConfiguration.parse(content, fallbackName: title).name
          : '';
      final bool hasNativeDelivery = _skillDeliveryByAgent.values.any(
        (SkillDeliveryMode mode) => mode != SkillDeliveryMode.dynamic,
      );
      final bool hasProjectNative = _skillDeliveryByAgent.values.any(
        (SkillDeliveryMode mode) => mode == SkillDeliveryMode.nativeProject,
      );
      final bool hasUserNative = _skillDeliveryByAgent.values.any(
        (SkillDeliveryMode mode) => mode == SkillDeliveryMode.nativeUser,
      );
      if (hasUserNative && hasProjectNative) {
        throw const FormatException(
          'One Skill cannot mix user-native and project-native delivery across Agents.',
        );
      }
      if (hasUserNative && _selectedTriggerGroupIds.isNotEmpty) {
        throw const FormatException(
          'User-native delivery is global; clear the project trigger scope first.',
        );
      }
      List<String> skillProjectPaths =
          resource?.skillProjectPaths ?? const <String>[];
      if (_draftType == ResourceType.skill && hasNativeDelivery) {
        final String packageRoot = (packagePath ?? '').trim();
        if (packageRoot.isEmpty ||
            !File(
              '$packageRoot${Platform.pathSeparator}SKILL.md',
            ).existsSync()) {
          throw const FormatException(
            'Native delivery requires a complete installed Skill package.',
          );
        }
      }
      if (_draftType == ResourceType.skill && hasProjectNative) {
        if (_selectedTriggerGroupIds.isNotEmpty) {
          skillProjectPaths = resolveStrictSkillProjectPaths(
            _selectedTriggerGroupIds.toList(growable: false),
            <String, TriggerGroup>{
              for (final TriggerGroup group in widget.triggerGroups)
                group.id: group,
            },
          );
        } else if (resource?.triggerGroupIds.isNotEmpty ?? false) {
          // Clearing the final UI-managed exact scope must not silently retain
          // an old native deployment path or its Hook.
          skillProjectPaths = const <String>[];
        }
        if (skillProjectPaths.isEmpty) {
          throw const FormatException(
            'Project-native delivery requires an exact project trigger scope.',
          );
        }
      } else if (!hasProjectNative) {
        skillProjectPaths = const <String>[];
      }
      for (final MapEntry<String, bool> hook
          in _skillHooksEnabledByAgent.entries) {
        if (!hook.value) {
          continue;
        }
        if (resolvedSkillName != 'impeccable' ||
            hook.key != 'codex' ||
            _skillDeliveryByAgent[hook.key] !=
                SkillDeliveryMode.nativeProject) {
          throw const FormatException(
            'Managed Hooks require Impeccable with Codex project-native delivery.',
          );
        }
      }
      if (resource == null) {
        final Future<void> Function({
          required ResourceType type,
          required String title,
          required String content,
          String? group,
          List<String>? tags,
          String? updateUrl,
          String? packagePath,
          String? skillPackageDigest,
          String? note,
          String? agentSessionName,
          bool? hideInAgentConversation,
          bool? pinned,
          bool? enabled,
          ResourceActivation? activation,
          List<String>? triggerGroupIds,
        })?
        createWithAgentSessionName = widget.onCreateWithAgentSessionName;
        if (createWithAgentSessionName != null) {
          await createWithAgentSessionName(
            type: _draftType,
            title: title,
            content: content,
            updateUrl: updateUrl,
            packagePath: packagePath,
            skillPackageDigest: skillPackageDigest,
            note: onlineSkill ? _noteController.text : null,
            agentSessionName: _agentSessionNameController.text,
            hideInAgentConversation: _hideInAgentConversation,
            pinned: _pinned,
            enabled: _enabled,
            activation: _activation,
            triggerGroupIds: _selectedTriggerGroupIds.toList(growable: false),
          );
        } else {
          await widget.onCreate(
            type: _draftType,
            title: title,
            content: content,
            updateUrl: updateUrl,
            packagePath: packagePath,
            skillPackageDigest: skillPackageDigest,
            note: onlineSkill ? _noteController.text : null,
            pinned: _pinned,
            enabled: _enabled,
            activation: _activation,
            triggerGroupIds: _selectedTriggerGroupIds.toList(growable: false),
          );
        }
      } else {
        final Resource updated = resource.copyWith(
          title: title,
          content: content,
          updateUrl: updateUrl,
          packagePath: packagePath,
          skillPackageDigest: skillPackageDigest,
          note: onlineSkill ? _noteController.text : resource.note,
          agentSessionName: _agentSessionNameController.text,
          hideInAgentConversation: _hideInAgentConversation,
          pinned: _pinned,
          enabled: _enabled,
          activation: _activation,
          triggerGroupIds: _selectedTriggerGroupIds.toList(growable: false),
          strictProjectSkill: hasProjectNative,
          skillProjectPaths: skillProjectPaths,
          skillDeliveryByAgent: _skillDeliveryByAgent,
          skillHooksEnabledByAgent: _skillHooksEnabledByAgent,
          updatedAt: DateTime.now().toUtc(),
        );
        _locallySubmittedResource = updated;
        await widget.onSave(updated);
      }
      if (mounted) {
        _setDirty(false);
        setState(() => _saved = true);
        _showSnackBarIfAvailable(
          context.localized('Configuration saved', '配置已保存'),
          const Duration(milliseconds: 1300),
        );
      }
    } on Object catch (error) {
      _locallySubmittedResource = null;
      if (mounted) {
        setState(() => _saveError = _friendlySaveError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  List<SkillDeliveryAgentOption> _resolvedSkillAgents() {
    final Map<String, SkillDeliveryAgentOption> agents =
        <String, SkillDeliveryAgentOption>{
          for (final SkillDeliveryAgentOption agent in widget.skillAgents)
            agent.id: agent,
        };
    for (final String id in <String>{
      ..._skillDeliveryByAgent.keys,
      ..._skillHooksEnabledByAgent.keys,
    }) {
      agents.putIfAbsent(
        id,
        () => SkillDeliveryAgentOption(id: id, label: id, available: false),
      );
    }
    final List<SkillDeliveryAgentOption> result = agents.values.toList()
      ..sort(
        (SkillDeliveryAgentOption left, SkillDeliveryAgentOption right) =>
            left.label.toLowerCase().compareTo(right.label.toLowerCase()),
      );
    return result;
  }

  Future<void> _openSkillSource() async {
    final String value = _updateUrlController.text.trim();
    final Uri? uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        widget.onOpenExternalLink == null) {
      setState(() {
        _saveError = context.localized(
          'Enter a valid web source before opening it.',
          '请先填写有效的网页来源链接。',
        );
      });
      return;
    }
    try {
      await widget.onOpenExternalLink!(uri);
    } on Object {
      if (mounted) {
        setState(() {
          _saveError = context.localized(
            'Could not open this Skill source.',
            '无法打开这个 Skill 来源。',
          );
        });
      }
    }
  }

  Future<void> _updateOnlineSkill() async {
    final Resource? resource = widget.resource;
    final Future<SkillPackageInstallResult> Function(String updateUrl)?
    resolve = widget.onResolveSkillSource;
    final String updateUrl = _updateUrlController.text.trim();
    if (resource == null || resolve == null || updateUrl.isEmpty) {
      setState(() {
        _saveError = context.localized(
          'This online Skill does not have an available source.',
          '这个在线 Skill 没有可用的来源链接。',
        );
      });
      return;
    }
    setState(() {
      _updatingSkill = true;
      _skillUpdated = false;
      _saveError = null;
    });
    try {
      final SkillPackageInstallResult installed = await resolve(updateUrl);
      final String content = installed.skillDocument;
      final SkillConfiguration skill = _validateOnlineSkill(content);
      final Resource updated = resource.copyWith(
        title: skill.name,
        content: content,
        updateUrl: updateUrl,
        packagePath: installed.directoryPath,
        skillPackageDigest: installed.packageDigest.isEmpty
            ? resource.skillPackageDigest
            : installed.packageDigest,
        updatedAt: DateTime.now().toUtc(),
      );
      _locallySubmittedResource = updated;
      await widget.onSave(updated);
      _loading = true;
      _skillDocumentController.text = content;
      _titleController.text = skill.name;
      _skillNameController.text = skill.name;
      _skillDescriptionController.text = skill.description;
      _loading = false;
      if (mounted) {
        setState(() => _skillUpdated = true);
        _showSnackBarIfAvailable(
          context.localized('Online Skill updated', '在线 Skill 已更新'),
          const Duration(milliseconds: 1400),
        );
      }
    } on Object catch (error) {
      _locallySubmittedResource = null;
      if (mounted) {
        setState(() => _saveError = _friendlySaveError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _updatingSkill = false);
      }
    }
  }

  SkillConfiguration _validateOnlineSkill(String document) =>
      SkillConfiguration.parseOnline(document);

  void _showSnackBarIfAvailable(String message, Duration duration) {
    if (Scaffold.maybeOf(context) == null) {
      return;
    }
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(duration: duration, content: Text(message)));
  }

  String _friendlySaveError(Object error) {
    if (error is StateError) {
      final String detail = error.message.toString();
      if (!detail.contains('unavailable')) {
        return context.localized(
          'Could not sync this resource to an installed Agent. $detail',
          '无法把这个资源同步到已安装的 Agent。$detail',
        );
      }
      return context.localized(
        'Online sync is not ready in this window. Reopen Resource Manager and try again.',
        '当前窗口尚未启用在线同步，请重新打开资源管理后重试。',
      );
    }
    if (error is TimeoutException || error is SocketException) {
      return context.localized(
        'Could not reach the source. Check your network and link, then try again.',
        '无法连接来源链接，请检查网络和链接后重试。',
      );
    }
    if (error is HttpException) {
      return context.localized(
        'The source did not return a usable SKILL.md. Check the repository path and access.',
        '来源链接没有返回可用的 SKILL.md，请确认仓库路径和访问权限。',
      );
    }
    if (error is FormatException) {
      if (_draftType == ResourceType.skill) {
        final String detail = error.message.toString();
        if (detail.contains('delivery') ||
            detail.contains('native') ||
            detail.contains('Hook') ||
            detail.contains('project trigger scope')) {
          return context.localized(
            'Could not apply this Skill delivery policy. $detail',
            '无法应用此 Skill 交付策略。$detail',
          );
        }
        if (_skillSourceMode == SkillSourceMode.local) {
          return context.localized(
            'SKILL.md needs valid name and description fields in its YAML frontmatter.',
            'SKILL.md 的 YAML frontmatter 需要有效的 name 和 description。',
          );
        }
        return context.localized(
          'Paste a GitHub Skill repository, folder, or direct SKILL.md link.\n'
              'Examples:\n'
              'https://github.com/JevonsCode/codex-skills/tree/main/skills/user-taste\n'
              'https://github.com/mattpocock/skills/tree/main/skills/productivity/grilling',
          '请粘贴 GitHub Skill 仓库、文件夹或 SKILL.md 直链。\n'
              '正确示例：\n'
              'https://github.com/JevonsCode/codex-skills/tree/main/skills/user-taste\n'
              'https://github.com/mattpocock/skills/tree/main/skills/productivity/grilling',
        );
      }
      if (_draftType == ResourceType.mcp) {
        return context.localized(
          'Use a valid STDIO or Streamable HTTP MCP configuration.',
          '请填写有效的 STDIO 或 Streamable HTTP MCP 配置。',
        );
      }
    }
    return context.localized(
      'Could not save this configuration. Check the content and try again.',
      '保存失败，请检查内容后重试。',
    );
  }

  String _serializedContent() {
    switch (_draftType) {
      case ResourceType.prompt:
      case ResourceType.knowledge:
      case ResourceType.clipboard:
        return _promptController.text;
      case ResourceType.skill:
        final SkillConfiguration skill = SkillConfiguration.parse(
          _skillDocumentController.text,
          fallbackName: _titleController.text,
        );
        if (skill.description.trim().isEmpty) {
          throw const FormatException('Skill description must not be empty.');
        }
        return skill
            .copyWith(name: normalizeSkillName(_titleController.text))
            .encode();
      case ResourceType.mcp:
        return McpConfiguration(
          transport: _mcpTransport,
          command: _mcpCommandController.text,
          arguments: _mcpArgumentsController.text
              .replaceAll('\r\n', '\n')
              .split('\n')
              .map((String value) => value.trim())
              .where((String value) => value.isNotEmpty)
              .toList(growable: false),
          environment: parseConfigurationPairs(_mcpEnvironmentController.text),
          url: _mcpUrlController.text,
          headers: parseConfigurationPairs(_mcpHeadersController.text),
          tokenEnvironmentVariable: _mcpTokenController.text,
          raw: _mcpRawController.text,
        ).encode();
    }
  }

  Future<void> _selectTriggerGroups({bool exactProjectOnly = false}) async {
    final CreateTriggerGroup? create = widget.onCreateTriggerGroup;
    final Future<void> Function(TriggerGroup group)? update =
        widget.onUpdateTriggerGroup;
    final Future<void> Function(String id)? delete =
        widget.onDeleteTriggerGroup;
    if (create == null || update == null || delete == null) {
      return;
    }
    final Set<String>? selected = await showDialog<Set<String>>(
      context: context,
      builder: (BuildContext context) => TriggerGroupPickerDialog(
        groups: widget.triggerGroups,
        selectedIds: _selectedTriggerGroupIds,
        onCreate: create,
        onUpdate: update,
        onDelete: delete,
        exactProjectOnly: exactProjectOnly,
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    if (setEquals(selected, _selectedTriggerGroupIds)) {
      return;
    }
    _setDirty(true);
    setState(() {
      _selectedTriggerGroupIds = selected;
      _saved = false;
    });
  }
}

class _ResourceEditorHeading extends StatelessWidget {
  const _ResourceEditorHeading({required this.resource, required this.type});

  final Resource? resource;
  final ResourceType type;

  @override
  Widget build(BuildContext context) {
    final Widget heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          resource == null
              ? context.localized('Add agent configuration', '添加 Agent 配置')
              : context.localized('Configuration details', '配置详情'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Text(
          _typeDescription(context, type),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final Resource? current = resource;
    if (current == null) {
      return heading;
    }
    final Widget usage = ResourceUsageSummary(
      key: const Key('resource-detail-usage-summary'),
      resource: current,
      style: ResourceUsageSummaryStyle.detail,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[heading, const SizedBox(height: 12), usage],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: heading),
            const SizedBox(width: 20),
            usage,
          ],
        );
      },
    );
  }
}

class _EmptyEditor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.tune_rounded,
            size: 24,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            context.localized(
              'Select a configuration to inspect or edit',
              '选择一项配置以查看或编辑',
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceTypePicker extends StatelessWidget {
  const _ResourceTypePicker({required this.selected, required this.onSelected});

  final ResourceType selected;
  final ValueChanged<ResourceType> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('resource-type'),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          for (final ResourceType type in const <ResourceType>[
            ResourceType.prompt,
            ResourceType.skill,
            ResourceType.mcp,
          ])
            Expanded(
              child: _TypeOption(
                key: Key('resource-type-${type.name}'),
                type: type,
                selected: type == selected,
                onTap: () => onSelected(type),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.type,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final ResourceType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? colors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                _typeIcon(type),
                size: 16,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Text(
                _typeLabel(context, type),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? colors.onSurface : colors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final ResourceType type;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Brightness brightness = Theme.of(context).brightness;
    final bool isMcp = type == ResourceType.mcp;
    return Container(
      key: const Key('resource-type-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isMcp
            ? PopupStyle.mcpSurface(brightness)
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            _typeIcon(type),
            size: 14,
            color: isMcp
                ? PopupStyle.mcpAccent(brightness)
                : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            _typeLabel(context, type),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isMcp
                  ? PopupStyle.mcpAccent(brightness)
                  : colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentSessionNameField extends StatelessWidget {
  const _AgentSessionNameField({
    required this.controller,
    required this.hideInAgentConversation,
    required this.onHideInAgentConversationChanged,
  });

  final TextEditingController controller;
  final bool hideInAgentConversation;
  final ValueChanged<bool> onHideInAgentConversationChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _FieldLabel(
                text: context.localized(
                  'Agent session loading name',
                  'Agent 会话加载名称',
                ),
              ),
            ),
            Tooltip(
              message: context.localized(
                'Load this resource without showing its name in the Agent conversation.',
                '加载这个资源，但不在 Agent 对话中展示它的名称。',
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    context.localized('Hide in conversation', '会话中隐藏'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CompactSwitch(
                    key: const Key('resource-hide-in-agent-conversation'),
                    value: hideInAgentConversation,
                    onChanged: onHideInAgentConversationChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        DesktopTextField(
          key: const Key('resource-agent-session-name'),
          controller: controller,
          maxLength: maximumAgentSessionNameCharacters,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          inputFormatters: <TextInputFormatter>[
            LengthLimitingTextInputFormatter(maximumAgentSessionNameCharacters),
          ],
          decoration: InputDecoration(
            hintText: context.localized(
              'Leave empty to use the resource title.',
              '留空时使用资源标题。',
            ),
            counterText: '',
          ),
        ),
        const SizedBox(height: 5),
        Text(
          context.localized(
            'Up to 7 characters. This name is shown first in the Agent conversation; an empty value falls back to the title.',
            '最多 7 个字。Agent 会话中优先展示这个名称；留空时回退到资源标题。',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PromptEditor extends StatelessWidget {
  const _PromptEditor({
    required this.controller,
    required this.activation,
    required this.onActivationChanged,
  });

  final TextEditingController controller;
  final ResourceActivation activation;
  final ValueChanged<ResourceActivation> onActivationChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FieldLabel(text: context.localized('When it applies', '生效方式')),
        const SizedBox(height: 7),
        _FlatChoiceRow<ResourceActivation>(
          selected: activation,
          choices: <_Choice<ResourceActivation>>[
            _Choice<ResourceActivation>(
              value: ResourceActivation.always,
              keyName: 'resource-activation-always',
              label: context.localized('Always', '始终'),
            ),
            _Choice<ResourceActivation>(
              value: ResourceActivation.taskMatch,
              keyName: 'resource-activation-task-match',
              label: context.localized('Agent decides', 'Agent 判断'),
            ),
            _Choice<ResourceActivation>(
              value: ResourceActivation.manual,
              keyName: 'resource-activation-manual',
              label: context.localized('Manual', '手动'),
            ),
          ],
          onSelected: onActivationChanged,
        ),
        const SizedBox(height: 16),
        _FieldLabel(text: context.localized('Instructions', '提示词内容')),
        const SizedBox(height: 7),
        _MultilineField(
          key: const Key('resource-content'),
          controller: controller,
          hintText: context.localized(
            'Describe the behavior the Agent should follow.',
            '直接写清楚 Agent 应遵循的行为。',
          ),
          height: 220,
        ),
      ],
    );
  }
}

enum SkillSourceMode { local, online }

class _SkillEditor extends StatelessWidget {
  const _SkillEditor({
    required this.name,
    required this.sourceMode,
    required this.onSourceModeChanged,
    required this.updateUrlController,
    required this.documentController,
    required this.parsedNameController,
    required this.parsedDescriptionController,
    required this.noteController,
    required this.installedOnline,
    required this.updating,
    required this.updated,
    required this.onOpenSource,
    required this.onUpdate,
  });

  final String name;
  final SkillSourceMode sourceMode;
  final ValueChanged<SkillSourceMode> onSourceModeChanged;
  final TextEditingController updateUrlController;
  final TextEditingController documentController;
  final TextEditingController parsedNameController;
  final TextEditingController parsedDescriptionController;
  final TextEditingController noteController;
  final bool installedOnline;
  final bool updating;
  final bool updated;
  final VoidCallback onOpenSource;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FieldLabel(text: context.localized('Skill source', 'Skill 来源')),
        const SizedBox(height: 7),
        if (installedOnline)
          Container(
            key: const Key('resource-skill-installed-online'),
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.cloud_done_outlined,
                  size: 16,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.localized(
                    'Installed from an online source',
                    '已从在线来源安装',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          _FlatChoiceRow<SkillSourceMode>(
            selected: sourceMode,
            choices: <_Choice<SkillSourceMode>>[
              _Choice<SkillSourceMode>(
                value: SkillSourceMode.local,
                keyName: 'resource-skill-source-local',
                label: context.localized('Local authoring', '本地编写'),
              ),
              _Choice<SkillSourceMode>(
                value: SkillSourceMode.online,
                keyName: 'resource-skill-source-online',
                label: context.localized('Online sync', '在线同步'),
              ),
            ],
            onSelected: onSourceModeChanged,
          ),
        const SizedBox(height: 16),
        if (sourceMode == SkillSourceMode.online) ...<Widget>[
          if (installedOnline) ...<Widget>[
            _FieldLabel(text: context.localized('Skill name', 'Skill 名称')),
            const SizedBox(height: 7),
            DesktopTextField(
              key: const Key('resource-skill-name'),
              controller: parsedNameController,
              readOnly: true,
            ),
            const SizedBox(height: 14),
            _FieldLabel(text: context.localized('When to use', '什么时候使用')),
            const SizedBox(height: 7),
            DesktopTextField(
              key: const Key('resource-skill-description'),
              controller: parsedDescriptionController,
              readOnly: true,
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 14),
            _FieldLabel(text: context.localized('My note', '我的备注')),
            const SizedBox(height: 7),
            DesktopTextField(
              key: const Key('resource-skill-note'),
              controller: noteController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: context.localized(
                  'Add a local note about how you use this Skill.',
                  '记录你会在什么场景使用这个 Skill。',
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 17,
                  color: Color(0xFFB26A19),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.localized(
                      installedOnline
                          ? 'The installed package is read-only. Review the source before updating.'
                          : 'Review the Skill before installing. DingDong saves the full folder, including scripts and references; updates stay manual.',
                      installedOnline
                          ? '已安装的 Skill 包为只读。更新前请先查看来源。'
                          : '安装前先确认内容。DingDong 会保存包括脚本和参考资料在内的完整目录，更新由你手动触发。',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _FieldLabel(text: context.localized('Source URL', '来源链接')),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              Expanded(
                child: DesktopTextField(
                  key: const Key('resource-skill-update-url'),
                  controller: updateUrlController,
                  readOnly: installedOnline,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    hintText:
                        'https://github.com/owner/repo/tree/main/skills/name',
                  ),
                ),
              ),
              const SizedBox(width: 7),
              DesktopIconButton(
                key: const Key('resource-skill-open-source'),
                tooltip: context.localized('Open source', '打开来源'),
                onPressed: onOpenSource,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
              ),
              if (installedOnline) ...<Widget>[
                const SizedBox(width: 6),
                DesktopActionButton(
                  key: const Key('resource-skill-update'),
                  onPressed: updating ? null : onUpdate,
                  icon: updating
                      ? const SizedBox.square(
                          dimension: 13,
                          child: CircularProgressIndicator(strokeWidth: 1.7),
                        )
                      : Icon(
                          updated ? Icons.check_rounded : Icons.sync_rounded,
                          size: 16,
                        ),
                  label: Text(
                    updating
                        ? context.localized('Updating…', '更新中…')
                        : updated
                        ? context.localized('Updated', '已更新')
                        : context.localized('Check update', '检查更新'),
                  ),
                ),
              ],
            ],
          ),
          if (installedOnline) ...<Widget>[
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _FieldLabel(
                    text: context.localized(
                      'Installed Skill package · SKILL.md',
                      '已安装的 Skill 包 · SKILL.md',
                    ),
                  ),
                ),
                Text(
                  context.localized('Read-only', '只读'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            _MultilineField(
              key: const Key('resource-content'),
              controller: documentController,
              height: 300,
              monospace: true,
              readOnly: true,
            ),
          ],
        ] else ...<Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.folder_outlined, size: 16, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.localized(
                      'Saved as SKILL.md · name: $name',
                      '保存为 SKILL.md · name: $name',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _FieldLabel(
                  text: context.localized('SKILL.md content', 'SKILL.md 内容'),
                ),
              ),
              Text(
                context.localized(
                  'Cursor-compatible format',
                  '兼容 Cursor 的单文件格式',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _MultilineField(
            key: const Key('resource-content'),
            controller: documentController,
            hintText: context.localized(
              '---\nname: my-skill\ndescription: Use when…\n---\n\n# Instructions',
              '---\nname: my-skill\ndescription: 什么时候使用…\n---\n\n# 执行说明',
            ),
            height: 340,
            monospace: true,
          ),
        ],
      ],
    );
  }
}

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
        _FieldLabel(text: context.localized('Connection type', '连接方式')),
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
              label: context.localized('Paste config', '粘贴配置'),
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
              _FieldLabel(
                text: context.localized(
                  'JSON, TOML, or YAML configuration',
                  'JSON、TOML 或 YAML 配置',
                ),
              ),
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
        _FieldLabel(text: context.localized('Command', '启动命令')),
        const SizedBox(height: 7),
        DesktopTextField(
          key: const Key('resource-mcp-command'),
          controller: commandController,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: context.localized(
              'Executable path, npx, uvx…',
              '可执行文件路径、npx、uvx…',
            ),
          ),
        ),
        const SizedBox(height: 14),
        _ResponsivePair(
          left: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _FieldLabel(
                text: context.localized(
                  'Arguments · one per line',
                  '参数 · 每行一个',
                ),
              ),
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
              _FieldLabel(text: context.localized('Environment', '环境变量')),
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
        _FieldLabel(text: context.localized('Server URL', '服务地址')),
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
              _FieldLabel(text: context.localized('Headers', '请求头')),
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
              _FieldLabel(
                text: context.localized('Bearer token env', '令牌环境变量'),
              ),
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
          context.localized(
            'Knowledge is collected from imports and Agent context; it cannot be newly authored here yet.',
            '知识库内容来自导入和 Agent 上下文，暂时不能在这里直接新建。',
          ),
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
              ? context.localized('Project installation scope', '项目安装范围')
              : context.localized('Trigger scope', '触发范围'),
        ),
        if (nativeProject) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            context.localized(
              'DingDong copies the complete Skill package into each selected project\'s native directory. The Skill is discovered only when that Agent works in the project.',
              'DingDong 会把完整 Skill 包复制到每个所选项目的 Agent 原生目录；只有该 Agent 在这些项目中工作时才会发现它。',
            ),
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
                                  ? context.localized(
                                      'No project selected',
                                      '尚未选择项目',
                                    )
                                  : context.localized(
                                      'All projects · no restriction',
                                      '所有项目 · 不限制',
                                    )
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
                                ? context.localized(
                                    'Configure projects',
                                    '配置项目',
                                  )
                                : context.localized('Choose rules', '选择规则')
                          : context.localized(
                              '${names.length} selected',
                              '已选 ${names.length} 个',
                            ),
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

class _SkillDeliveryEditor extends StatelessWidget {
  const _SkillDeliveryEditor({
    required this.agents,
    required this.deliveryByAgent,
    required this.hooksEnabledByAgent,
    required this.impeccable,
    required this.onDeliveryChanged,
    required this.onHookChanged,
  });

  final List<SkillDeliveryAgentOption> agents;
  final Map<String, SkillDeliveryMode> deliveryByAgent;
  final Map<String, bool> hooksEnabledByAgent;
  final bool impeccable;
  final void Function(String agentId, SkillDeliveryMode mode) onDeliveryChanged;
  final void Function(String agentId, bool enabled) onHookChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<SkillDeliveryAgentOption> primaryAgents = agents
        .where(
          (SkillDeliveryAgentOption agent) =>
              agent.available ||
              (deliveryByAgent[agent.id] ?? SkillDeliveryMode.dynamic) !=
                  SkillDeliveryMode.dynamic ||
              (hooksEnabledByAgent[agent.id] ?? false),
        )
        .toList(growable: false);
    final List<SkillDeliveryAgentOption> uninstalledAgents = agents
        .where(
          (SkillDeliveryAgentOption agent) =>
              !agent.available && !primaryAgents.contains(agent),
        )
        .toList(growable: false);
    return DesktopDisclosure(
      key: const Key('skill-delivery-settings'),
      initiallyExpanded: true,
      leading: const Icon(Icons.inventory_2_outlined, size: 16),
      title: Text(
        context.localized('Delivery by Agent', '按 Agent 交付'),
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            context.localized(
              'Dynamic loads on demand through DingDong. Native · Global installs in the Agent user directory. Native · Project installs only in selected projects.',
              '动态通过 DingDong 按需加载；原生 · 全局安装到 Agent 用户目录；原生 · 项目只安装到所选项目。',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (primaryAgents.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _SkillDeliveryAgentList(
              agents: primaryAgents,
              deliveryByAgent: deliveryByAgent,
              hooksEnabledByAgent: hooksEnabledByAgent,
              impeccable: impeccable,
              onDeliveryChanged: onDeliveryChanged,
              onHookChanged: onHookChanged,
            ),
          ],
          if (uninstalledAgents.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            DesktopDisclosure(
              key: const Key('skill-delivery-uninstalled-agents'),
              title: Text(
                context.localized(
                  'Not installed Agents (${uninstalledAgents.length})',
                  '未安装的 Agent（${uninstalledAgents.length}）',
                ),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: _SkillDeliveryAgentList(
                agents: uninstalledAgents,
                deliveryByAgent: deliveryByAgent,
                hooksEnabledByAgent: hooksEnabledByAgent,
                impeccable: impeccable,
                onDeliveryChanged: onDeliveryChanged,
                onHookChanged: onHookChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkillDeliveryAgentList extends StatelessWidget {
  const _SkillDeliveryAgentList({
    required this.agents,
    required this.deliveryByAgent,
    required this.hooksEnabledByAgent,
    required this.impeccable,
    required this.onDeliveryChanged,
    required this.onHookChanged,
  });

  final List<SkillDeliveryAgentOption> agents;
  final Map<String, SkillDeliveryMode> deliveryByAgent;
  final Map<String, bool> hooksEnabledByAgent;
  final bool impeccable;
  final void Function(String agentId, SkillDeliveryMode mode) onDeliveryChanged;
  final void Function(String agentId, bool enabled) onHookChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (int index = 0; index < agents.length; index++) ...<Widget>[
        if (index > 0) const SizedBox(height: 13),
        _SkillDeliveryAgentRow(
          agent: agents[index],
          delivery:
              deliveryByAgent[agents[index].id] ?? SkillDeliveryMode.dynamic,
          hookEnabled: hooksEnabledByAgent[agents[index].id] ?? false,
          impeccable: impeccable,
          onDeliveryChanged: onDeliveryChanged,
          onHookChanged: onHookChanged,
        ),
      ],
    ],
  );
}

class _SkillDeliveryAgentRow extends StatelessWidget {
  const _SkillDeliveryAgentRow({
    required this.agent,
    required this.delivery,
    required this.hookEnabled,
    required this.impeccable,
    required this.onDeliveryChanged,
    required this.onHookChanged,
  });

  final SkillDeliveryAgentOption agent;
  final SkillDeliveryMode delivery;
  final bool hookEnabled;
  final bool impeccable;
  final void Function(String agentId, SkillDeliveryMode mode) onDeliveryChanged;
  final void Function(String agentId, bool enabled) onHookChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                agent.label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (!agent.available)
              Text(
                context.localized('Not installed', '未安装'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _FlatChoiceRow<SkillDeliveryMode>(
          selected: delivery,
          choices: <_Choice<SkillDeliveryMode>>[
            _Choice<SkillDeliveryMode>(
              value: SkillDeliveryMode.dynamic,
              keyName: 'skill-delivery-${agent.id}-dynamic',
              label: context.localized('Dynamic', '动态'),
            ),
            _Choice<SkillDeliveryMode>(
              value: SkillDeliveryMode.nativeUser,
              keyName: 'skill-delivery-${agent.id}-native-user',
              label: context.localized('Native · User', '原生 · 全局'),
              enabled: agent.available,
            ),
            _Choice<SkillDeliveryMode>(
              value: SkillDeliveryMode.nativeProject,
              keyName: 'skill-delivery-${agent.id}-native-project',
              label: context.localized('Native · Project', '原生 · 项目'),
              enabled: agent.available,
            ),
          ],
          onSelected: (SkillDeliveryMode mode) =>
              onDeliveryChanged(agent.id, mode),
        ),
        if (agent.id == 'codex' &&
            impeccable &&
            delivery == SkillDeliveryMode.nativeProject) ...<Widget>[
          const SizedBox(height: 5),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.localized(
                    'Impeccable project Hook (approval required in /hooks)',
                    'Impeccable 项目 Hook（需在 /hooks 中批准）',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 10),
              CompactSwitch(
                key: const Key('skill-hook-codex'),
                value: hookEnabled,
                onChanged: (bool value) => onHookChanged('codex', value),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ResourceOptions extends StatelessWidget {
  const _ResourceOptions({
    required this.updateUrlController,
    required this.pinned,
    required this.enabled,
    required this.showSync,
    required this.showUpdateLink,
    required this.onPinnedChanged,
    required this.onEnabledChanged,
    required this.onSync,
  });

  final TextEditingController updateUrlController;
  final bool pinned;
  final bool enabled;
  final bool showSync;
  final bool showUpdateLink;
  final ValueChanged<bool> onPinnedChanged;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return DesktopDisclosure(
      key: const Key('resource-advanced-settings'),
      leading: const Icon(Icons.tune_rounded, size: 16),
      title: Text(
        context.localized('Other settings', '其它设置'),
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showUpdateLink) ...<Widget>[
            _FieldLabel(text: context.localized('Update link', '更新链接')),
            const SizedBox(height: 7),
            Row(
              children: <Widget>[
                Expanded(
                  child: DesktopTextField(
                    key: const Key('resource-update-url'),
                    controller: updateUrlController,
                    decoration: const InputDecoration(
                      hintText: 'HTTPS or GitHub file URL',
                    ),
                  ),
                ),
                if (showSync) ...<Widget>[
                  const SizedBox(width: 8),
                  DesktopIconButton(
                    key: const Key('resource-sync-update'),
                    tooltip: context.localized(
                      'Fetch latest content',
                      '获取最新内容',
                    ),
                    onPressed: onSync,
                    icon: const Icon(Icons.sync_rounded),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              Expanded(
                child: _InlineToggle(
                  key: const Key('resource-pinned'),
                  label: context.localized('Pin in library', '在资源库置顶'),
                  value: pinned,
                  onChanged: onPinnedChanged,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _InlineToggle(
                  key: const Key('resource-enabled'),
                  label: context.localized(
                    'Available to installed Agents',
                    '对已安装的 Agent 可用',
                  ),
                  value: enabled,
                  onChanged: onEnabledChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditorActions extends StatelessWidget {
  const _EditorActions({
    required this.existing,
    required this.onDelete,
    required this.onReset,
    required this.onSave,
    required this.saving,
    required this.saved,
    required this.syncing,
  });

  final bool existing;
  final Future<void> Function()? onDelete;
  final VoidCallback onReset;
  final Future<void> Function() onSave;
  final bool saving;
  final bool saved;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 400) {
          return Row(
            children: <Widget>[
              if (existing)
                DesktopIconButton(
                  tooltip: context.localized('Delete', '删除'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              const Spacer(),
              DesktopIconButton(
                tooltip: context.localized('Reset changes', '重置更改'),
                onPressed: onReset,
                icon: const Icon(Icons.undo_rounded),
              ),
              const SizedBox(width: 6),
              DesktopActionButton(
                key: const Key('resource-save'),
                onPressed: saving ? null : onSave,
                child: _SaveButtonLabel(
                  saving: saving,
                  saved: saved,
                  syncing: syncing,
                ),
              ),
            ],
          );
        }
        return Row(
          children: <Widget>[
            if (existing)
              DesktopActionButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(context.localized('Delete', '删除')),
              ),
            const Spacer(),
            DesktopActionButton(
              onPressed: onReset,
              child: Text(context.localized('Reset', '重置')),
            ),
            const SizedBox(width: 8),
            DesktopActionButton(
              key: const Key('resource-save'),
              onPressed: saving ? null : onSave,
              child: _SaveButtonLabel(
                saving: saving,
                saved: saved,
                syncing: syncing,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SaveButtonLabel extends StatelessWidget {
  const _SaveButtonLabel({
    required this.saving,
    required this.saved,
    required this.syncing,
  });

  final bool saving;
  final bool saved;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    final String label = saving
        ? context.localized('Saving…', '保存中…')
        : saved
        ? context.localized('Saved', '已保存')
        : syncing
        ? context.localized('Install Skill', '安装 Skill')
        : context.localized('Save', '保存');
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: Row(
        key: ValueKey<String>(label),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (saving)
            const SizedBox.square(
              dimension: 13,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            )
          else if (saved)
            const Icon(Icons.check_rounded, size: 16),
          if (saving || saved) const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _FlatChoiceRow<T> extends StatelessWidget {
  const _FlatChoiceRow({
    required this.selected,
    required this.choices,
    required this.onSelected,
  });

  final T selected;
  final List<_Choice<T>> choices;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        for (int index = 0; index < choices.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: 6),
          Expanded(
            child: DesktopActionButton(
              key: Key(choices[index].keyName),
              onPressed: choices[index].enabled
                  ? () => onSelected(choices[index].value)
                  : null,
              style: DesktopActionButton.styleFrom(
                minimumSize: const Size(0, 34),
                foregroundColor: choices[index].value == selected
                    ? colors.primary
                    : colors.onSurfaceVariant,
                backgroundColor: choices[index].value == selected
                    ? colors.primary.withValues(alpha: 0.09)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: Text(
                choices[index].label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: choices[index].value == selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

final class _Choice<T> {
  const _Choice({
    required this.value,
    required this.keyName,
    required this.label,
    this.enabled = true,
  });

  final T value;
  final String keyName;
  final String label;
  final bool enabled;
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[left, const SizedBox(height: 12), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _MultilineField extends StatelessWidget {
  const _MultilineField({
    required this.controller,
    required this.height,
    this.hintText,
    this.monospace = false,
    this.readOnly = false,
    super.key,
  });

  final TextEditingController controller;
  final double height;
  final String? hintText;
  final bool monospace;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DesktopTextField(
        controller: controller,
        readOnly: readOnly,
        expands: true,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        style: monospace ? const TextStyle(fontFamily: 'monospace') : null,
        decoration: InputDecoration(hintText: hintText),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _InlineToggle extends StatelessWidget {
  const _InlineToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(4),
    onTap: () => onChanged(!value),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          const SizedBox(width: 10),
          CompactSwitch(value: value, onChanged: onChanged),
        ],
      ),
    ),
  );
}

String _typeLabel(BuildContext context, ResourceType type) {
  return switch (type) {
    ResourceType.prompt => context.localized('Prompt', '提示词'),
    ResourceType.skill => context.localized('Skill', 'Skill'),
    ResourceType.mcp => 'MCP',
    ResourceType.knowledge => context.localized('Knowledge', '知识库'),
    ResourceType.clipboard => context.localized('Clipboard', '剪贴板'),
  };
}

IconData _typeIcon(ResourceType type) {
  return switch (type) {
    ResourceType.prompt => Icons.format_quote_rounded,
    ResourceType.skill => Icons.auto_awesome_outlined,
    ResourceType.mcp => Icons.dns_outlined,
    ResourceType.knowledge => Icons.folder_outlined,
    ResourceType.clipboard => Icons.content_paste_outlined,
  };
}

String _typeDescription(BuildContext context, ResourceType type) {
  return switch (type) {
    ResourceType.prompt => context.localized(
      'Required instructions that are applied automatically whenever active.',
      '命中后必须自动应用的完整指令。',
    ),
    ResourceType.skill => context.localized(
      'Matched by description, then loaded as a complete Skill package only when needed.',
      '先按 description 匹配，需要时才加载完整 Skill 包。',
    ),
    ResourceType.mcp => context.localized(
      'A tool connection whose MCP tools are called only when the task requires them.',
      '提供 MCP 工具连接，仅在任务需要时调用。',
    ),
    ResourceType.knowledge => context.localized(
      'Imported knowledge available to Agent context.',
      '已导入、可供 Agent 使用的知识库内容。',
    ),
    ResourceType.clipboard => context.localized('Clipboard item.', '剪贴板条目。'),
  };
}

String _titleLabel(BuildContext context, ResourceType type) {
  return switch (type) {
    ResourceType.prompt => context.localized('Prompt name', '提示词名称'),
    ResourceType.skill => context.localized('Skill name', 'Skill 名称'),
    ResourceType.mcp => context.localized('Server name', '服务名称'),
    ResourceType.knowledge => context.localized('Name', '名称'),
    ResourceType.clipboard => context.localized('Name', '名称'),
  };
}

String _titleHint(BuildContext context, ResourceType type) {
  return switch (type) {
    ResourceType.prompt => context.localized(
      'e.g. Concise release notes',
      '例如：简洁发布说明',
    ),
    ResourceType.skill => context.localized(
      'lowercase-hyphen-name',
      '使用小写英文与连字符',
    ),
    ResourceType.mcp => context.localized('e.g. Figma', '例如：Figma'),
    ResourceType.knowledge => '',
    ResourceType.clipboard => '',
  };
}
