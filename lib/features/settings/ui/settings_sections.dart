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
        if (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows) ...<Widget>[
          _trayStyleRow(context, attention: false),
          _SettingRow(
            label: context.l10n.completionTrayColor,
            child: _TrayNotificationColorPicker(
              value:
                  rules.completionTrayColor ?? settings.trayNotificationColor,
              onChanged: (color) => rules.completionTrayColor == null
                  ? viewModel.setTrayNotificationColor(color)
                  : _setRules(rules.copyWith(completionTrayColor: color)),
            ),
          ),
          _trayStyleRow(context, attention: true),
          _SettingRow(
            label: context.l10n.attentionTrayColor,
            child: _TrayNotificationColorPicker(
              keyPrefix: 'settings-attention-tray-color',
              value: rules.attentionTrayColor,
              onChanged: (color) =>
                  _setRules(rules.copyWith(attentionTrayColor: color)),
            ),
          ),
        ],
        _SettingRow(
          label: context.l10n.completionSound,
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
        ..._attentionSoundRows(context),
        CompactSwitchListTile(
          key: const Key('settings-push-completion-to-phone'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.pushCompletionToPhone),
          subtitle: Text(context.l10n.pushToPhoneDescription),
          value: rules.completionToPhone,
          onChanged: (bool value) =>
              _setRules(rules.copyWith(completionToPhone: value)),
        ),
        CompactSwitchListTile(
          key: const Key('settings-push-attention-to-phone'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.pushAttentionToPhone),
          value: rules.attentionToPhone,
          onChanged: (bool value) =>
              _setRules(rules.copyWith(attentionToPhone: value)),
        ),
        _SettingRow(
          label: context.l10n.completionMinimumDuration,
          child: SizedBox(
            width: 220,
            child: DesktopSelectField<int>(
              key: const Key('settings-completion-minimum-minutes'),
              value: rules.completionMinimumMinutes,
              items: NotificationRules.completionMinimumChoices
                  .map(
                    (int minutes) => DesktopSelectItem<int>(
                      value: minutes,
                      label: minutes == 0
                          ? context.l10n.completionMinimumAny
                          : context.l10n.completionMinimumMinutes(minutes),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (int value) =>
                  _setRules(rules.copyWith(completionMinimumMinutes: value)),
            ),
          ),
        ),
        if (rules.completionMinimumMinutes > 0)
          Text(
            context.l10n.completionMinimumDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        CompactSwitchListTile(
          key: const Key('settings-quiet-hours'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.quietHours),
          subtitle: Text(context.l10n.quietHoursDescription),
          value: rules.quietHours.enabled,
          onChanged: (bool value) => _setRules(
            rules.copyWith(
              quietHours: rules.quietHours.copyWith(enabled: value),
            ),
          ),
        ),
        if (rules.quietHours.enabled) ...<Widget>[
          _SettingRow(
            label: context.l10n.quietHoursFrom,
            child: _MinuteOfDayField(
              key: const Key('settings-quiet-hours-start'),
              value: rules.quietHours.startMinute,
              onChanged: (int value) => _setRules(
                rules.copyWith(
                  quietHours: rules.quietHours.copyWith(startMinute: value),
                ),
              ),
            ),
          ),
          _SettingRow(
            label: context.l10n.quietHoursTo,
            child: _MinuteOfDayField(
              key: const Key('settings-quiet-hours-end'),
              value: rules.quietHours.endMinute,
              onChanged: (int value) => _setRules(
                rules.copyWith(
                  quietHours: rules.quietHours.copyWith(endMinute: value),
                ),
              ),
            ),
          ),
          CompactSwitchListTile(
            key: const Key('settings-quiet-hours-allow-attention'),
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.quietHoursAllowAttention),
            value: rules.quietHours.allowAttention,
            onChanged: (bool value) => _setRules(
              rules.copyWith(
                quietHours: rules.quietHours.copyWith(allowAttention: value),
              ),
            ),
          ),
        ],
      ],
    );
  }

  NotificationRules get rules => settings.notificationRules;

  Future<void> _setRules(NotificationRules value) =>
      viewModel.setNotificationRules(value);

  Widget _trayStyleRow(BuildContext context, {required bool attention}) {
    return _SettingRow(
      label: attention
          ? context.l10n.attentionTrayStyle
          : context.l10n.completionTrayStyle,
      child: SizedBox(
        width: 220,
        child: DesktopSelectField<TrayReminderStyle>(
          key: Key(
            attention
                ? 'settings-attention-tray-style'
                : 'settings-completion-tray-style',
          ),
          value: attention
              ? rules.attentionTrayStyle
              : rules.completionTrayStyle,
          items: <DesktopSelectItem<TrayReminderStyle>>[
            DesktopSelectItem(
              value: TrayReminderStyle.staticMarker,
              label: context.l10n.trayStyleStatic,
            ),
            DesktopSelectItem(
              value: TrayReminderStyle.softPulse,
              label: context.l10n.trayStylePulse,
            ),
          ],
          onChanged: (value) => _setRules(
            attention
                ? rules.copyWith(attentionTrayStyle: value)
                : rules.copyWith(completionTrayStyle: value),
          ),
        ),
      ),
    );
  }

  List<Widget> _attentionSoundRows(BuildContext context) {
    final String sound = rules.attentionSound;
    final String previewSound = sound == sameAsCompletionSound
        ? settings.selectedSound
        : sound;
    final String? previewPath = sound == sameAsCompletionSound
        ? settings.customSoundPath
        : rules.attentionCustomSoundPath;
    return <Widget>[
      _SettingRow(
        label: context.l10n.attentionSound,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 220,
              child: DesktopSelectField<String>(
                key: const Key('settings-attention-sound'),
                value: sound,
                items: <DesktopSelectItem<String>>[
                  DesktopSelectItem<String>(
                    value: sameAsCompletionSound,
                    label: context.l10n.sameAsCompletionSound,
                  ),
                  for (final SoundChoice choice in soundChoices)
                    DesktopSelectItem<String>(
                      value: choice.value,
                      label: _soundChoiceLabel(context, choice),
                    ),
                ],
                onChanged: (String value) =>
                    _setRules(rules.copyWith(attentionSound: value)),
              ),
            ),
            const SizedBox(width: 8),
            DesktopIconButton(
              key: const Key('settings-preview-attention-sound'),
              tooltip: context.l10n.previewSound,
              onPressed: soundPreviewGateway == null || previewSound == 'muted'
                  ? null
                  : () => soundPreviewGateway!.preview(
                      sound: previewSound,
                      customSoundPath: previewPath,
                    ),
              icon: const Icon(Icons.volume_up_outlined, size: 18),
            ),
          ],
        ),
      ),
      if (sound == 'custom')
        _SettingRow(
          label: context.l10n.attentionCustomFile,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 240,
                child: Text(
                  rules.attentionCustomSoundPath ??
                      context.l10n.noSoundSelected,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              DesktopActionButton(
                key: const Key('settings-choose-attention-sound'),
                onPressed: soundFileGateway == null
                    ? null
                    : _chooseAttentionSound,
                label: context.l10n.choose,
                tone: DesktopActionTone.neutral,
              ),
            ],
          ),
        ),
    ];
  }

  Future<void> _chooseCustomSound() async {
    final String? path = await soundFileGateway?.chooseSoundFile();
    if (path != null) {
      await viewModel.setCustomSoundPath(path);
    }
  }

  Future<void> _chooseAttentionSound() async {
    final String? path = await soundFileGateway?.chooseSoundFile();
    if (path != null) {
      await _setRules(rules.copyWith(attentionCustomSoundPath: path));
    }
  }
}

