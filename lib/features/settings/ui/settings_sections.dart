part of 'settings_screen.dart';

class _NotificationSoundSettingsSection extends StatelessWidget {
  const _NotificationSoundSettingsSection({
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
      title: context.localized('Notification sound', '通知声音'),
      description: context.localized(
        'Used when an Agent completes a task without requesting a specific sound.',
        '当 Agent 完成任务且未指定声音时使用。',
      ),
      children: <Widget>[
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
              IconButton.outlined(
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
                OutlinedButton(
                  key: const Key('settings-choose-custom-sound'),
                  onPressed: soundFileGateway == null
                      ? null
                      : _chooseCustomSound,
                  child: Text(context.localized('Choose', '选择')),
                ),
                if (settings.customSoundPath != null) ...<Widget>[
                  const SizedBox(width: 6),
                  IconButton(
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
