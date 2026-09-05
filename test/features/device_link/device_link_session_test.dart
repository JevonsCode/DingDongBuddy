import 'dart:async';
import 'dart:convert';

import 'package:dingdong/features/device_link/data/device_link_session.dart';
import 'package:dingdong/features/device_link/data/secure_message_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  test('a relay replacement close stops the superseded session', () {
    expect(
      deviceLinkConnectionWasReplaced(1008, 'Replaced by a newer connection'),
      isTrue,
    );
    expect(deviceLinkConnectionWasReplaced(1006, ''), isFalse);
    expect(deviceLinkConnectionWasReplaced(1008, 'Policy violation'), isFalse);
  });

  test('128 KiB UTF-8 text fits in a final encrypted relay frame', () async {
    final SecureMessageCodec codec = SecureMessageCodec.fromBase64Url(_secret);
    final String content = List<String>.filled(32 * 1024, '🚀').join();
    expect(utf8.encode(content), hasLength(128 * 1024));

    final String envelope = await codec.seal(<String, Object?>{
      'type': 'clipboard.upsert',
      'item': <String, Object?>{'id': 'safe', 'content': content},
    });
    final String frame = encodeDeviceLinkRelayFrame(
      type: 'data',
      envelope: envelope,
    );

    expect(
      utf8.encode(frame).length,
      lessThanOrEqualTo(deviceLinkMaximumRelayFrameBytes),
    );
  });

  test(
    'final encrypted relay frame rejects JSON expansion beyond 256 KiB',
    () async {
      final SecureMessageCodec codec = SecureMessageCodec.fromBase64Url(
        _secret,
      );
      final String content = List<String>.filled(128 * 1024, '\u0001').join();
      expect(utf8.encode(content), hasLength(128 * 1024));
      final String envelope = await codec.seal(<String, Object?>{
        'type': 'clipboard.upsert',
        'item': <String, Object?>{'id': 'expanded', 'content': content},
      });

      expect(
        () => encodeDeviceLinkRelayFrame(type: 'data', envelope: envelope),
        throwsA(
          isA<DeviceLinkFrameTooLargeException>()
              .having(
                (DeviceLinkFrameTooLargeException error) => error.actualBytes,
                'actualBytes',
                greaterThan(deviceLinkMaximumRelayFrameBytes),
              )
              .having(
                (DeviceLinkFrameTooLargeException error) => error.maximumBytes,
                'maximumBytes',
                deviceLinkMaximumRelayFrameBytes,
              ),
        ),
      );
    },
  );

  test('direct data sends wait for native buffer pressure to drain', () async {
    final _FakeDataChannel channel = _FakeDataChannel(
      bufferedAmounts: <int>[
        deviceLinkMaximumDataChannelBufferedBytes + 1,
        deviceLinkMaximumDataChannelBufferedBytes,
      ],
    );
    final WebRtcDeviceLinkSession session = _testingSession(channel);
    addTearDown(session.close);

    await session.send(<String, Object?>{'type': 'file.chunk', 'index': 0});

    expect(channel.bufferedAmountReads, 2);
    expect(channel.sent, hasLength(1));
  });

  test('a disconnected data channel aborts a pending buffered send', () async {
    final Completer<void> readStarted = Completer<void>();
    final Completer<int> readResult = Completer<int>();
    final _FakeDataChannel channel = _FakeDataChannel(
      onGetBufferedAmount: () {
        if (!readStarted.isCompleted) readStarted.complete();
        return readResult.future;
      },
    );
    final WebRtcDeviceLinkSession session = _testingSession(channel);

    final Future<void> sending = session.send(<String, Object?>{
      'type': 'file.chunk',
      'index': 0,
    });
    await readStarted.future;
    await session.close();
    readResult.complete(deviceLinkMaximumDataChannelBufferedBytes + 1);

    await expectLater(sending, throwsA(anything));
    expect(channel.sent, isEmpty);
  });
}

const String _secret = 'BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc';

WebRtcDeviceLinkSession _testingSession(RTCDataChannel channel) {
  return WebRtcDeviceLinkSession.forTesting(
    relayUrl: Uri.parse('https://relay.example.test'),
    room: 'device-link-test-room',
    secret: _secret,
    dataChannel: channel,
  );
}

final class _FakeDataChannel extends RTCDataChannel {
  _FakeDataChannel({List<int>? bufferedAmounts, this.onGetBufferedAmount})
    : _bufferedAmounts = List<int>.of(bufferedAmounts ?? <int>[0]) {
    stateChangeStream = const Stream<RTCDataChannelState>.empty();
    messageStream = const Stream<RTCDataChannelMessage>.empty();
  }

  final List<int> _bufferedAmounts;
  final Future<int> Function()? onGetBufferedAmount;
  final List<RTCDataChannelMessage> sent = <RTCDataChannelMessage>[];
  int bufferedAmountReads = 0;
  RTCDataChannelState stateValue = RTCDataChannelState.RTCDataChannelOpen;

  @override
  RTCDataChannelState get state => stateValue;

  @override
  int get id => 1;

  @override
  String get label => 'test-channel';

  @override
  int get bufferedAmount =>
      _bufferedAmounts.isEmpty ? 0 : _bufferedAmounts.first;

  @override
  Future<int> getBufferedAmount() {
    bufferedAmountReads += 1;
    final Future<int> Function()? read = onGetBufferedAmount;
    if (read != null) return read();
    if (_bufferedAmounts.isEmpty) return Future<int>.value(0);
    return Future<int>.value(_bufferedAmounts.removeAt(0));
  }

  @override
  Future<void> send(RTCDataChannelMessage message) async {
    sent.add(message);
  }

  @override
  Future<void> close() async {
    stateValue = RTCDataChannelState.RTCDataChannelClosed;
  }
}
