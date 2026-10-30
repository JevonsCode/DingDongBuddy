import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const _target = AgentConversationTarget(
  client: AgentClient.codex,
  conversationId: 'original-conversation',
);
final _time = DateTime.utc(2026, 10, 30, 10);

void main() {
  test(
    'an auxiliary read during the atomic rename uses the completed staged history',
    () {
      final directory = Directory.systemTemp.createTempSync('activity-rename-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/history.json');
      final store = FileAgentActivityStore(file);
      store.save(
        AgentActivityHistory(
          activities: [
            AgentActivity(
              id: 'older',
              source: 'Codex',
              message: 'Old',
              completedAt: _time,
              unseen: false,
              sequence: 1,
            ),
          ],
          latestSequence: 1,
          lastViewedSequence: 1,
        ),
      );
      final staged =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      staged['latestSequence'] = 2;
      staged['activities'] = [
        AgentActivity(
          id: 'newer',
          source: 'Codex',
          message: 'New',
          completedAt: _time,
          unseen: true,
          sequence: 2,
        ).toJson(),
        ...staged['activities'] as List,
      ];
      File(
        '${file.path}.tmp',
      ).writeAsStringSync(jsonEncode(staged), flush: true);
      file.renameSync('${file.path}.bak');
      final duringRename = store.load();
      expect(duringRename.activities, hasLength(2));
      expect(duringRename.latestSequence, 2);
      expect(duringRename.lastViewedSequence, 1);
    },
  );

  test('an auxiliary controller cannot overwrite newer host history', () {
    final store = InMemoryAgentActivityStore();
    var id = 0;
    final host = ActivityController(
      store: store,
      idGenerator: () => 'host-${++id}',
      now: () => _time,
    )..load();
    addTearDown(host.dispose);
    final original = host.record(source: 'Codex', message: 'Original').activity;
    final auxiliary = ActivityController(
      store: store,
      persistHistory: false,
      now: () => _time,
    )..load();
    addTearDown(auxiliary.dispose);
    host.record(source: 'Other', message: 'Newer host notification');
    auxiliary.markOpened(original);
    auxiliary.markFeedViewed(auxiliary.latestSequence);
    expect(store.load().activities, hasLength(2));
    expect(store.load().activities.last.opened, isFalse);
    host.markOpened(original);
    auxiliary.reload();
    expect(auxiliary.activities, hasLength(2));
    expect(
      auxiliary.activities.singleWhere((item) => item.id == original.id).opened,
      isTrue,
    );
  });

  test('opened state and the visit checkpoint survive the real file store', () {
    final directory = Directory.systemTemp.createTempSync('activity-visits-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final store = FileAgentActivityStore(
      File('${directory.path}/history.json'),
    );
    final controller = ActivityController(store: store, now: () => _time);
    addTearDown(controller.dispose);
    controller.load();
    final first = controller
        .record(source: 'Codex', message: 'Ready', conversationTarget: _target)
        .activity;
    controller.markFeedViewed(controller.latestSequence);
    controller.markAllSeen();
    expect(controller.activities.single.opened, isFalse);
    controller.markOpened(first);

    final restored = ActivityController(store: store, now: () => _time)..load();
    addTearDown(restored.dispose);
    expect(restored.activities.single.opened, isTrue);
    expect(restored.activities.single.unseen, isFalse);
    expect(restored.activities.single.sequence, first.sequence);
    expect(restored.lastViewedSequence, first.sequence);
    expect(restored.latestSequence, first.sequence);
  });

  test('legacy history does not invent opened records or a previous visit', () {
    final directory = Directory.systemTemp.createTempSync('activity-legacy-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/history.json');
    file.writeAsStringSync(
      jsonEncode({
        'version': 2,
        'activities': [
          {
            'id': 'legacy',
            'source': 'Codex',
            'message': 'Previously seen',
            'completedAt': _time.toIso8601String(),
            'unseen': false,
          },
        ],
      }),
    );
    final controller = ActivityController(
      store: FileAgentActivityStore(file),
      now: () => _time,
    )..load();
    addTearDown(controller.dispose);
    expect(controller.activities.single.opened, isFalse);
    expect(controller.activities.single.sequence, 0);
    expect(controller.lastViewedSequence, isNull);
    controller.markFeedViewed(controller.latestSequence);
    final next = controller.record(source: 'Codex', message: 'New').activity;
    expect(next.sequence, greaterThan(controller.lastViewedSequence!));
  });

  test('seen and pin changes preserve opening feedback', () {
    final item = AgentActivity.fromJson({
      'id': 'opened',
      'source': 'Codex',
      'message': 'Ready',
      'completedAt': _time.toIso8601String(),
      'unseen': true,
      'opened': true,
      'sequence': 12,
    });
    final updated = item.seen().withPinned(true);
    expect(updated.opened, isTrue);
    expect(updated.sequence, 12);
    expect(updated.unseen, isFalse);
  });

  test(
    'a grouped update resets opened even when its timestamp is identical',
    () {
      final controller = ActivityController(now: () => _time)..load();
      addTearDown(controller.dispose);
      final first = controller
          .record(
            source: 'Codex',
            message: 'First',
            conversationTarget: _target,
          )
          .activity;
      controller.markOpened(first);
      expect(controller.activities.single.opened, isTrue);
      final next = controller
          .record(
            source: 'Codex',
            message: 'Second',
            conversationTarget: _target,
          )
          .activity;
      expect(next.id, first.id);
      expect(next.sequence, greaterThan(first.sequence));
      expect(next.opened, isFalse);
      expect(next.repeatCount, 2);
    },
  );

  test('a delayed launch cannot mark a newer notification opened', () {
    final controller = ActivityController(now: () => _time)..load();
    addTearDown(controller.dispose);
    final first = controller
        .record(source: 'Codex', message: 'First', conversationTarget: _target)
        .activity;
    controller.record(
      source: 'Codex',
      message: 'Arrived during launch',
      conversationTarget: _target,
    );
    controller.markOpened(first);
    expect(controller.activities.single.opened, isFalse);
  });

  test('a deduplicated lifecycle hook preserves the opened notification', () {
    final controller = ActivityController(now: () => _time)..load();
    addTearDown(controller.dispose);
    final original = controller
        .record(
          source: 'Codex',
          message: 'Finished',
          conversationTarget: _target,
        )
        .activity;
    controller.markOpened(original);
    controller.recordRepeat(
      source: 'Codex',
      message: 'Matching completion hook',
      target: _target,
    );
    expect(controller.activities.single.sequence, original.sequence);
    expect(controller.activities.single.opened, isTrue);
  });

  test(
    'new and historical groups are separated before filtering and paging',
    () async {
      var id = 0;
      final controller = ActivityController(
        idGenerator: () => '${++id}',
        now: () => _time,
      )..load();
      addTearDown(controller.dispose);
      final old = controller
          .record(source: 'Codex', message: 'Historical')
          .activity;
      controller.setPinned(old.id, true);
      controller.markFeedViewed(controller.latestSequence);
      final boundary = controller.lastViewedSequence!;
      controller.record(source: 'Other', message: 'Filtered out');
      controller.record(
        source: 'Codex',
        message: 'New backdated update',
        completedAt: _time.subtract(const Duration(days: 1)),
      );
      final first = await controller.queryPage(
        newerThanSequence: boundary,
        sources: {'Codex'},
        limit: 1,
      );
      final second = await controller.queryPage(
        newerThanSequence: boundary,
        sources: {'Codex'},
        offset: 1,
        limit: 1,
      );
      expect(first.items.single.message, 'New backdated update');
      expect(second.items.single.id, old.id);
      expect(first.total, 2);
    },
  );

  test(
    'an older view acknowledgement never moves the checkpoint backwards',
    () {
      final controller = ActivityController(now: () => _time)..load();
      addTearDown(controller.dispose);
      controller.record(source: 'Codex', message: 'One');
      controller.markFeedViewed(controller.latestSequence);
      final previous = controller.lastViewedSequence!;
      controller.record(source: 'Codex', message: 'Two');
      controller.markFeedViewed(controller.latestSequence);
      controller.markFeedViewed(previous);
      expect(controller.lastViewedSequence, controller.latestSequence);
    },
  );

  test(
    'clearing or disabling remembered history resets the visit checkpoint',
    () {
      final store = InMemoryAgentActivityStore();
      final controller = ActivityController(store: store, now: () => _time)
        ..load();
      addTearDown(controller.dispose);
      controller.record(source: 'Codex', message: 'Ready');
      controller.markFeedViewed(controller.latestSequence);
      controller.clear();
      expect(controller.lastViewedSequence, isNull);
      expect(controller.latestSequence, 0);
      controller.record(source: 'Codex', message: 'Another update');
      controller.markFeedViewed(controller.latestSequence);
      final restarted = ActivityController(store: store, now: () => _time);
      // The public settings configuration owns the retention policy.
      restarted.configure(
        rememberAcrossRestarts: false,
        maxItems: 500,
        countWindowHours: 24,
      );
      restarted.load(resetPreviousSession: true);
      addTearDown(restarted.dispose);
      expect(restarted.activities, isEmpty);
      expect(restarted.lastViewedSequence, isNull);
    },
  );
}
