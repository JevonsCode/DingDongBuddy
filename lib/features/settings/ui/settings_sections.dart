part of 'settings_screen.dart';

class _NotificationSettingsSection extends StatelessWidget {
  const _NotificationSettingsSection({
    required this.viewModel,
    required this.settings,
    required this.soundFileGateway,
    required this.soundPreviewGateway,
    super.key,
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
        ReminderProfilesEditor(
          viewModel: viewModel,
          settings: settings,
          soundFileGateway: soundFileGateway,
          soundPreviewGateway: soundPreviewGateway,
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
