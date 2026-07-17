import 'dart:convert';

/// Sound values retained for compatibility with existing API clients.
enum DingSound {
  defaultSound('default'),
  dingSoft('dingSoft'),
  dingBright('dingBright'),
  dingCrisp('dingCrisp'),
  dingWood('dingWood'),
  dingDeep('dingDeep'),
  joy('joy'),
  levelUp('levelUp'),
  taDa('taDa'),
  bubble('bubble'),
  coin('coin'),
  fanfare('fanfare'),
  arcade('arcade'),
  bloom('bloom'),
  sunrise('sunrise'),
  popcorn('popcorn'),
  glimmer('glimmer'),
  rocket('rocket'),
  confetti('confetti'),
  marimba('marimba'),
  candy('candy'),
  sparkle('sparkle'),
  success('success'),
  celebrate('celebrate'),
  random('random'),
  custom('custom'),
  system('system'),
  muted('muted');

  const DingSound(this.apiValue);

  final String apiValue;

  static DingSound parse(Object? value) {
    if (value == null) {
      return DingSound.defaultSound;
    }
    return values.firstWhere(
      (DingSound sound) => sound.apiValue == value,
      orElse: () => throw FormatException('Unknown sound: $value'),
    );
  }
}

/// Parsed notification request delivered to the platform coordinator.
final class DingRequest {
  const DingRequest({
    this.message = 'Task complete',
    this.source,
    this.sound = DingSound.defaultSound,
    this.flashCount = 8,
    this.fallback = false,
  });

  factory DingRequest.parse(String body) {
    if (body.isEmpty) {
      return const DingRequest();
    }
    final Map<String, Object?> json = jsonDecode(body) as Map<String, Object?>;
    final String message =
        _trimmedOrNull(json['message'] as String?) ?? 'Task complete';
    final int requestedFlashCount = json['flashCount'] as int? ?? 8;
    return DingRequest(
      message: message,
      source: _trimmedOrNull(json['source'] as String?),
      sound: DingSound.parse(json['sound']),
      flashCount: requestedFlashCount.clamp(2, 30),
      fallback: json['fallback'] == true,
    );
  }

  final String message;
  final String? source;
  final DingSound sound;
  final int flashCount;
  final bool fallback;

  DingRequest copyWith({DingSound? sound}) {
    return DingRequest(
      message: message,
      source: source,
      sound: sound ?? this.sound,
      flashCount: flashCount,
      fallback: fallback,
    );
  }
}

String? _trimmedOrNull(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
