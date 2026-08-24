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

// Private editor sections stay in the same Dart library so they can share the
// form state without widening the public API of ResourceEditor.
part 'resource_editor_chrome.dart';
part 'resource_editor_controls.dart';
part 'resource_editor_delivery_section.dart';
part 'resource_editor_mcp_section.dart';
part 'resource_editor_skill_section.dart';

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
          context.l10n.configurationSaved,
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
        _saveError = context.l10n.enterAValidWebSourceBeforeOpeningIt;
      });
      return;
    }
    try {
      await widget.onOpenExternalLink!(uri);
    } on Object {
      if (mounted) {
        setState(() {
          _saveError = context.l10n.couldNotOpenThisSkillSource;
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
        _saveError = context.l10n.thisOnlineSkillDoesNotHaveAnAvailableSource;
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
          context.l10n.onlineSkillUpdated,
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
        return context.l10n.couldNotSyncThisResourceToAnInstalledAgentDetail(
          detail,
        );
      }
      return context
          .l10n
          .onlineSyncIsNotReadyInThisWindowReopenResourceManagerAnd_2ceb1f90;
    }
    if (error is TimeoutException || error is SocketException) {
      return context
          .l10n
          .couldNotReachTheSourceCheckYourNetworkAndLinkThenTry_1c1ff9ae;
    }
    if (error is HttpException) {
      return context
          .l10n
          .theSourceDidNotReturnAUsableSKILLMdCheckTheRepository_8db02039;
    }
    if (error is FormatException) {
      if (_draftType == ResourceType.skill) {
        final String detail = error.message.toString();
        if (detail.contains('delivery') ||
            detail.contains('native') ||
            detail.contains('Hook') ||
            detail.contains('project trigger scope')) {
          return context.l10n.couldNotApplyThisSkillDeliveryPolicyDetail(
            detail,
          );
        }
        if (_skillSourceMode == SkillSourceMode.local) {
          return context
              .l10n
              .skillMdNeedsValidNameAndDescriptionFieldsInItsYAML_c05294f5;
        }
        return context
            .l10n
            .pasteAGitHubSkillRepositoryFolderOrDirectSKILLMdLink_1ee790e1;
      }
      if (_draftType == ResourceType.mcp) {
        return context.l10n.useAValidSTDIOOrStreamableHTTPMCPConfiguration;
      }
    }
    return context.l10n.couldNotSaveThisConfigurationCheckTheContentAndTryAgain;
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
