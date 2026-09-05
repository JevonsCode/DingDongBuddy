import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/device_link/data/secure_message_codec.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_webrtc/flutter_webrtc.dart';

const int deviceLinkMaximumRelayFrameBytes = 256 * 1024;
const int deviceLinkMaximumDataChannelBufferedBytes = 1024 * 1024;
const Duration deviceLinkDataChannelBackpressureTimeout = Duration(seconds: 15);
const Duration deviceLinkDataChannelBackpressurePollInterval = Duration(
  milliseconds: 12,
);

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

final class DeviceLinkTransportEvent extends DeviceLinkSessionEvent {
  const DeviceLinkTransportEvent(this.transport);

  final DeviceLinkActiveTransport transport;
}

/// Reports that the encrypted signalling room has (or has lost) its other
/// endpoint. This is intentionally separate from content connectivity: LAN
/// mode may need the relay control plane to reconcile settings before a direct
/// data channel is available.
final class DeviceLinkPeerPresenceEvent extends DeviceLinkSessionEvent {
  const DeviceLinkPeerPresenceEvent(this.present);

  final bool present;
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

/// Optional route policy supported by the production WebRTC session. Keeping
/// this separate means small test doubles do not need transport internals.
abstract interface class ConfigurableDeviceLinkSessionHandle {
  DeviceLinkTransportPreference get transportPreference;

  set transportPreference(DeviceLinkTransportPreference value);

  DeviceLinkActiveTransport get activeTransport;

