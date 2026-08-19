/// Sounds exposed by the current desktop settings surface.
final class SoundChoice {
  const SoundChoice(this.value);

  final String value;
}

const List<SoundChoice> soundChoices = <SoundChoice>[
  SoundChoice('default'),
  SoundChoice('dingSoft'),
  SoundChoice('dingBright'),
  SoundChoice('dingCrisp'),
  SoundChoice('dingDeep'),
  SoundChoice('custom'),
  SoundChoice('system'),
  SoundChoice('muted'),
];
