import 'dart:convert';

import 'package:dingdong/features/device_link/data/device_link_session.dart';
import 'package:dingdong/features/device_link/data/secure_message_codec.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

const String _secret = 'BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc';
