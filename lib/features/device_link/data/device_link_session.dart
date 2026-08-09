import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/device_link/data/secure_message_codec.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

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

sealed class DeviceLinkSessionEvent {
  const DeviceLinkSessionEvent();
}

final class DeviceLinkStatusEvent extends DeviceLinkSessionEvent {
  const DeviceLinkStatusEvent(this.status, {this.error});

  final DeviceConnectionStatus status;
  final Object? error;
}

final class DeviceLinkMessageEvent extends DeviceLinkSessionEvent {
  const DeviceLinkMessageEvent(this.message);

  final Map<String, Object?> message;
}

abstract interface class DeviceLinkSessionHandle {
  Stream<DeviceLinkSessionEvent> get events;

  bool get connected;

  Future<void> connect();

  Future<void> send(Map<String, Object?> message);

  Future<void> close();
}

typedef DeviceLinkSessionFactory =
    DeviceLinkSessionHandle Function({
      required Uri relayUrl,
      required String room,
      required String secret,
    });

bool deviceLinkConnectionWasReplaced(int? closeCode, String? closeReason) {
  return closeCode == 1008 &&
      closeReason?.toLowerCase() ==
          'Replaced by a newer connection'.toLowerCase();
}

DeviceLinkSessionHandle createDeviceLinkSession({
  required Uri relayUrl,
  required String room,
  required String secret,
}) {
  return WebRtcDeviceLinkSession(
    relayUrl: relayUrl,
    room: room,
    secret: secret,
  );
}

/// macOS/Windows offerer for one trusted PWA or desktop peer.
final class WebRtcDeviceLinkSession implements DeviceLinkSessionHandle {
  WebRtcDeviceLinkSession({
    required this.relayUrl,
    required this.room,
    required String secret,
  }) : _codec = SecureMessageCodec.fromBase64Url(secret);

  final Uri relayUrl;
  final String room;
  final SecureMessageCodec _codec;
  final StreamController<DeviceLinkSessionEvent> _events =
      StreamController<DeviceLinkSessionEvent>.broadcast();
  final List<RTCIceCandidate> _pendingRemoteCandidates = <RTCIceCandidate>[];

  WebSocket? _socket;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  Timer? _reconnectTimer;
  bool _closed = false;
  bool _connecting = false;
  bool _makingOffer = false;
  bool _relayPeerPresent = false;
  int _reconnectAttempt = 0;
  Future<void> _relayMessages = Future<void>.value();
  Future<void> _incomingMessages = Future<void>.value();

  @override
  Stream<DeviceLinkSessionEvent> get events => _events.stream;

  @override
  bool get connected => _dataChannelConnected || _relayConnected;

  bool get _dataChannelConnected =>
      _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;

  bool get _relayConnected =>
      _relayPeerPresent && _socket?.readyState == WebSocket.open;

