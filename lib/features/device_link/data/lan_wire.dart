import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Bounded newline frames. One iterator survives the authentication handoff.
final class LanWire {
  LanWire(this.socket) {
    socket.setOption(SocketOption.tcpNoDelay, true);
    // IP_TTL: one hop for authenticated traffic as well as discovery. Linux
    // defines this option as 2; Winsock and Darwin define it as 4.
    socket.setRawOption(
      RawSocketOption.fromInt(
        RawSocketOption.levelIPv4,
        Platform.isLinux ? 2 : 4,
        1,
      ),
    );
    frames = StreamIterator(_frames());
  }
  final Socket socket;
  late final StreamIterator<Map<String, Object?>> frames;
  static const maximumFrameBytes = 256 * 1024;

  Stream<Map<String, Object?>> _frames() async* {
    var pending = <int>[];
    await for (final chunk in socket) {
      for (final byte in chunk) {
        if (byte == 10) {
          yield Map<String, Object?>.from(
            jsonDecode(utf8.decode(pending)) as Map,
          );
          pending = <int>[];
        } else {
          pending.add(byte);
          if (pending.length > maximumFrameBytes) {
            throw const FormatException('LAN frame too large');
          }
        }
      }
    }
  }

  Future<Map<String, Object?>> read() async {
    if (!await frames.moveNext().timeout(const Duration(seconds: 12))) {
      throw const SocketException('LAN connection closed');
    }
    return frames.current;
  }

  Future<void> write(Map<String, Object?> value) async {
    final bytes = utf8.encode(jsonEncode(value));
    if (bytes.length > maximumFrameBytes) {
      throw const FormatException('LAN frame too large');
    }
    socket.add([...bytes, 10]);
    await socket.flush().timeout(const Duration(seconds: 12));
  }

  void close() {
    socket.destroy();
    unawaited(frames.cancel());
  }
}
