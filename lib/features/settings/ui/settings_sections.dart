part of 'settings_screen.dart';

class _NotificationSettingsSection extends StatelessWidget {
  const _NotificationSettingsSection({
    required this.viewModel,
    required this.settings,
    required this.soundFileGateway,
    required this.soundPreviewGateway,
  });

  final SettingsViewModel viewModel;
  final AppSettings settings;
  final SoundFileGateway? soundFileGateway;
  final SoundPreviewGateway? soundPreviewGateway;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: context.l10n.notifications,
      description: context
          .l10n
          .chooseWhichAgentEventsShouldNotifyYouThenCustomizeThe_7d9141e4,
      children: <Widget>[
        CompactSwitchListTile(
          key: const Key('settings-notify-agent-completion'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.agentCompletionNotifications),
          subtitle: Text(
            context.l10n.notifyWhenAnAgentFinishesItsCurrentTaskTurn,
          ),
          value: settings.notifyAgentCompletion,
          onChanged: viewModel.setNotifyAgentCompletion,
        ),
        CompactSwitchListTile(
          key: const Key('settings-notify-agent-attention'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.needsYourInput2),
          subtitle: Text(
            context
                .l10n
                .notifyWhenAnAgentIsWaitingForConfirmationAChoiceOrYour_825d0876,
          ),
          value: settings.notifyAgentAttention,
          onChanged: viewModel.setNotifyAgentAttention,
        ),
        CompactSwitchListTile(
          key: const Key('settings-notify-codex-voice-activity'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.codexVoiceTaskNotifications),
          subtitle: Text(
            context
                .l10n
                .whenOffTasksStartedInCodexVoiceModeDoNotNotifyOrPlayA_75237958,
          ),
          value: settings.notifyCodexVoiceActivity,
          onChanged: viewModel.setNotifyCodexVoiceActivity,
        ),
        CompactSwitchListTile(
          key: const Key('settings-notify-subagent-activity'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.subagentNotifications),
          subtitle: Text(
            context
                .l10n
                .whenOffSubagentActivityShowsNoNotificationOrDingDong_ce161d98,
          ),
          value: settings.notifySubagentActivity,
          onChanged: viewModel.setNotifySubagentActivity,
        ),
        if (defaultTargetPlatform == TargetPlatform.macOS)
          _SettingRow(
            label:
                '${context.l10n.menuBarAlertColor} · '
                '${_trayNotificationColorLabel(context, settings.trayNotificationColor)}',
            child: _TrayNotificationColorPicker(
              value: settings.trayNotificationColor,
              onChanged: viewModel.setTrayNotificationColor,
            ),
          ),
        _SettingRow(
          label: context.l10n.sound,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 220,
                child: DesktopSelectField<String>(
                  key: const Key('settings-sound'),
                  value: settings.selectedSound,
                  items: soundChoices
                      .map(
                        (SoundChoice choice) => DesktopSelectItem<String>(
                          value: choice.value,
                          label: _soundChoiceLabel(context, choice),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: viewModel.setSelectedSound,
                ),
              ),
              const SizedBox(width: 8),
              DesktopIconButton(
                key: const Key('settings-preview-sound'),
                tooltip: context.l10n.previewSound,
                onPressed:
                    soundPreviewGateway == null ||
                        settings.selectedSound == 'muted'
                    ? null
                    : () => soundPreviewGateway!.preview(
                        sound: settings.selectedSound,
                        customSoundPath: settings.customSoundPath,
                      ),
                icon: const Icon(Icons.volume_up_outlined, size: 18),
              ),
            ],
          ),
        ),
        if (settings.selectedSound == 'custom')
          _SettingRow(
            label: context.l10n.customFile,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 240,
                  child: Text(
                    settings.customSoundPath ?? context.l10n.noSoundSelected,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                DesktopActionButton(
                  key: const Key('settings-choose-custom-sound'),
                  onPressed: soundFileGateway == null
                      ? null
                      : _chooseCustomSound,
                  label: context.l10n.choose,
                  tone: DesktopActionTone.neutral,
                ),
                if (settings.customSoundPath != null) ...<Widget>[
                  const SizedBox(width: 6),
                  DesktopIconButton(
                    tooltip: context.l10n.clearCustomSound,
                    onPressed: () => viewModel.setCustomSoundPath(null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _chooseCustomSound() async {
    final String? path = await soundFileGateway?.chooseSoundFile();
    if (path != null) {
      await viewModel.setCustomSoundPath(path);
    }
  }
}

String _soundChoiceLabel(BuildContext context, SoundChoice choice) =>
    switch (choice.value) {
      'default' => context.l10n.dingdongClassic,
      'dingSoft' => context.l10n.dingdongSoft,
      'dingBright' => context.l10n.dingdongBright,
      'dingCrisp' => context.l10n.dingdongCrisp,
      'dingDeep' => context.l10n.dingdongDeep,
      'custom' => context.l10n.customSound,
      'system' => context.l10n.systemSound,
      'muted' => context.l10n.muted,
      _ => choice.value,
    };

class _ConversationFooterSettingsSection extends StatelessWidget {
  const _ConversationFooterSettingsSection({
    required this.viewModel,
    required this.settings,
  });

  final SettingsViewModel viewModel;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final ConversationFooterSymbols symbols =
        settings.conversationFooterSymbols;
    return _SettingsSection(
      title: context.l10n.agentReplyFooter,
      description: context
          .l10n
          .configureTheFinalDingDongResourceLineAndOptionallyAppend_e6f7cb62,
      children: <Widget>[
        CompactSwitchListTile(
          key: const Key('settings-show-conversation-token-usage'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.showConversationTokenUsage),
          subtitle: Text(
            context
                .l10n
                .shownOnlyWhenCodexClaudeCodeOrPiProvidesExactLocalUsage_7e557397,
          ),
          value: settings.showConversationTokenUsage,
          onChanged: viewModel.setShowConversationTokenUsage,
        ),
        _SettingRow(
          label: context.l10n.promptSymbol,
          child: _ConversationFooterSymbolField(
            fieldKey: const Key('settings-conversation-symbol-prompt'),
            semanticLabel: context.l10n.promptFooterSymbol,
            semanticHint: context
                .l10n
                .enterOneVisibleSymbolAsteriskAndVerticalBarAreReserved,
            value: symbols.prompt,
            onChanged: (String value) =>
                unawaited(viewModel.setConversationFooterSymbol(prompt: value)),
          ),
        ),
        _SettingRow(
          label: context.l10n.skillSymbol,
          child: _ConversationFooterSymbolField(
            fieldKey: const Key('settings-conversation-symbol-skill'),
            semanticLabel: context.l10n.skillFooterSymbol,
            semanticHint: context
                .l10n
                .enterOneVisibleSymbolAsteriskAndVerticalBarAreReserved,
            value: symbols.skill,
            onChanged: (String value) =>
                unawaited(viewModel.setConversationFooterSymbol(skill: value)),
          ),
        ),
        _SettingRow(
          label: context.l10n.mcpSymbol,
          child: _ConversationFooterSymbolField(
            fieldKey: const Key('settings-conversation-symbol-mcp'),
            semanticLabel: context.l10n.mcpFooterSymbol,
            semanticHint: context
                .l10n
                .enterOneVisibleSymbolAsteriskAndVerticalBarAreReserved,
            value: symbols.mcp,
            onChanged: (String value) =>
                unawaited(viewModel.setConversationFooterSymbol(mcp: value)),
          ),
        ),
        _SettingRow(
          label: context.l10n.preview,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                SelectableText(
                  'DingDong · ${symbols.prompt} Prompt | '
                  '${symbols.skill} Skill* | ${symbols.mcp} MCP'
                  '${settings.showConversationTokenUsage ? ' · 12.4K Token' : ''}',
                  key: const Key('settings-conversation-footer-preview'),
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  context
                      .l10n
                      .aSkillMeansItsFullInstructionsWereLoadedForThisTaskAnMCP_240facd9,
                  key: const Key('settings-conversation-footer-marker-help'),
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                DesktopActionButton(
                  key: const Key('settings-conversation-symbols-reset'),
                  label: context.l10n.restoreDefaults,
                  tone: DesktopActionTone.neutral,
                  compact: true,
                  onPressed: symbols == ConversationFooterSymbols.defaultValue
                      ? null
                      : () => unawaited(
                          viewModel.setConversationFooterSymbols(
                            ConversationFooterSymbols.defaultValue,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConversationFooterSymbolField extends StatefulWidget {
  const _ConversationFooterSymbolField({
    required this.fieldKey,
    required this.semanticLabel,
    required this.semanticHint,
    required this.value,
    required this.onChanged,
  });

  final Key fieldKey;
  final String semanticLabel;
  final String semanticHint;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_ConversationFooterSymbolField> createState() =>
      _ConversationFooterSymbolFieldState();
}

class _ConversationFooterSymbolFieldState
    extends State<_ConversationFooterSymbolField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(_ConversationFooterSymbolField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) {
      _restoreValueIfInvalid();
    }
  }

  void _restoreValueIfInvalid() {
    if (!ConversationFooterSymbols.isValidSymbol(_controller.text)) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      textField: true,
      child: SizedBox(
        width: 68,
        child: DesktopTextField(
          key: widget.fieldKey,
          controller: _controller,
          focusNode: _focusNode,
          textAlign: TextAlign.center,
          inputFormatters: <TextInputFormatter>[
            LengthLimitingTextInputFormatter(1),
            _ConversationFooterSymbolInputFormatter(),
          ],
          onChanged: (String value) {
            final TextRange composing = _controller.value.composing;
            if ((!composing.isValid || composing.isCollapsed) &&
                ConversationFooterSymbols.isValidSymbol(value)) {
              widget.onChanged(value.trim());
            }
          },
          onSubmitted: (_) => _restoreValueIfInvalid(),
        ),
      ),
    );
  }
}

final class _ConversationFooterSymbolInputFormatter extends TextInputFormatter {
  const _ConversationFooterSymbolInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    return newValue.text.isEmpty ||
            ConversationFooterSymbols.isValidSymbol(newValue.text)
        ? newValue
        : oldValue;
  }
}

class _TrayNotificationColorPicker extends StatelessWidget {
  const _TrayNotificationColorPicker({
    required this.value,
    required this.onChanged,
  });

  final TrayNotificationColor value;
  final ValueChanged<TrayNotificationColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return DesktopSegmentedControl<TrayNotificationColor>(
      key: const Key('settings-tray-notification-color'),
      value: value,
      minimumSegmentWidth: 40,
      segments: TrayNotificationColor.values
          .map((TrayNotificationColor color) {
            final bool selected = color == value;
            final String label = _trayNotificationColorLabel(context, color);
            return DesktopSegment<TrayNotificationColor>(
              value: color,
              label: Tooltip(
                message: label,
                child: Semantics(
                  label: label,
                  selected: selected,
                  child: Container(
                    key: Key('settings-tray-notification-color-${color.name}'),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Color(0xFF000000 | color.rgbValue),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
      onChanged: onChanged,
    );
  }
}

String _trayNotificationColorLabel(
  BuildContext context,
  TrayNotificationColor color,
) {
  return switch (color) {
    TrayNotificationColor.orange => context.l10n.orange,
    TrayNotificationColor.pink => context.l10n.pink,
    TrayNotificationColor.blue => context.l10n.blue,
    TrayNotificationColor.green => context.l10n.green,
    TrayNotificationColor.purple => context.l10n.purple,
  };
}