  @override
  Future<void> connect() async {
    if (_closed || _connecting || _socket != null) return;
    _connecting = true;
    _events.add(const DeviceLinkStatusEvent(DeviceConnectionStatus.connecting));
    try {
      final WebSocket socket = await WebSocket.connect(
        _relaySocketUri(relayUrl, room).toString(),
      );
      if (_closed) {
        await socket.close();
        return;
      }
      _socket = socket;
      socket.pingInterval = const Duration(seconds: 20);
      socket.listen(
        (Object? data) {
          if (data is String) {
            _relayMessages = _relayMessages.then(
              (_) => _handleRelayMessage(data),
            );
          }
        },
        onError: _handleSocketError,
        onDone: () => _handleSocketDone(socket),
        cancelOnError: false,
      );
    } on Object catch (error) {
      _events.add(
        DeviceLinkStatusEvent(DeviceConnectionStatus.error, error: error),
      );
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  Future<void> _handleRelayMessage(String raw) async {
    try {
      final int rawBytes = utf8.encode(raw).length;
      if (rawBytes > deviceLinkMaximumRelayFrameBytes) {
        throw DeviceLinkFrameTooLargeException(
          frameType: 'incoming relay',
          actualBytes: rawBytes,
          maximumBytes: deviceLinkMaximumRelayFrameBytes,
        );
      }
      final Map<String, Object?> frame = Map<String, Object?>.from(
        jsonDecode(raw) as Map,
      );
      if (frame['type'] == 'relay') {
        final String? event = frame['event'] as String?;
        if (event == 'peer_joined') {
          _relayPeerPresent = true;
          _reconnectAttempt = 0;
          _events.add(
            const DeviceLinkStatusEvent(DeviceConnectionStatus.connected),
          );
          await _makeOffer();
        } else if (event == 'peer_left') {
          _relayPeerPresent = false;
          await _resetPeer();
          _events.add(
            const DeviceLinkStatusEvent(DeviceConnectionStatus.disconnected),
          );
        }
        return;
      }
      if (frame['type'] == 'data' && frame['payload'] is String) {
        _queueIncomingEnvelope(frame['payload']! as String);
        return;
      }
      if (frame['type'] != 'signal' || frame['payload'] is! String) return;
      final Map<String, Object?> message = await _codec.open(
        frame['payload']! as String,
      );
      switch (message['type']) {
        case 'answer':
          final RTCPeerConnection? peer = _peerConnection;
          if (peer == null) return;
          await peer.setRemoteDescription(
            RTCSessionDescription(
              message['sdp']! as String,
              message['sdpType'] as String? ?? 'answer',
            ),
          );
          for (final RTCIceCandidate candidate in List<RTCIceCandidate>.of(
            _pendingRemoteCandidates,
          )) {
            await peer.addCandidate(candidate);
          }
          _pendingRemoteCandidates.clear();
        case 'candidate':
          final RTCIceCandidate candidate = RTCIceCandidate(
            message['candidate'] as String?,
            message['sdpMid'] as String?,
            (message['sdpMLineIndex'] as num?)?.toInt(),
          );
          final RTCPeerConnection? peer = _peerConnection;
          final RTCSessionDescription? remote = await peer
              ?.getRemoteDescription();
          if (peer == null || remote == null) {
            _pendingRemoteCandidates.add(candidate);
          } else {
            await peer.addCandidate(candidate);
          }
      }
    } on Object catch (error) {
      _events.add(
        DeviceLinkStatusEvent(DeviceConnectionStatus.error, error: error),
      );
    }
  }

  Future<void> _makeOffer() async {
    if (_closed || _makingOffer) return;
    _makingOffer = true;
    try {
      await _resetPeer();
      final RTCPeerConnection peer = await createPeerConnection(
        <String, Object?>{'iceServers': const <Object?>[]},
      );
      _peerConnection = peer;
      peer.onIceCandidate = (RTCIceCandidate candidate) {
        if ((candidate.candidate ?? '').isEmpty) return;
        unawaited(
          _sendSignal(<String, Object?>{
            'type': 'candidate',
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }),
        );
      };
      peer.onConnectionState = (RTCPeerConnectionState state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          if (!_relayConnected) {
            _events.add(
              const DeviceLinkStatusEvent(DeviceConnectionStatus.disconnected),
            );
          }
        }
      };
      final RTCDataChannel channel = await peer.createDataChannel(
        'dingdong-v1',
        RTCDataChannelInit()
          ..ordered = true
          ..id = 1,
      );
      _attachDataChannel(channel);
      final RTCSessionDescription offer = await peer.createOffer(
        <String, Object?>{},
      );
      await peer.setLocalDescription(offer);
      await _sendSignal(<String, Object?>{
        'type': 'offer',
        'sdp': offer.sdp,
        'sdpType': offer.type ?? 'offer',
      });
    } finally {
      _makingOffer = false;
    }
  }

  void _attachDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;
    channel.onDataChannelState = (RTCDataChannelState state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _reconnectAttempt = 0;
        _events.add(
          const DeviceLinkStatusEvent(DeviceConnectionStatus.connected),
        );
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        if (!_relayConnected) {
          _events.add(
            const DeviceLinkStatusEvent(DeviceConnectionStatus.disconnected),
          );
        }
      }
    };
    channel.onMessage = (RTCDataChannelMessage data) {
      if (data.isBinary) return;
      _queueIncomingEnvelope(data.text);
    };
  }

  void _queueIncomingEnvelope(String envelope) {
    try {
      // Validate the relay representation even when this instance arrived over
      // WebRTC, so a message accepted on the direct path is always safe to send
      // through the fallback path as well.
      encodeDeviceLinkRelayFrame(type: 'data', envelope: envelope);
    } on DeviceLinkFrameTooLargeException catch (error) {
      _events.add(
        DeviceLinkStatusEvent(DeviceConnectionStatus.error, error: error),
      );
      return;
    }
    _incomingMessages = _incomingMessages.then((_) async {
      try {
        _events.add(DeviceLinkMessageEvent(await _codec.open(envelope)));
      } on Object catch (error) {
        _events.add(
          DeviceLinkStatusEvent(DeviceConnectionStatus.error, error: error),
        );
      }
    });
  }

  Future<void> _sendSignal(Map<String, Object?> signal) async {
    final WebSocket? socket = _socket;
    if (socket == null) return;
    final String envelope = await _codec.seal(signal);
    socket.add(encodeDeviceLinkRelayFrame(type: 'signal', envelope: envelope));
  }

  @override
  Future<void> send(Map<String, Object?> message) async {
    final RTCDataChannel? channel = _dataChannel;
    final String envelope = await _codec.seal(message);
    final String relayFrame = encodeDeviceLinkRelayFrame(
      type: 'data',
      envelope: envelope,
    );
    if (channel != null && _dataChannelConnected) {
      await channel.send(RTCDataChannelMessage(envelope));
      return;
    }
    final WebSocket? socket = _socket;
    if (socket != null && _relayConnected) {
      socket.add(relayFrame);
      return;
    }
    throw StateError('The device is not connected.');
  }

  void _handleSocketError(Object error) {
    if (!_dataChannelConnected) {
      _events.add(
        DeviceLinkStatusEvent(DeviceConnectionStatus.error, error: error),
      );
    }
  }

  void _handleSocketDone(WebSocket socket) {
    if (!identical(_socket, socket)) return;
    final bool replaced = deviceLinkConnectionWasReplaced(
      socket.closeCode,
      socket.closeReason,
    );
    _socket = null;
    _relayPeerPresent = false;
    if (_closed) return;
    if (!_dataChannelConnected) {
      _events.add(
        const DeviceLinkStatusEvent(DeviceConnectionStatus.disconnected),
      );
    }
    if (!replaced) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closed || _reconnectTimer != null) return;
    final int seconds = <int>[
      1,
      2,
      4,
      8,
      15,
      30,
    ][_reconnectAttempt.clamp(0, 5)];
    _reconnectAttempt += 1;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      unawaited(connect());
    });
  }

  Future<void> _resetPeer() async {
    final RTCDataChannel? channel = _dataChannel;
    final RTCPeerConnection? peer = _peerConnection;
    _dataChannel = null;
    _peerConnection = null;
    _pendingRemoteCandidates.clear();
    await channel?.close();
    await peer?.close();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _relayPeerPresent = false;
    await _resetPeer();
    final WebSocket? socket = _socket;
    _socket = null;
    await socket?.close();
    await _events.close();
  }
}

Uri _relaySocketUri(Uri relayUrl, String room) {
  final String basePath = relayUrl.path == '/' ? '' : relayUrl.path;
  return relayUrl.replace(
    scheme: switch (relayUrl.scheme) {
      'https' => 'wss',
      'http' => 'ws',
      _ => relayUrl.scheme,
    },
    path: '$basePath/v1/rooms/${Uri.encodeComponent(room)}',
    queryParameters: const <String, String>{'side': 'host'},
    fragment: '',
  );
}
