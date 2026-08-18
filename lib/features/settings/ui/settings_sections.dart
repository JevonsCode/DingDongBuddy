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
      title: context.localized('Notifications', '通知'),
      description: context.localized(
        'Choose which Agent events should notify you, then customize the alert sound and color.',
        '选择哪些 Agent 事件需要提醒，再自定义提示声音和颜色。',
      ),
      children: <Widget>[
        CompactSwitchListTile(
          key: const Key('settings-notify-agent-completion'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.localized('Agent completion notifications', 'Agent 完成提醒'),
          ),
          subtitle: Text(
            context.localized(
              'Notify when an Agent finishes its current task turn.',
              'Agent 完成本轮任务时提醒。',
            ),
          ),
          value: settings.notifyAgentCompletion,
          onChanged: viewModel.setNotifyAgentCompletion,
        ),
        CompactSwitchListTile(
          key: const Key('settings-notify-agent-attention'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.localized('Needs your input', '需要你处理')),
          subtitle: Text(
            context.localized(
              'Notify when an Agent is waiting for confirmation, a choice, or your takeover.',
              'Agent 等待确认、选择或需要你接管时提醒。',
            ),
          ),
          value: settings.notifyAgentAttention,
          onChanged: viewModel.setNotifyAgentAttention,
        ),
        CompactSwitchListTile(
          key: const Key('settings-notify-codex-voice-activity'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.localized('Codex voice task notifications', 'Codex 语音任务提醒'),
          ),
          subtitle: Text(
            context.localized(
              'When off, tasks started in Codex voice mode do not notify or play a DingDong sound.',
              '关闭后，从 Codex 语音模式发起的任务不显示提醒，也不播放叮咚声音。',
            ),
          ),
          value: settings.notifyCodexVoiceActivity,
          onChanged: viewModel.setNotifyCodexVoiceActivity,
        ),
        CompactSwitchListTile(
          key: const Key('settings-notify-subagent-activity'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.localized('Subagent notifications', '子智能体提醒')),
          subtitle: Text(
            context.localized(
              'When off, subagent activity shows no notification or DingDong sound.',
              '关闭后，子智能体动态不显示提醒，也不播放叮咚声音。',
            ),
          ),
          value: settings.notifySubagentActivity,
          onChanged: viewModel.setNotifySubagentActivity,
        ),
        if (defaultTargetPlatform == TargetPlatform.macOS)
          _SettingRow(
            label:
                '${context.localized('Menu bar alert color', '菜单栏提示颜色')} · '
                '${_trayNotificationColorLabel(context, settings.trayNotificationColor)}',
            child: _TrayNotificationColorPicker(
              value: settings.trayNotificationColor,
              onChanged: viewModel.setTrayNotificationColor,
            ),
          ),
        _SettingRow(
          label: context.localized('Sound', '声音'),
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
                          label: context.localized(
                            choice.englishLabel,
                            choice.chineseLabel,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: viewModel.setSelectedSound,
                ),
              ),
              const SizedBox(width: 8),
              DesktopIconButton(
                key: const Key('settings-preview-sound'),
                tooltip: context.localized('Preview sound', '试听声音'),
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
            label: context.localized('Custom file', '自定义文件'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 240,
                  child: Text(
                    settings.customSoundPath ??
                        context.localized('No sound selected', '尚未选择声音'),
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
                  label: context.localized('Choose', '选择'),
                  tone: DesktopActionTone.neutral,
                ),
                if (settings.customSoundPath != null) ...<Widget>[
                  const SizedBox(width: 6),
                  DesktopIconButton(
                    tooltip: context.localized('Clear custom sound', '清除自定义声音'),
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
      title: context.localized('Agent reply footer', 'Agent 回复尾部'),
      description: context.localized(
        'Configure the final DingDong resource line and optionally append exact session usage.',
        '配置 DingDong 最终资源行，并可选择追加精确的本轮会话用量。',
      ),
      children: <Widget>[
        CompactSwitchListTile(
          key: const Key('settings-show-conversation-token-usage'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.localized('Show conversation Token usage', '显示会话 Token 用量'),
          ),
          subtitle: Text(
            context.localized(
              'Shown only when Codex, Claude Code, or Pi provides exact local usage. Unsupported Agents are not estimated.',
              '仅在 Codex、Claude Code 或 Pi 可提供本机精确用量时显示；不支持的 Agent 不做估算。',
            ),
          ),
          value: settings.showConversationTokenUsage,
          onChanged: viewModel.setShowConversationTokenUsage,
        ),
        _SettingRow(
          label: context.localized('Prompt symbol', 'Prompt 符号'),
          child: _ConversationFooterSymbolField(
            fieldKey: const Key('settings-conversation-symbol-prompt'),
            semanticLabel: context.localized(
              'Prompt footer symbol',
              'Prompt 尾部符号',
            ),
            semanticHint: context.localized(
              'Enter one visible symbol. Asterisk and vertical bar are reserved.',
              '输入一个可见符号。星号和竖线为保留字符。',
            ),
            value: symbols.prompt,
            onChanged: (String value) =>
                unawaited(viewModel.setConversationFooterSymbol(prompt: value)),
          ),
        ),
        _SettingRow(
          label: context.localized('Skill symbol', 'Skill 符号'),
          child: _ConversationFooterSymbolField(
            fieldKey: const Key('settings-conversation-symbol-skill'),
            semanticLabel: context.localized(
              'Skill footer symbol',
              'Skill 尾部符号',
            ),
            semanticHint: context.localized(
              'Enter one visible symbol. Asterisk and vertical bar are reserved.',
              '输入一个可见符号。星号和竖线为保留字符。',
            ),
            value: symbols.skill,
            onChanged: (String value) =>
                unawaited(viewModel.setConversationFooterSymbol(skill: value)),
          ),
        ),
        _SettingRow(
          label: context.localized('MCP symbol', 'MCP 符号'),
          child: _ConversationFooterSymbolField(
            fieldKey: const Key('settings-conversation-symbol-mcp'),
            semanticLabel: context.localized('MCP footer symbol', 'MCP 尾部符号'),
            semanticHint: context.localized(
              'Enter one visible symbol. Asterisk and vertical bar are reserved.',
              '输入一个可见符号。星号和竖线为保留字符。',
            ),
            value: symbols.mcp,
            onChanged: (String value) =>
                unawaited(viewModel.setConversationFooterSymbol(mcp: value)),
          ),
        ),
        _SettingRow(
          label: context.localized('Preview', '预览'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              SelectableText(
                'DingDong · ${symbols.prompt} Prompt | '
                '${symbols.skill} Skill* | ${symbols.mcp} MCP'
                '${settings.showConversationTokenUsage ? ' · 12.4K Token' : ''}',
                key: const Key('settings-conversation-footer-preview'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              DesktopActionButton(
                key: const Key('settings-conversation-symbols-reset'),
                label: context.localized('Restore defaults', '恢复默认'),
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
    TrayNotificationColor.orange => context.localized('Orange', '橙黄'),
    TrayNotificationColor.pink => context.localized('Pink', '粉色'),
    TrayNotificationColor.blue => context.localized('Blue', '蓝色'),
    TrayNotificationColor.green => context.localized('Green', '绿色'),
    TrayNotificationColor.purple => context.localized('Purple', '紫色'),
  };
}
