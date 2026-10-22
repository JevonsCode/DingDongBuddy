import 'dart:convert';

import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'retains independent tray appearance choices for both reminder kinds',
    () {
      final rules = NotificationRules.parse(
        '{"completionTrayStyle":"staticMarker",'
        '"attentionTrayStyle":"softPulse",'
        '"attentionTrayColor":"amber"}',
      );
      final stored = jsonDecode(rules.encode()) as Map;
      expect(stored['completionTrayStyle'], 'staticMarker');
      expect(stored['attentionTrayStyle'], 'softPulse');
      expect(stored['attentionTrayColor'], 'amber');
    },
  );

  test(
    'old settings get distinct defaults without overwriting the old color',
    () {
      final stored = jsonDecode(NotificationRules.parse('{}').encode()) as Map;
      expect(stored['completionTrayColor'], isNull);
      expect(stored['completionTrayStyle'], 'staticMarker');
      expect(stored['attentionTrayStyle'], 'softPulse');
      expect(stored['attentionTrayColor'], 'amber');
    },
  );
  test(
    'appearance settings resolve per kind while preserving the saved completion color',
    () {
      final rules = NotificationRules.parse(
        '{"attentionTrayColor":"blue","completionTrayStyle":"softPulse","attentionTrayStyle":"staticMarker"}',
      );
      expect(
        rules.trayColorFor(
          AgentNotificationKind.completion,
          legacyCompletionColor: TrayNotificationColor.purple,
        ),
        TrayNotificationColor.purple,
      );
      expect(
        rules.trayColorFor(
          AgentNotificationKind.attention,
          legacyCompletionColor: TrayNotificationColor.purple,
        ),
        TrayNotificationColor.blue,
      );
      expect(
        rules.trayStyleFor(AgentNotificationKind.completion),
        TrayReminderStyle.softPulse,
      );
      expect(
        rules.trayStyleFor(AgentNotificationKind.attention),
        TrayReminderStyle.staticMarker,
      );
      final invalid = NotificationRules.parse(
        '{"completionTrayStyle":"blink","attentionTrayStyle":"blink","attentionTrayColor":"red"}',
      );
      expect(invalid.completionTrayStyle, TrayReminderStyle.staticMarker);
      expect(invalid.attentionTrayStyle, TrayReminderStyle.softPulse);
      expect(invalid.attentionTrayColor, TrayNotificationColor.amber);
    },
  );
  test('settings apply saved tray rules on load and after editing', () async {
    final applied = <NotificationRules>[];
    final model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      onNotificationRulesChanged: (value) async => applied.add(value),
    );
    addTearDown(model.dispose);
    await model.load();
    expect(applied.single.attentionTrayColor, TrayNotificationColor.amber);
    await model.setNotificationRules(
      model.settings.notificationRules.copyWith(
        attentionTrayStyle: TrayReminderStyle.staticMarker,
      ),
    );
    expect(applied.last.attentionTrayStyle, TrayReminderStyle.staticMarker);
    expect(applied, hasLength(2));
  });
}
