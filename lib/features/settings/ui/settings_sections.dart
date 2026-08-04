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
        'Choose how DingDong looks and sounds when an Agent completes a task.',
        '选择 Agent 完成任务时 DingDong 的提示颜色和声音。',
      ),
      children: <Widget>[
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
