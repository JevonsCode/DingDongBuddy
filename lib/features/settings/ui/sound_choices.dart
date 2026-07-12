/// A settings choice; legacy API-only sounds remain parseable elsewhere.
final class SoundChoice {
  const SoundChoice(this.value, this.englishLabel, this.chineseLabel);

  final String value;
  final String englishLabel;
  final String chineseLabel;
}

const List<SoundChoice> soundChoices = <SoundChoice>[
  SoundChoice('default', 'DingDong Classic', '经典叮咚'),
  SoundChoice('dingSoft', 'DingDong Soft', '轻柔叮咚'),
  SoundChoice('dingBright', 'DingDong Bright', '清亮叮咚'),
  SoundChoice('dingCrisp', 'DingDong Crisp', '清脆叮咚'),
  SoundChoice('dingDeep', 'DingDong Deep', '低沉叮咚'),
  SoundChoice('custom', 'Custom sound', '自定义声音'),
  SoundChoice('system', 'System sound', '系统声音'),
  SoundChoice('muted', 'Muted', '静音'),
];
