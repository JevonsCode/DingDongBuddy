import 'dart:async';

import 'package:dingdong/app/app_dependencies.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native failure does not block companion delivery', () async {
    final List<NotificationDeliveryFailure> failures =
        <NotificationDeliveryFailure>[];
    var companionCalls = 0;

    await deliverNotificationIndependently(
      nativeDelivery: () async => throw StateError('native unavailable'),
      companionDelivery: () async {
        companionCalls += 1;
      },
      onFailure: failures.add,
    );

    expect(companionCalls, 1);
    expect(failures, hasLength(1));
    expect(failures.single.route, NotificationDeliveryRoute.native);
    expect(failures.single.error, isA<StateError>());
  });

  test('companion failure does not block native delivery', () async {
    final List<NotificationDeliveryFailure> failures =
        <NotificationDeliveryFailure>[];
    final Completer<void> nativeStarted = Completer<void>();
    var nativeCompleted = false;

    await deliverNotificationIndependently(
      nativeDelivery: () async {
        nativeStarted.complete();
        await Future<void>.delayed(Duration.zero);
        nativeCompleted = true;
      },
      companionDelivery: () async {
        await nativeStarted.future;
        throw StateError('push unavailable');
      },
      onFailure: failures.add,
    );

    expect(nativeCompleted, isTrue);
    expect(failures, hasLength(1));
    expect(failures.single.route, NotificationDeliveryRoute.companion);
    expect(failures.single.error, isA<StateError>());
  });

  test('both route failures remain independently observable', () async {
    final List<NotificationDeliveryFailure> failures =
        <NotificationDeliveryFailure>[];

    await deliverNotificationIndependently(
      nativeDelivery: () async => throw StateError('native unavailable'),
      companionDelivery: () async => throw StateError('push unavailable'),
      onFailure: failures.add,
    );

    expect(
      failures.map((NotificationDeliveryFailure value) => value.route).toSet(),
      <NotificationDeliveryRoute>{
        NotificationDeliveryRoute.native,
        NotificationDeliveryRoute.companion,
      },
    );
  });

  test(
    'failures use Flutter error reporting when no observer is injected',
    () async {
      final FlutterExceptionHandler? previousHandler = FlutterError.onError;
      final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previousHandler);

      await deliverNotificationIndependently(
        nativeDelivery: () async => throw StateError('native unavailable'),
      );

      expect(reported, hasLength(1));
      expect(reported.single.exception, isA<StateError>());
      expect(reported.single.library, 'DingDong notification delivery');
      expect(reported.single.context.toString(), contains('native'));
    },
  );
}