  void updateTransportPreference(DeviceLinkTransportPreference value);
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

DeviceLinkSessionHandle createPeerDeviceLinkSession({
  required Uri relayUrl,
  required String room,
  required String secret,
}) {
  return WebRtcDeviceLinkSession(
    relayUrl: relayUrl,
    room: room,
    secret: secret,
    side: DeviceLinkConnectionSide.peer,
  );
}

/// macOS/Windows offerer for one trusted PWA or desktop peer.
final class WebRtcDeviceLinkSession
    implements DeviceLinkSessionHandle, ConfigurableDeviceLinkSessionHandle {
  WebRtcDeviceLinkSession({
    required this.relayUrl,
    required this.room,
    required String secret,
    this.side = DeviceLinkConnectionSide.host,
    this.transportPreference = DeviceLinkTransportPreference.automatic,
  }) : _codec = SecureMessageCodec.fromBase64Url(secret);

  @visibleForTesting
  WebRtcDeviceLinkSession.forTesting({
    required this.relayUrl,
    required this.room,
    required String secret,
    required RTCDataChannel dataChannel,
    this.side = DeviceLinkConnectionSide.host,
    this.transportPreference = DeviceLinkTransportPreference.automatic,
  }) : _codec = SecureMessageCodec.fromBase64Url(secret) {
    _dataChannel = dataChannel;
  }

  final Uri relayUrl;
  final String room;
  final DeviceLinkConnectionSide side;
  final SecureMessageCodec _codec;
  final StreamController<DeviceLinkSessionEvent> _events =
      StreamController<DeviceLinkSessionEvent>.broadcast();
  final List<RTCIceCandidate> _pendingRemoteCandidates = <RTCIceCandidate>[];
  final Queue<
    ({String envelope, bool fromRelay, Object source, int generation})
  >
  _incomingEnvelopes =
      Queue<
        ({String envelope, bool fromRelay, Object source, int generation})
      >();

  WebSocket? _socket;
  StreamSubscription<Object?>? _socketSubscription;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  Timer? _reconnectTimer;
  bool _closed = false;
  bool _connecting = false;
  bool _makingOffer = false;
  bool _relayPeerPresent = false;
  bool _drainingIncomingEnvelopes = false;
  bool _directSendUnavailable = false;
  int _reconnectAttempt = 0;
  int _relayGeneration = 0;
  int _peerGeneration = 0;
  WebSocket? _peerSignallingSocket;
  int _peerRelayGeneration = -1;
  @override
  DeviceLinkTransportPreference transportPreference;

  @override
  void updateTransportPreference(DeviceLinkTransportPreference value) {
    if (transportPreference == value) return;
    transportPreference = value;
    _refreshConnectionState();
    if (value == DeviceLinkTransportPreference.serviceRelay) {
      unawaited(_resetPeer());
    } else if (side == DeviceLinkConnectionSide.host &&
        _relayPeerPresent &&
        !_dataChannelConnected) {
      unawaited(_makeOffer());
    }
  }

  DeviceLinkActiveTransport _activeTransport = DeviceLinkActiveTransport.none;
  DeviceConnectionStatus? _lastStatus;
  Future<void> _incomingDrain = Future<void>.value();

  static const int _maximumQueuedIncomingEnvelopes = 16;

  @override
  Stream<DeviceLinkSessionEvent> get events => _events.stream;

  @override
  bool get connected => activeTransport != DeviceLinkActiveTransport.none;

  @override
  DeviceLinkActiveTransport get activeTransport {
    if (transportPreference != DeviceLinkTransportPreference.serviceRelay &&
        _dataChannelConnected) {
      return DeviceLinkActiveTransport.localNetwork;
    }
    if (transportPreference != DeviceLinkTransportPreference.localNetwork &&
        _relayConnected) {
      return DeviceLinkActiveTransport.serviceRelay;
    }
    return DeviceLinkActiveTransport.none;
  }

  bool get _dataChannelConnected =>
      !_directSendUnavailable &&
      _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;

  bool get _relayConnected =>
      _relayPeerPresent && _socket?.readyState == WebSocket.open;

  @override
  Future<void> connect() async {
    if (_closed || _connecting || _socket != null) return;
    _connecting = true;
    _emitStatus(DeviceConnectionStatus.connecting);
    try {
      final WebSocket socket = await WebSocket.connect(
        _relaySocketUri(relayUrl, room, side).toString(),
      );
      if (_closed) {
        await socket.close();
        return;
      }
      _socket = socket;
      final int relayGeneration = ++_relayGeneration;
      socket.pingInterval = const Duration(seconds: 20);
      late final StreamSubscription<Object?> subscription;
      subscription = socket
          .asyncMap<void>((Object? data) async {
            if (data is String && _socketIsCurrent(socket, relayGeneration)) {
              await _handleRelayMessage(socket, relayGeneration, data);
            }
          })
          .listen(
            null,
            onError: (Object error) =>
                _handleSocketError(socket, relayGeneration, error),
            onDone: () {
              if (identical(_socketSubscription, subscription)) {
                _socketSubscription = null;
              }
              _handleSocketDone(socket, relayGeneration);
            },
            cancelOnError: false,
          );
      _socketSubscription = subscription;
    } on Object catch (error) {
      if (_closed) return;
      _emitStatus(DeviceConnectionStatus.error, error: error);
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  Future<void> _handleRelayMessage(
    WebSocket source,
    int relayGeneration,
    String raw,
  ) async {
    if (!_socketIsCurrent(source, relayGeneration)) return;
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
      if (!_socketIsCurrent(source, relayGeneration)) return;
      if (frame['type'] == 'relay') {
        final String? event = frame['event'] as String?;
        final String joinedEvent = side == DeviceLinkConnectionSide.host
            ? 'peer_joined'
            : 'host_joined';
        final String leftEvent = side == DeviceLinkConnectionSide.host
            ? 'peer_left'
            : 'host_left';
        if (event == joinedEvent) {
          _relayPeerPresent = true;
          _reconnectAttempt = 0;
          _refreshConnectionState();
          _events.add(const DeviceLinkPeerPresenceEvent(true));
          if (side == DeviceLinkConnectionSide.host &&
              transportPreference !=
                  DeviceLinkTransportPreference.serviceRelay) {
            await _makeOffer(
              expectedSocket: source,
              expectedRelayGeneration: relayGeneration,
            );
          }
        } else if (event == leftEvent) {
          _relayPeerPresent = false;
          await _resetPeer();
          if (!_socketIsCurrent(source, relayGeneration)) return;
          _refreshConnectionState();
          _events.add(const DeviceLinkPeerPresenceEvent(false));
        }
        return;
      }
      if (frame['type'] == 'data' && frame['payload'] is String) {
        _queueIncomingEnvelope(
          frame['payload']! as String,
          fromRelay: true,
          source: source,
          generation: relayGeneration,
        );
        return;
      }
      if (frame['type'] != 'signal' || frame['payload'] is! String) return;
      final Map<String, Object?> message = await _codec.open(
        frame['payload']! as String,
      );
      if (!_socketIsCurrent(source, relayGeneration)) return;
      switch (message['type']) {
        case 'offer':
          if (side == DeviceLinkConnectionSide.peer &&
              transportPreference !=
                  DeviceLinkTransportPreference.serviceRelay) {
            await _acceptOffer(
              message,
              source: source,
              relayGeneration: relayGeneration,
            );
          }
        case 'answer':
          if (side != DeviceLinkConnectionSide.host) return;
          final RTCPeerConnection? peer = _peerConnection;
          final int peerGeneration = _peerGeneration;
          if (peer == null ||
              !_peerContextIsCurrent(
                peer,
                peerGeneration,
                source,
                relayGeneration,
              )) {
            return;
          }
          await peer.setRemoteDescription(
            RTCSessionDescription(
              message['sdp']! as String,
              message['sdpType'] as String? ?? 'answer',
            ),
          );
          if (!_peerContextIsCurrent(
            peer,
            peerGeneration,
            source,
            relayGeneration,
          )) {
            return;
          }
          for (final RTCIceCandidate candidate in List<RTCIceCandidate>.of(
            _pendingRemoteCandidates,
          )) {
            await peer.addCandidate(candidate);
            if (!_peerContextIsCurrent(
              peer,
              peerGeneration,
              source,
              relayGeneration,
            )) {
              return;
            }
          }
          _pendingRemoteCandidates.clear();
        case 'candidate':
          final RTCIceCandidate candidate = RTCIceCandidate(
            message['candidate'] as String?,
            message['sdpMid'] as String?,
            (message['sdpMLineIndex'] as num?)?.toInt(),
          );
          final RTCPeerConnection? peer = _peerConnection;
          final int peerGeneration = _peerGeneration;
          final RTCSessionDescription? remote = await peer
              ?.getRemoteDescription();
          if (peer != null &&
              !_peerContextIsCurrent(
                peer,
                peerGeneration,
                source,
                relayGeneration,
              )) {
            return;
          }
          if (peer == null || remote == null) {
            _pendingRemoteCandidates.add(candidate);
          } else {
            await peer.addCandidate(candidate);
          }
      }
    } on Object catch (error) {
      _emitStatus(DeviceConnectionStatus.error, error: error);
    }
  }

  Future<void> _makeOffer({
    WebSocket? expectedSocket,
    int? expectedRelayGeneration,
  }) async {
    if (_closed ||
        _makingOffer ||
        side != DeviceLinkConnectionSide.host ||
        transportPreference == DeviceLinkTransportPreference.serviceRelay) {
      return;
    }
    final WebSocket? signallingSocket = expectedSocket ?? _socket;
    final int relayGeneration = expectedRelayGeneration ?? _relayGeneration;
    if (signallingSocket == null ||
        !_socketIsCurrent(signallingSocket, relayGeneration)) {
      return;
    }
    _makingOffer = true;
    try {
      await _resetPeer();
      if (_closed ||
          !_relayPeerPresent ||
          !_socketIsCurrent(signallingSocket, relayGeneration)) {
        return;
      }
      final int peerGeneration = _peerGeneration;
      final RTCPeerConnection? peer = await _createPeerConnection(
        expectedPeerGeneration: peerGeneration,
        signallingSocket: signallingSocket,
        relayGeneration: relayGeneration,
      );
      if (peer == null) return;
      final RTCDataChannel channel = await peer.createDataChannel(
        'dingdong-v1',
        RTCDataChannelInit()
          ..ordered = true
          ..id = 1,
      );
      if (!_peerContextIsCurrent(
        peer,
        peerGeneration,
        signallingSocket,
        relayGeneration,
      )) {
        await channel.close();
        return;
      }
      _attachDataChannel(channel, peer, peerGeneration);
      final RTCSessionDescription offer = await peer.createOffer(
        <String, Object?>{},
      );
      if (!_peerContextIsCurrent(
        peer,
        peerGeneration,
        signallingSocket,
        relayGeneration,
      )) {
        return;
      }
      await peer.setLocalDescription(offer);
      if (!_peerContextIsCurrent(
        peer,
        peerGeneration,
        signallingSocket,
        relayGeneration,
      )) {
        return;
      }
      await _sendSignal(
        <String, Object?>{
          'type': 'offer',
          'sdp': offer.sdp,
          'sdpType': offer.type ?? 'offer',
        },
        expectedSocket: signallingSocket,
        expectedRelayGeneration: relayGeneration,
        expectedPeer: peer,
        expectedPeerGeneration: peerGeneration,
      );
    } finally {
      _makingOffer = false;
    }
  }

  Future<void> _acceptOffer(
    Map<String, Object?> message, {
    required WebSocket source,
    required int relayGeneration,
  }) async {
    // ICE callbacks may overtake the offer on the signalling socket. Preserve
    // candidates received before resetting an older peer connection.
    final List<RTCIceCandidate> earlyCandidates = List<RTCIceCandidate>.of(
      _pendingRemoteCandidates,
    );
    await _resetPeer();
    if (_closed || !_socketIsCurrent(source, relayGeneration)) return;
    final int peerGeneration = _peerGeneration;
    final RTCPeerConnection? peer = await _createPeerConnection(
      expectedPeerGeneration: peerGeneration,
      signallingSocket: source,
      relayGeneration: relayGeneration,
      receiveDataChannel: true,
    );
    if (peer == null) return;
    await peer.setRemoteDescription(
      RTCSessionDescription(
        message['sdp']! as String,
        message['sdpType'] as String? ?? 'offer',
      ),
    );
    if (!_peerContextIsCurrent(peer, peerGeneration, source, relayGeneration)) {
      return;
    }
    final List<RTCIceCandidate> candidates = <RTCIceCandidate>[
      ...earlyCandidates,
      ..._pendingRemoteCandidates,
    ];
    _pendingRemoteCandidates.clear();
    for (final RTCIceCandidate candidate in candidates) {
      await peer.addCandidate(candidate);
      if (!_peerContextIsCurrent(
        peer,
        peerGeneration,
        source,
        relayGeneration,
      )) {
        return;
      }
    }
    final RTCSessionDescription answer = await peer.createAnswer(
      <String, Object?>{},
    );
    if (!_peerContextIsCurrent(peer, peerGeneration, source, relayGeneration)) {
      return;
    }
    await peer.setLocalDescription(answer);
    if (!_peerContextIsCurrent(peer, peerGeneration, source, relayGeneration)) {
      return;
    }
    await _sendSignal(
      <String, Object?>{
        'type': 'answer',
        'sdp': answer.sdp,
        'sdpType': answer.type ?? 'answer',
      },
      expectedSocket: source,
      expectedRelayGeneration: relayGeneration,
      expectedPeer: peer,
      expectedPeerGeneration: peerGeneration,
    );
  }

  Future<RTCPeerConnection?> _createPeerConnection({
    required int expectedPeerGeneration,
    required WebSocket signallingSocket,
    required int relayGeneration,
    bool receiveDataChannel = false,
  }) async {
    final RTCPeerConnection peer = await createPeerConnection(<String, Object?>{
      'iceServers': const <Object?>[],
    });
    if (_closed ||
        expectedPeerGeneration != _peerGeneration ||
        !_socketIsCurrent(signallingSocket, relayGeneration)) {
      await peer.close();
      return null;
    }
    _peerConnection = peer;
    _peerSignallingSocket = signallingSocket;
    _peerRelayGeneration = relayGeneration;
    peer.onIceCandidate = (RTCIceCandidate candidate) {
      if ((candidate.candidate ?? '').isEmpty ||
          !_peerContextIsCurrent(
            peer,
            expectedPeerGeneration,
            signallingSocket,
            relayGeneration,
          )) {
        return;
      }
      unawaited(
        _sendSignal(
          <String, Object?>{
            'type': 'candidate',
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
          expectedSocket: signallingSocket,
          expectedRelayGeneration: relayGeneration,
          expectedPeer: peer,
          expectedPeerGeneration: expectedPeerGeneration,
        ),
      );
    };
    peer.onConnectionState = (_) {
      if (_peerContextIsCurrent(
        peer,
        expectedPeerGeneration,
        signallingSocket,
        relayGeneration,
      )) {
        _refreshConnectionState();
      }
    };
    if (receiveDataChannel) {
      peer.onDataChannel = (RTCDataChannel channel) {
        _attachDataChannel(channel, peer, expectedPeerGeneration);
      };
    }
    return peer;
  }

  void _attachDataChannel(
    RTCDataChannel channel,
    RTCPeerConnection peer,
    int peerGeneration,
  ) {
    if (_closed ||
        peerGeneration != _peerGeneration ||
        !identical(_peerConnection, peer)) {
      unawaited(channel.close());
      return;
    }
    final RTCDataChannel? previous = _dataChannel;
    _dataChannel = channel;
    _directSendUnavailable = false;
    if (previous != null && !identical(previous, channel)) {
      unawaited(previous.close());
    }
    channel.onDataChannelState = (RTCDataChannelState state) {
      if (!identical(_peerConnection, peer) ||
          peerGeneration != _peerGeneration ||
          !identical(_dataChannel, channel)) {
        return;
      }
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _reconnectAttempt = 0;
        _directSendUnavailable = false;
      }
      _refreshConnectionState();
    };
    channel.onMessage = (RTCDataChannelMessage data) {
      if (data.isBinary ||
          !identical(_peerConnection, peer) ||
          peerGeneration != _peerGeneration ||
          !identical(_dataChannel, channel)) {
        return;
      }
      _queueIncomingEnvelope(
        data.text,
        fromRelay: false,
        source: channel,
        generation: peerGeneration,
      );
    };
  }

  void _queueIncomingEnvelope(
    String envelope, {
    required bool fromRelay,
    required Object source,
    required int generation,
  }) {
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
    if (_closed ||
        !_incomingContextIsCurrent(
          fromRelay: fromRelay,
          source: source,
          generation: generation,
        )) {
      return;
    }
    if (_incomingEnvelopes.length >= _maximumQueuedIncomingEnvelopes) {
      _events.add(
        DeviceLinkStatusEvent(
          DeviceConnectionStatus.error,
          error: StateError('Incoming device message queue is full.'),
        ),
      );
      return;
    }
    _incomingEnvelopes.addLast((
      envelope: envelope,
      fromRelay: fromRelay,
      source: source,
      generation: generation,
    ));
    if (_drainingIncomingEnvelopes) return;
    _drainingIncomingEnvelopes = true;
    _incomingDrain = _drainIncomingEnvelopes();
  }

  Future<void> _drainIncomingEnvelopes() async {
    try {
      while (!_closed && _incomingEnvelopes.isNotEmpty) {
        final ({String envelope, bool fromRelay, Object source, int generation})
        incoming = _incomingEnvelopes.removeFirst();
        try {
          if (!_incomingContextIsCurrent(
            fromRelay: incoming.fromRelay,
            source: incoming.source,
            generation: incoming.generation,
          )) {
            continue;
          }
          final Map<String, Object?> message = await _codec.open(
            incoming.envelope,
          );
          if (!_incomingContextIsCurrent(
            fromRelay: incoming.fromRelay,
            source: incoming.source,
            generation: incoming.generation,
          )) {
            continue;
          }
          if (incoming.fromRelay &&
              transportPreference ==
                  DeviceLinkTransportPreference.localNetwork &&
              !_isDeviceLinkControlMessage(message)) {
            continue;
          }
          _events.add(DeviceLinkMessageEvent(message));
        } on Object catch (error) {
          _events.add(
            DeviceLinkStatusEvent(DeviceConnectionStatus.error, error: error),
          );
        }
      }
    } finally {
      _drainingIncomingEnvelopes = false;
      if (!_closed && _incomingEnvelopes.isNotEmpty) {
        _drainingIncomingEnvelopes = true;
        _incomingDrain = _drainIncomingEnvelopes();
      }
    }
  }

  Future<void> _sendSignal(
    Map<String, Object?> signal, {
    required WebSocket expectedSocket,
    required int expectedRelayGeneration,
    RTCPeerConnection? expectedPeer,
    int? expectedPeerGeneration,
  }) async {
    if (!_socketIsCurrent(expectedSocket, expectedRelayGeneration) ||
        expectedSocket.readyState != WebSocket.open ||
        (expectedPeer != null &&
            !_peerContextIsCurrent(
              expectedPeer,
              expectedPeerGeneration ?? _peerGeneration,
              expectedSocket,
              expectedRelayGeneration,
            ))) {
      return;
    }
    final String envelope = await _codec.seal(signal);
    if (!_socketIsCurrent(expectedSocket, expectedRelayGeneration) ||
        expectedSocket.readyState != WebSocket.open ||
        (expectedPeer != null &&
            !_peerContextIsCurrent(
              expectedPeer,
              expectedPeerGeneration ?? _peerGeneration,
              expectedSocket,
              expectedRelayGeneration,
            ))) {
      return;
    }
    expectedSocket.add(
      encodeDeviceLinkRelayFrame(type: 'signal', envelope: envelope),
    );
  }

  @override
  Future<void> send(Map<String, Object?> message) async {
    final RTCDataChannel? channel = _dataChannel;
    final int peerGeneration = _peerGeneration;
    final bool hasDirectCandidate =
        channel != null &&
        transportPreference != DeviceLinkTransportPreference.serviceRelay &&
        !_directSendUnavailable &&
        channel.state == RTCDataChannelState.RTCDataChannelOpen;
    final String envelope = await _codec.seal(message);
    final String relayFrame = encodeDeviceLinkRelayFrame(
      type: 'data',
      envelope: envelope,
    );
    final bool controlMessage = _isDeviceLinkControlMessage(message);
    bool attemptedDirectSend = false;
    Object? directSendError;
    if (transportPreference != DeviceLinkTransportPreference.serviceRelay &&
        !_directSendUnavailable &&
        channel != null &&
        identical(_dataChannel, channel) &&
        channel.state == RTCDataChannelState.RTCDataChannelOpen) {
      attemptedDirectSend = true;
      try {
        await _waitForDataChannelBuffer(channel, peerGeneration);
        if (!_dataChannelContextIsCurrent(channel, peerGeneration)) {
          throw StateError('The device connection changed while sending.');
        }
        await channel.send(RTCDataChannelMessage(envelope));
        return;
      } on Object catch (error) {
        directSendError = error;
        if (identical(_dataChannel, channel)) {
          _directSendUnavailable = true;
          _refreshConnectionState();
        }
      }
    }
    if (_isOrderedFileMessage(message) &&
        (directSendError != null ||
            (hasDirectCandidate && !attemptedDirectSend))) {
      throw directSendError ??
          StateError('The device connection changed while sending.');
    }
    final WebSocket? socket = _socket;
    if ((transportPreference != DeviceLinkTransportPreference.localNetwork ||
            controlMessage) &&
        socket != null &&
        _relayConnected) {
      socket.add(relayFrame);
      return;
    }
    if (directSendError != null) throw directSendError;
    throw StateError('The device is not connected.');
  }

  bool _dataChannelContextIsCurrent(
    RTCDataChannel channel,
    int peerGeneration,
  ) =>
      !_closed &&
      transportPreference != DeviceLinkTransportPreference.serviceRelay &&
      !_directSendUnavailable &&
      peerGeneration == _peerGeneration &&
      identical(_dataChannel, channel) &&
      channel.state == RTCDataChannelState.RTCDataChannelOpen;

  Future<void> _waitForDataChannelBuffer(
    RTCDataChannel channel,
    int peerGeneration,
  ) async {
    final Stopwatch elapsed = Stopwatch()..start();
    while (true) {
      if (!_dataChannelContextIsCurrent(channel, peerGeneration)) {
        throw StateError('The device connection changed while sending.');
      }
      final int remainingMilliseconds =
          deviceLinkDataChannelBackpressureTimeout.inMilliseconds -
          elapsed.elapsedMilliseconds;
      if (remainingMilliseconds <= 0) {
        throw TimeoutException('The device data channel stayed backpressured.');
      }
      final int bufferedAmount = await channel.getBufferedAmount().timeout(
        Duration(milliseconds: remainingMilliseconds),
      );
      if (!_dataChannelContextIsCurrent(channel, peerGeneration)) {
        throw StateError('The device connection changed while sending.');
      }
      if (bufferedAmount <= deviceLinkMaximumDataChannelBufferedBytes) return;
      if (elapsed.elapsed >= deviceLinkDataChannelBackpressureTimeout) {
        throw TimeoutException('The device data channel stayed backpressured.');
      }
      final int remainingAfterRead =
          deviceLinkDataChannelBackpressureTimeout.inMilliseconds -
          elapsed.elapsedMilliseconds;
      await Future<void>.delayed(
        Duration(
          milliseconds:
              remainingAfterRead <
                  deviceLinkDataChannelBackpressurePollInterval.inMilliseconds
              ? remainingAfterRead
              : deviceLinkDataChannelBackpressurePollInterval.inMilliseconds,
        ),
      );
    }
  }

  bool _socketIsCurrent(WebSocket socket, int generation) =>
      !_closed && generation == _relayGeneration && identical(_socket, socket);

  bool _peerContextIsCurrent(
    RTCPeerConnection peer,
    int peerGeneration,
    WebSocket signallingSocket,
    int relayGeneration,
  ) =>
      !_closed &&
      peerGeneration == _peerGeneration &&
      identical(_peerConnection, peer) &&
      identical(_peerSignallingSocket, signallingSocket) &&
      _peerRelayGeneration == relayGeneration &&
      _socketIsCurrent(signallingSocket, relayGeneration);

  bool _incomingContextIsCurrent({
    required bool fromRelay,
    required Object source,
    required int generation,
  }) {
    if (fromRelay) {
      return source is WebSocket && _socketIsCurrent(source, generation);
    }
    return source is RTCDataChannel &&
        generation == _peerGeneration &&
        identical(_dataChannel, source);
  }

  void _handleSocketError(WebSocket socket, int relayGeneration, Object error) {
    if (!_socketIsCurrent(socket, relayGeneration)) return;
    if (!_dataChannelConnected) {
      _emitStatus(DeviceConnectionStatus.error, error: error);
    }
  }

  void _handleSocketDone(WebSocket socket, int relayGeneration) {
    if (!_socketIsCurrent(socket, relayGeneration)) return;
    final bool replaced = deviceLinkConnectionWasReplaced(
      socket.closeCode,
      socket.closeReason,
    );
    _socket = null;
    _relayGeneration += 1;
    _relayPeerPresent = false;
    _pendingRemoteCandidates.clear();
    if (_closed) return;
    _refreshConnectionState();
    if (!replaced) _scheduleReconnect();
  }

  void _refreshConnectionState() {
    final DeviceLinkActiveTransport next = activeTransport;
    if (_activeTransport != next) {
      _activeTransport = next;
      _events.add(DeviceLinkTransportEvent(next));
    }
    _emitStatus(
      next == DeviceLinkActiveTransport.none
          ? DeviceConnectionStatus.disconnected
          : DeviceConnectionStatus.connected,
    );
  }

  void _emitStatus(DeviceConnectionStatus status, {Object? error}) {
    if (_lastStatus == status && error == null) return;
    _lastStatus = status;
    _events.add(DeviceLinkStatusEvent(status, error: error));
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
    _peerGeneration += 1;
    final RTCDataChannel? channel = _dataChannel;
    final RTCPeerConnection? peer = _peerConnection;
    _dataChannel = null;
    _peerConnection = null;
    _peerSignallingSocket = null;
    _peerRelayGeneration = -1;
    _directSendUnavailable = false;
    _pendingRemoteCandidates.clear();
    await channel?.close();
    await peer?.close();
    _refreshConnectionState();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _relayPeerPresent = false;
    _incomingEnvelopes.clear();
    await _resetPeer();
    final StreamSubscription<Object?>? subscription = _socketSubscription;
    _socketSubscription = null;
    await subscription?.cancel();
    final WebSocket? socket = _socket;
    _socket = null;
    _relayGeneration += 1;
    _activeTransport = DeviceLinkActiveTransport.none;
    await socket?.close();
    await _incomingDrain;
    await _events.close();
  }
}

bool _isDeviceLinkControlMessage(Map<String, Object?> message) =>
    const <String>{
      'hello',
      'welcome',
      'settings.update',
      'request.rejected',
    }.contains(message['type']);

bool _isOrderedFileMessage(Map<String, Object?> message) =>
    message['type'] == 'file.chunk' || message['type'] == 'file.end';

Uri _relaySocketUri(Uri relayUrl, String room, DeviceLinkConnectionSide side) {
  final String basePath = relayUrl.path == '/' ? '' : relayUrl.path;
  return relayUrl.replace(
    scheme: switch (relayUrl.scheme) {
      'https' => 'wss',
      'http' => 'ws',
      _ => relayUrl.scheme,
    },
    path: '$basePath/v1/rooms/${Uri.encodeComponent(room)}',
    queryParameters: <String, String>{'side': side.name},
    fragment: '',
  );
}
