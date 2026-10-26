import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/settings/domain/reminder_profile.dart';
import 'package:dingdong/features/settings/domain/tray_reminder_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'local pages are disjoint, filter before paging, and pinned rows sort first',
    () async {
      var id = 0;
      final store = InMemoryAgentActivityStore();
      final c = ActivityController(store: store, idGenerator: () => '${++id}');
      addTearDown(c.dispose);
      c.load();
      for (var i = 0; i < 65; i++) {
        c.record(
          source: i.isEven ? 'Codex' : 'Claude Code',
          message: 'Update $i',
          completedAt: DateTime(2026, 10, 1 + i),
        );
      }
      expect(c.recentPageSize, 21);
      final page = await c.queryPage();
      final next = await c.queryPage(offset: page.items.length);
      expect(page.items.length, 21);
      expect(next.items.length, 21);
      expect(
        page.items
            .map((e) => e.id)
            .toSet()
            .intersection(next.items.map((e) => e.id).toSet()),
        isEmpty,
      );
      final oldest = c.activities.last;
      c.setPinned(oldest.id, true);
      final pinned = await c.queryPage();
      expect(pinned.items.first.id, oldest.id);
      c.setRecentPageSize(35);
      final restored = ActivityController(store: store)..load();
      addTearDown(restored.dispose);
      expect(restored.recentPageSize, 35);
      expect((await restored.queryPage()).items.first.pinned, true);
      final filtered = await c.queryPage(
        sources: {'Claude Code'},
        range: DateTimeRange(
          start: DateTime(2026, 10, 1),
          end: DateTime(2026, 10, 10),
        ),
      );
      expect(filtered.total, 5);
      expect(filtered.items.every((e) => e.source == 'Claude Code'), true);
    },
  );

  test(
    'historical reminder snapshot and pin survive seen and JSON round trip',
    () {
      const reminder = ReminderProfile(
        id: 'next',
        name: 'Next request',
        temporary: true,
        color: TrayNotificationColor.green,
        sound: 'dingDeep',
      );
      final activity = AgentActivity(
        id: '1',
        source: 'Agent',
        message: 'Ready',
        completedAt: DateTime(2026),
        unseen: true,
        reminder: reminder,
        pinned: true,
      );
      final restored = AgentActivity.fromJson(activity.seen().toJson());
      expect(restored.reminder, reminder);
      expect(restored.pinned, true);
      expect(restored.unseen, false);
      expect(
        restored
            .repeated(
              source: 'Agent',
              message: 'Still ready',
              completedAt: DateTime(2026, 2),
            )
            .pinned,
        true,
      );
    },
  );
}
