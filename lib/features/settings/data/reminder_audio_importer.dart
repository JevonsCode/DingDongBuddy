import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:dingdong/features/settings/domain/reminder_profile.dart';

/// Copies short PCM WAV audio into app-owned storage; never executes a path.
final class ReminderAudioImporter {
  ReminderAudioImporter(this.directory);
  final Directory directory;
  Future<ReminderAudio> import(String path, String name) async {
    if (name.trim().isEmpty || name.length > 64) {
      throw const FormatException('Sound name must contain 1–64 characters.');
    }
    final file = File(path);
    if (!file.isAbsolute || !await file.exists()) {
      throw const FormatException(
        'Provide an existing absolute local WAV file path.',
      );
    }
    if (await file.length() > 5 * 1024 * 1024) {
      throw const FormatException('Sound must be at most 5 MiB.');
    }
    final bytes = await file.readAsBytes();
    validateWave(bytes);
    await directory.create(recursive: true);
    final digest = (await Sha256().hash(
      bytes,
    )).bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    final target = File('${directory.path}/$digest.wav');
    if (!await target.exists()) await target.writeAsBytes(bytes, flush: true);
    return ReminderAudio(name: name.trim(), path: target.path);
  }
}

void validateWave(Uint8List bytes) {
  bool tag(int at, String value) =>
      at + 4 <= bytes.length &&
      String.fromCharCodes(bytes.sublist(at, at + 4)) == value;
  if (bytes.length < 44 || !tag(0, 'RIFF') || !tag(8, 'WAVE')) {
    throw const FormatException('Only PCM WAV audio is supported.');
  }
  final data = ByteData.sublistView(bytes);
  int? bytesPerSecond;
  int? audioBytes;
  for (int at = 12; at + 8 <= bytes.length;) {
    final size = data.getUint32(at + 4, Endian.little);
    if (at + 8 + size > bytes.length) {
      throw const FormatException('Incomplete WAV file.');
    }
    if (tag(at, 'fmt ') && size >= 16) {
      final channels = data.getUint16(at + 10, Endian.little);
      final rate = data.getUint32(at + 12, Endian.little);
      final bits = data.getUint16(at + 22, Endian.little);
      final blockAlign = data.getUint16(at + 20, Endian.little);
      bytesPerSecond = data.getUint32(at + 16, Endian.little);
      if (data.getUint16(at + 8, Endian.little) != 1 ||
          channels < 1 ||
          channels > 2 ||
          ![8, 16, 24, 32].contains(bits) ||
          rate < 8000 ||
          rate > 192000 ||
          blockAlign != channels * bits ~/ 8 ||
          bytesPerSecond != rate * blockAlign) {
        throw const FormatException('Use mono/stereo PCM WAV audio.');
      }
    }
    if (tag(at, 'data')) audioBytes = size;
    at += 8 + size + size % 2;
  }
  if (bytesPerSecond == null ||
      audioBytes == null ||
      audioBytes == 0 ||
      audioBytes > bytesPerSecond * 15) {
    throw const FormatException(
      'Sound must contain audio lasting at most 15 seconds.',
    );
  }
}
