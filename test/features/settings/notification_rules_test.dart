import 'package:dingdong/app/app_dependencies.dart';
import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:dingdong/features/agent_api/data/ding_request.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuietHours', () {
    test('covers a window that crosses midnight', () {
      const QuietHours quiet = QuietHours(
        enabled: true,
        startMinute: 22 * 60,
        endMinute: 8 * 60,
      );

      expect(quiet.covers(DateTime(2026, 10, 18, 23, 30)), isTrue);
      expect(quiet.covers(DateTime(2026, 10, 18, 7, 59)), isTrue);
      expect(quiet.covers(DateTime(2026, 10, 18, 8)), isFalse);
      expect(quiet.covers(DateTime(2026, 10, 18, 21, 59)), isFalse);
    });

    test('covers a same-day window and is inert when disabled', () {
      const QuietHours lunch = QuietHours(
        enabled: true,
        startMinute: 12 * 60,
        endMinute: 13 * 60,
      );

      expect(lunch.covers(DateTime(2026, 10, 18, 12, 30)), isTrue);
      expect(lunch.covers(DateTime(2026, 10, 18, 13)), isFalse);
      expect(
        lunch.copyWith(enabled: false).covers(DateTime(2026, 10, 18, 12, 30)),
        isFalse,
      );
    });
  });

  group('NotificationRules', () {
    test('round-trips through its stored JSON', () {
      const NotificationRules rules = NotificationRules(
        attentionSound: 'custom',
        attentionCustomSoundPath: '/sounds/alarm.wav',
        completionToPhone: false,
        quietHours: QuietHours(
          enabled: true,
          startMinute: 23 * 60,
          endMinute: 7 * 60 + 30,
          allowAttention: false,
        ),
        completionMinimumMinutes: 5,
      );

      expect(NotificationRules.parse(rules.encode()), rules);
    });

    test('falls back to defaults for missing or invalid values', () {
      expect(NotificationRules.parse(null), NotificationRules.defaultValue);
      expect(
        NotificationRules.parse('not json'),
        NotificationRules.defaultValue,
      );
      final NotificationRules parsed = NotificationRules.parse(
        '{"attentionSound":"siren","completionMinimumMinutes":7,'
        '"quietHours":{"enabled":true,"startMinute":9999}}',
      );
      expect(parsed.attentionSound, sameAsCompletionSound);
      expect(parsed.completionMinimumMinutes, 0);
      expect(parsed.quietHours.startMinute, 22 * 60);
      expect(parsed.quietHours.enabled, isTrue);
    });

    test('settings repository persists the rules', () async {
      final SettingsRepository repository = SettingsRepository(
        MemoryPreferencesBackend(),
      );
      const NotificationRules rules = NotificationRules(
        attentionSound: 'dingBright',
        attentionToPhone: false,
      );

      await repository.save(const AppSettings(notificationRules: rules));

      expect((await repository.load()).notificationRules, rules);
    });
  });

  group('planAgentNotification', () {
    final DateTime afternoon = DateTime(2026, 10, 18, 15);
    final DateTime night = DateTime(2026, 10, 18, 23);
    const NotificationRules quietNights = NotificationRules(
      quietHours: QuietHours(enabled: true),
    );

    AgentNotificationPlan plan(
      AgentNotificationKind kind, {
      NotificationRules rules = NotificationRules.defaultValue,
      DateTime? now,
      Duration? taskDuration,
    }) => planAgentNotification(
      kind: kind,
      completionSound: 'dingSoft',
      completionCustomSoundPath: '/sounds/done.wav',
      rules: rules,
      now: now ?? afternoon,
      taskDuration: taskDuration,
    );

    test('defaults alert everywhere with the completion sound', () {
      final AgentNotificationPlan result = plan(
        AgentNotificationKind.attention,
      );

      expect(result.alertDesktop, isTrue);
      expect(result.alertPhone, isTrue);
      expect(result.sound, 'dingSoft');
      expect(result.customSoundPath, '/sounds/done.wav');
    });

    test('attention can use its own sound and custom file', () {
      final AgentNotificationPlan result = plan(
        AgentNotificationKind.attention,
        rules: const NotificationRules(
          attentionSound: 'custom',
          attentionCustomSoundPath: '/sounds/alarm.wav',
        ),
      );

      expect(result.sound, 'custom');
      expect(result.customSoundPath, '/sounds/alarm.wav');
      expect(
        plan(
          AgentNotificationKind.completion,
          rules: const NotificationRules(attentionSound: 'dingBright'),
        ).sound,
        'dingSoft',
      );
    });

    test('quiet hours silence completions but let attention through', () {
      expect(
        plan(
          AgentNotificationKind.completion,
          rules: quietNights,
          now: night,
        ).silent,
        isTrue,
      );
      expect(
        plan(
          AgentNotificationKind.attention,
          rules: quietNights,
          now: night,
        ).alertDesktop,
        isTrue,
      );
      expect(
        plan(
          AgentNotificationKind.attention,
          rules: const NotificationRules(
            quietHours: QuietHours(enabled: true, allowAttention: false),
          ),
          now: night,
        ).silent,
        isTrue,
      );
    });

    test('per-kind phone switch keeps the desktop alert', () {
      final AgentNotificationPlan result = plan(
        AgentNotificationKind.completion,
        rules: const NotificationRules(completionToPhone: false),
      );

      expect(result.alertDesktop, isTrue);
      expect(result.alertPhone, isFalse);
    });

    test('short tasks complete silently; unknown durations still alert', () {
      const NotificationRules longOnly = NotificationRules(
        completionMinimumMinutes: 5,
      );

      expect(
        plan(
          AgentNotificationKind.completion,
          rules: longOnly,
          taskDuration: const Duration(minutes: 2),
        ).silent,
        isTrue,
      );
      expect(
        plan(
          AgentNotificationKind.completion,
          rules: longOnly,
          taskDuration: const Duration(minutes: 6),
        ).silent,
        isFalse,
      );
      expect(
        plan(AgentNotificationKind.completion, rules: longOnly).silent,
        isFalse,
      );
      expect(
        plan(
          AgentNotificationKind.attention,
          rules: longOnly,
          taskDuration: const Duration(seconds: 10),
        ).silent,
        isFalse,
      );
    });
  });

  group('deliverAgentNotification rules', () {
    test(
      'a silent reminder is recorded without native alert or push',
      () async {
        var nativeCalls = 0;
        final List<DingRequest> companion = <DingRequest>[];

        await deliverAgentNotification(
          request: const DingRequest(source: 'Codex'),
          settings: const AppSettings(
            notificationRules: NotificationRules(completionMinimumMinutes: 3),
          ),
          now: () => DateTime(2026, 10, 18, 15, 1),
          taskStartedAt: (_) => DateTime(2026, 10, 18, 15),
          nativeDelivery: (_) async => nativeCalls += 1,
          companionDelivery: (DingRequest value) async => companion.add(value),
        );

        expect(nativeCalls, 0);
        expect(companion, hasLength(1));
        expect(companion.single.alertPhone, isFalse);
      },
    );

    test('attention uses its own sound on every route', () async {
      final List<DingSound> sounds = <DingSound>[];

      await deliverAgentNotification(
        request: const DingRequest(
          source: 'Codex',
          notificationKind: AgentNotificationKind.attention,
        ),
        settings: const AppSettings(
          selectedSound: 'dingSoft',
          notificationRules: NotificationRules(attentionSound: 'dingBright'),
        ),
        nativeDelivery: (DingRequest value) async => sounds.add(value.sound),
        companionDelivery: (DingRequest value) async => sounds.add(value.sound),
      );

      expect(sounds, <DingSound>[DingSound.dingBright, DingSound.dingBright]);
    });
  });
}