/// Half-hour local time choices for quiet hours.
class _MinuteOfDayField extends StatelessWidget {
  const _MinuteOfDayField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<int> minutes = <int>{
      for (int minute = 0; minute < 24 * 60; minute += 30) minute,
      value,
    }.toList()..sort();
    return SizedBox(
      width: 120,
      child: DesktopSelectField<int>(
        value: value,
        items: minutes
            .map(
              (int minute) => DesktopSelectItem<int>(
                value: minute,
                label:
                    '${(minute ~/ 60).toString().padLeft(2, '0')}:'
                    '${(minute % 60).toString().padLeft(2, '0')}',
              ),
            )
            .toList(growable: false),
        onChanged: onChanged,
      ),
    );
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
    final usagePreview = settings.showConversationTokenUsage
        ? ' · ${formatConversationTokenUsage(const ConversationTokenUsage(source: ConversationTokenUsageSource.codex, totalTokens: 12400, inputTokens: 12000, outputTokens: 400, cachedInputTokens: 8000))}'
        : '';
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
                  '$usagePreview',
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
    this.keyPrefix = 'settings-tray-notification-color',
    required this.value,
    required this.onChanged,
  });

  final String keyPrefix;
  final TrayNotificationColor value;
  final ValueChanged<TrayNotificationColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return DesktopSegmentedControl<TrayNotificationColor>(
      key: Key(keyPrefix),
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
                    key: Key('$keyPrefix-${color.name}'),
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
                        ? Icon(
                            Icons.check_rounded,
                            size: 14,
                            color:
                                Color(
                                      0xFF000000 | color.rgbValue,
                                    ).computeLuminance() >
                                    0.179
                                ? Colors.black
                                : Colors.white,
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
    TrayNotificationColor.amber => context.l10n.amber,
  };
}
