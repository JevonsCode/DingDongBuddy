/// DingDong device-link wire format: relay frames, AES-GCM envelopes and the
/// pairing QR payload. Pure Dart so the desktop app and the Android companion
/// share one implementation.
library;

export 'src/pairing_payload.dart';
export 'src/relay_frames.dart';
export 'src/secure_message_codec.dart';
