import 'dart:async';

import 'package:dingdong/app/app_dependencies.dart';
import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:dingdong/features/agent_api/data/agent_bridge.dart';
import 'package:dingdong/features/agent_api/data/ding_request.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Agent notification preferences', () {
    const DingRequest request = DingRequest(source: 'Codex');

    test('suppresses a positively identified subagent by default', () async {
      expect(
        await shouldDeliverAgentNotification(
          request: request,
          settings: const AppSettings(),
          isSubagentNotification: (_) async => true,
        ),
        isFalse,
      );
    });

    test('keeps main Agent notifications visible by default', () async {
      expect(
        await shouldDeliverAgentNotification(
          request: request,
          settings: const AppSettings(),
          isSubagentNotification: (_) async => false,
        ),
        isTrue,
      );
    });

    test(
      'suppresses a positively identified Codex voice task by default',
      () async {
        expect(
          await shouldDeliverAgentNotification(
            request: request,
            settings: const AppSettings(),
            isCodexVoiceNotification: (_) async => true,
          ),
          isFalse,
        );
      },
    );

    test('keeps ordinary Codex tasks visible by default', () async {
      expect(
        await shouldDeliverAgentNotification(
          request: request,
          settings: const AppSettings(),
          isCodexVoiceNotification: (_) async => false,
        ),
        isTrue,
      );
    });

    test('voice opt-in skips Codex voice classification', () async {
      var detectorCalls = 0;

      expect(
        await shouldDeliverAgentNotification(
          request: request,
          settings: const AppSettings(notifyCodexVoiceActivity: true),
          isCodexVoiceNotification: (_) async {
            detectorCalls += 1;
            return true;
          },
        ),
        isTrue,
      );
      expect(detectorCalls, 0);
    });

    test(
      'voice classification failure does not hide an Agent completion',
      () async {
        expect(
          await shouldDeliverAgentNotification(
            request: request,
            settings: const AppSettings(),
            isCodexVoiceNotification: (_) async => throw StateError('offline'),
          ),
          isTrue,
        );
      },
    );

    test('respects the completion notification switch', () async {
      expect(
        await shouldDeliverAgentNotification(
          request: const DingRequest(),
          settings: const AppSettings(notifyAgentCompletion: false),
        ),
        isFalse,
      );
    });

    test('respects the attention notification switch', () async {
      expect(
        await shouldDeliverAgentNotification(
          request: const DingRequest(
            notificationKind: AgentNotificationKind.attention,
          ),
          settings: const AppSettings(notifyAgentAttention: false),
        ),
        isFalse,
      );
    });

    test(
      'does not classify a disabled notification kind as subagent work',
      () async {
        var detectorCalls = 0;
        var voiceDetectorCalls = 0;

        expect(
          await shouldDeliverAgentNotification(
            request: const DingRequest(
              notificationKind: AgentNotificationKind.attention,
            ),
            settings: const AppSettings(notifyAgentAttention: false),
            isCodexVoiceNotification: (_) async {
              voiceDetectorCalls += 1;
              return false;
            },
            isSubagentNotification: (_) async {
              detectorCalls += 1;
              return false;
            },
          ),
          isFalse,
        );
        expect(detectorCalls, 0);
        expect(voiceDetectorCalls, 0);
      },
    );

    test(
      'opt-in delivers subagent notifications without classification',
      () async {
        var detectorCalls = 0;

        expect(
          await shouldDeliverAgentNotification(
            request: request,
            settings: const AppSettings(notifySubagentActivity: true),
            isSubagentNotification: (_) async {
              detectorCalls += 1;
              return true;
            },
          ),
          isTrue,
        );
        expect(detectorCalls, 0);
      },
    );

    test('classification failure does not hide an Agent completion', () async {
      expect(
        await shouldDeliverAgentNotification(
          request: request,
          settings: const AppSettings(),
          isSubagentNotification: (_) async => throw StateError('offline'),
        ),
        isTrue,
      );
    });

    test('filtered subagent reaches neither delivery route', () async {
      var nativeCalls = 0;
      var companionCalls = 0;
      var filteredCalls = 0;

      await deliverAgentNotification(
        request: request,
        settings: const AppSettings(),
        isSubagentNotification: (_) async => true,
        nativeDelivery: (_) async => nativeCalls += 1,
        companionDelivery: (_) async => companionCalls += 1,
        onFiltered: (_) async => filteredCalls += 1,
      );

      expect(nativeCalls, 0);
      expect(companionCalls, 0);
      expect(filteredCalls, 1);
    });

    test('opt-in resolves sound and reaches both delivery routes', () async {
      final List<DingSound> nativeSounds = <DingSound>[];
      final List<DingSound> companionSounds = <DingSound>[];

      await deliverAgentNotification(
        request: request,
        settings: const AppSettings(
          notifySubagentActivity: true,
          selectedSound: 'dingCrisp',
        ),
        isSubagentNotification: (_) async => true,
        nativeDelivery: (DingRequest value) async {
          nativeSounds.add(value.sound);
        },
        companionDelivery: (DingRequest value) async {
          companionSounds.add(value.sound);
        },
      );

      expect(nativeSounds, <DingSound>[DingSound.dingCrisp]);
      expect(companionSounds, <DingSound>[DingSound.dingCrisp]);
    });
  });

  group('subagent task-start preference', () {
    final AgentBridgeTaskStart start = AgentBridgeTaskStart(
      task: 'Background review',
      source: 'Codex',
      startedAt: DateTime.utc(2026, 8, 13),
      conversationId: 'subagent-thread',
      workspacePath: '/workspace/dingdong',
    );

    test('suppresses an identified subagent run by default', () async {
      expect(
        await shouldRecordAgentTaskStart(
          start: start,
          settings: const AppSettings(),
          isSubagentConversation: (_) async => true,
        ),
        isFalse,
      );
    });

    test('keeps a main run and classification failures visible', () async {
      expect(
        await shouldRecordAgentTaskStart(
          start: start,
          settings: const AppSettings(),
          isSubagentConversation: (_) async => false,
        ),
        isTrue,
      );
      expect(
        await shouldRecordAgentTaskStart(
          start: start,
          settings: const AppSettings(),
          isSubagentConversation: (_) async => throw StateError('offline'),
        ),
        isTrue,
      );
    });

    test('opt-in records a subagent run without classification', () async {
      var detectorCalls = 0;

      expect(
        await shouldRecordAgentTaskStart(
          start: start,
          settings: const AppSettings(notifySubagentActivity: true),
          isSubagentConversation: (_) async {
            detectorCalls += 1;
            return true;
          },
        ),
        isTrue,
      );
      expect(detectorCalls, 0);
    });
  });

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
