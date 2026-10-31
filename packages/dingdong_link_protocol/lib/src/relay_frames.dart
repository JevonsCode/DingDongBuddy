import 'dart:convert';

/// The relay closes any frame above this many UTF-8 bytes
/// (device_link_relay/src/worker.js `maximumFrameBytes`).
const int deviceLinkMaximumRelayFrameBytes = 256 * 1024;

final class DeviceLinkFrameTooLargeException implements Exception {
  const DeviceLinkFrameTooLargeException({
    required this.frameType,
    required this.actualBytes,
    required this.maximumBytes,
  });

  final String frameType;
  final int actualBytes;
  final int maximumBytes;

  @override
  String toString() =>
      'DeviceLinkFrameTooLargeException: encrypted $frameType frame is '
      '$actualBytes bytes; maximum is $maximumBytes bytes.';
}

/// Encodes the exact text frame sent to the relay and enforces the relay's
/// UTF-8 byte limit. String length is not sufficient because non-ASCII text
/// may occupy multiple bytes on the wire.
String encodeDeviceLinkRelayFrame({
  required String type,
  required String envelope,
  int maximumBytes = deviceLinkMaximumRelayFrameBytes,
}) {
  final String frame = jsonEncode(<String, Object?>{
    'type': type,
    'payload': envelope,
  });
  final int actualBytes = utf8.encode(frame).length;
  if (actualBytes > maximumBytes) {
    throw DeviceLinkFrameTooLargeException(
      frameType: type,
      actualBytes: actualBytes,
      maximumBytes: maximumBytes,
    );
  }
  return frame;
}

/// The relay keeps one socket per side and closes the older one with this
/// code and reason. Reconnecting after it would start a replacement loop.
bool deviceLinkConnectionWasReplaced(int? closeCode, String? closeReason) {
  return closeCode == 1008 &&
      closeReason?.toLowerCase() ==
          'Replaced by a newer connection'.toLowerCase();
}

/// WebSocket URL for one side (`host` or `peer`) of a relay room.
Uri deviceLinkRelaySocketUri(Uri relayUrl, String room, String side) {
  final String basePath = relayUrl.path == '/' ? '' : relayUrl.path;
  return relayUrl.replace(
    scheme: switch (relayUrl.scheme) {
      'https' => 'wss',
      'http' => 'ws',
      _ => relayUrl.scheme,
    },
    path: '$basePath/v1/rooms/${Uri.encodeComponent(room)}',
    queryParameters: <String, String>{'side': side},
    fragment: '',
  );
}
