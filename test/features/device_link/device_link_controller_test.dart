import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/domain/agent_task_run.dart';
import 'package:dingdong/features/agent_api/data/ding_request.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/device_link/data/device_link_session.dart';
import 'package:dingdong/features/device_link/data/device_link_store.dart';
import 'package:dingdong/features/device_link/data/secure_message_codec.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:dingdong/features/device_link/ui/device_link_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('device link security envelope', () {
    test('legacy linked devices authorize no clipboard history', () {
      final LinkedDevice device = LinkedDevice.fromJson(<String, Object?>{
        'id': 'legacy-phone',
        'name': '旧连接',
        'kind': 'phone',
        'platform': 'android-pwa',
        'room': 'abcdefghijklmnopqrstuvwx',
        'secret': _secret,
        'autoSendClipboard': false,
        'receiveAgentNotifications': true,
        'vibrationEnabled': true,
        'manuallyDisconnected': false,
        'pairedAt': '2026-08-08T00:00:00.000Z',
      });

      expect(device.sharedClipboardItemIds, isEmpty);
      expect(device.toJson()['sharedClipboardItemIds'], isEmpty);
    });

    test(
      'pairing payload round-trips without putting the key in the URL query',
      () {
        final DevicePairingPayload payload = DevicePairingPayload(
          room: 'abcdefghijklmnopqrstuvwx',
          secret: _secret,
          hostId: 'desktop-one',
          hostName: 'Studio',
          relayUrl: Uri.parse('https://relay.example'),
        );

        final DevicePairingPayload decoded = DevicePairingPayload.decode(
          payload.encode(),
        );
        final Uri pairingUrl = Uri.parse(
          'https://relay.example/app/#pair=${payload.encode()}',
        );

        expect(decoded.room, payload.room);
        expect(decoded.secret, payload.secret);
        expect(decoded.hostName, 'Studio');
        expect(pairingUrl.query, isEmpty);
        expect(
          DevicePairingPayload.decode(
            pairingUrl.fragment.substring('pair='.length),
          ).secret,
          payload.secret,
          reason: 'The QR fragment is never sent in the HTTP request.',
        );
      },
    );

    test('encrypted messages reject a modified envelope', () async {
      final SecureMessageCodec codec = SecureMessageCodec.fromBase64Url(
        _secret,
      );
      final String envelope = await codec.seal(<String, Object?>{
        'type': 'clipboard.create',
        'content': 'only after Send',
      });

      expect(await codec.open(envelope), <String, Object?>{
        'type': 'clipboard.create',
        'content': 'only after Send',
      });
      final List<int> bytes = base64Url.decode(base64Url.normalize(envelope));
      bytes[bytes.length - 1] ^= 1;

      await expectLater(
        codec.open(base64Url.encode(bytes).replaceAll('=', '')),
        throwsA(anything),
      );
    });

    test('desktop codec opens the browser Web Crypto envelope format', () async {
      final SecureMessageCodec codec = SecureMessageCodec.fromBase64Url(
        _secret,
      );

      expect(
        await codec.open(
          'AAECAwQFBgcICQoLY6OdCW1s-3NV2oDwjjdO1sNK1-JtB1ULNLkG2Kyqn6lwjCm-g_Zru-FR_6pLKQ',
        ),
        <String, Object?>{'type': 'hello', 'value': 'web'},
      );
    });
  });

  group('device link direction rules', () {
    test(
      'desktop auto-send is off until its one-way switch is enabled',
      () async {
        final _Harness harness = await _connectedHarness(autoSend: false);
        addTearDown(harness.dispose);
        final ClipboardRecord local = _record('local', '电脑复制的内容');

        await harness.controller.handleLocalClipboard(local);
        expect(harness.session.sent, isEmpty);

        await harness.controller.setAutoSendClipboard('phone-one', true);
        await harness.controller.handleLocalClipboard(local);

        expect(harness.session.sent, hasLength(1));
        expect(harness.session.sent.single['type'], 'clipboard.upsert');
        expect(harness.session.sent.single['manual'], false);
        expect(
          harness.store.document!.devices.single.autoSendClipboard,
          isTrue,
        );
        expect(
          harness.store.document!.devices.single.sharedClipboardItemIds,
          <String>['local'],
        );

        harness.session.sent.clear();
        await harness.controller.handleLocalClipboard(
          local.copyWith(updatedAt: DateTime.utc(2026, 8, 7, 23, 59)),
        );
        expect(
          harness.session.sent,
          isEmpty,
          reason: 'Auto-send never backfills a record from before pairing.',
        );
      },
    );

    test('manual share can explicitly authorize an existing record', () async {
      final ClipboardRecord existing = _record(
        'existing',
        '连接前已经存在，但用户主动选择发送',
      ).copyWith(updatedAt: DateTime.utc(2026, 8, 7, 23, 59));
      final _Harness harness = await _connectedHarness(
        autoSend: false,
        clipboardRecords: <ClipboardRecord>[existing],
      );
      addTearDown(harness.dispose);

      await harness.controller.shareRecord(existing, 'phone-one');

      expect(harness.session.sent.single['manual'], isTrue);
      expect(
        harness.store.document!.devices.single.sharedClipboardItemIds,
        <String>['existing'],
      );
    });

    test('manual share rejects text above the 128 KiB UTF-8 limit', () async {
      final ClipboardRecord oversized = _record(
        'oversized',
        List<String>.filled(deviceLinkMaximumTextBytes + 1, 'a').join(),
      );
      final _Harness harness = await _connectedHarness(
        autoSend: false,
        clipboardRecords: <ClipboardRecord>[oversized],
      );
      addTearDown(harness.dispose);

      await expectLater(
        harness.controller.shareRecord(oversized, 'phone-one'),
        throwsA(
          isA<DeviceLinkTextTooLargeException>().having(
            (DeviceLinkTextTooLargeException error) => error.actualBytes,
            'actualBytes',
            deviceLinkMaximumTextBytes + 1,
          ),
        ),
      );

      expect(harness.session.sent, isEmpty);
      expect(
        harness.store.document!.devices.single.sharedClipboardItemIds,
        isEmpty,
        reason: 'A rejected item must never be presented as shared.',
      );
    });

    test(
      'files are downloadable only after being sent to the device',
      () async {
        final Directory directory = await Directory.systemTemp.createTemp(
          'dingdong-shared-file-test-',
        );
        final File file = File('${directory.path}/private-before-share.txt');
        await file.writeAsString('only after explicit share');
        final DateTime now = DateTime.utc(2026, 8, 8, 8);
        final ClipboardRecord record = ClipboardRecord(
          id: 'host-file',
          group: '',
          title: 'private-before-share.txt',
          content: file.path,
          tags: const <String>['clipboard', 'file', 'file-url'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: now,
          updatedAt: now,
        );
        final _Harness harness = await _connectedHarness(
          autoSend: false,
          clipboardRecords: <ClipboardRecord>[record],
        );
        addTearDown(() async {
          await harness.dispose();
          if (await directory.exists()) await directory.delete(recursive: true);
        });

        harness.session.emit(
          const DeviceLinkMessageEvent(<String, Object?>{
            'type': 'file.request',
            'itemId': 'host-file',
          }),
        );
        await _flushEvents();
        expect(harness.session.sent, isEmpty);

        await harness.controller.shareRecord(record, 'phone-one');
        harness.session.sent.clear();
        harness.session.emit(
          const DeviceLinkMessageEvent(<String, Object?>{
            'type': 'file.request',
            'itemId': 'host-file',
          }),
        );
        await _waitUntil(
          () => harness.session.sent.any(
            (Map<String, Object?> value) => value['type'] == 'file.end',
          ),
        );

        expect(
          harness.session.sent.map(
            (Map<String, Object?> value) => value['type'],
          ),
          <Object?>['file.start', 'file.chunk', 'file.end'],
        );
      },
    );

    test(
      'phone content appears only after an explicit create message',
      () async {
        final _Harness harness = await _connectedHarness(autoSend: false);
        addTearDown(harness.dispose);

        expect(harness.clipboardStore.list(limit: 50), isEmpty);
        harness.session.emit(
          const DeviceLinkMessageEvent(<String, Object?>{
            'type': 'settings.update',
            'agentNotificationsEnabled': 'malformed',
          }),
        );
        await _flushEvents();
        expect(harness.clipboardStore.list(limit: 50), isEmpty);

        harness.session.emit(
          const DeviceLinkMessageEvent(<String, Object?>{
            'type': 'clipboard.create',
            'content': '用户在输入框里手动粘贴后点击了发送',
          }),
        );
        await _flushEvents();

        final ClipboardRecord received = harness.clipboardStore
            .list(limit: 50)
            .single;
        expect(received.content, '用户在输入框里手动粘贴后点击了发送');
        expect(received.source, '来自 iPhone');
        expect(received.tags, contains('device-origin:phone-one'));
      },
    );

    test('phone text limit is measured in UTF-8 bytes', () async {
      final _Harness harness = await _connectedHarness(autoSend: false);
      addTearDown(harness.dispose);
      final String exact = '${List<String>.filled(43690, '你').join()}ab';
      expect(utf8.encode(exact), hasLength(deviceLinkMaximumTextBytes));

      harness.session.emit(
        DeviceLinkMessageEvent(<String, Object?>{
          'type': 'clipboard.create',
          'requestId': 'exact-limit',
          'content': exact,
        }),
      );
      await _flushEvents();
      expect(harness.clipboardStore.list(limit: 50), hasLength(1));
      expect(harness.session.sent, isEmpty);

      harness.session.emit(
        DeviceLinkMessageEvent(<String, Object?>{
          'type': 'clipboard.create',
          'requestId': 'over-limit',
          'content': '${exact}a',
        }),
      );
      await _flushEvents();

      expect(harness.clipboardStore.list(limit: 50), hasLength(1));
      expect(harness.session.sent, hasLength(1));
      expect(harness.session.sent.single, <String, Object?>{
        'type': 'request.rejected',
        'requestType': 'clipboard.create',
        'requestId': 'over-limit',
        'code': 'text_too_large',
        'maximumBytes': deviceLinkMaximumTextBytes,
      });
    });

    test('phone file is saved by the host only after file.end', () async {
      final _Harness harness = await _connectedHarness(autoSend: false);
      addTearDown(harness.dispose);
      final String encoded = base64Encode(utf8.encode('LAN file'));

      harness.session.emit(
        const DeviceLinkMessageEvent(<String, Object?>{
          'type': 'file.start',
          'transferId': 'transfer-one',
          'name': '../note.txt',
          'size': 8,
        }),
      );
      harness.session.emit(
        DeviceLinkMessageEvent(<String, Object?>{
          'type': 'file.chunk',
          'transferId': 'transfer-one',
          'index': 0,
          'data': encoded,
        }),
      );
      await _flushEvents();
      expect(harness.clipboardStore.list(limit: 50), isEmpty);

      harness.session.emit(
        const DeviceLinkMessageEvent(<String, Object?>{
          'type': 'file.end',
          'transferId': 'transfer-one',
        }),
      );
      await _waitUntil(() => harness.clipboardStore.list(limit: 50).isNotEmpty);

      final ClipboardRecord received = harness.clipboardStore
          .list(limit: 50)
          .single;
      expect(received.title, 'note.txt');
      expect(received.kind, ClipboardKind.file);
      expect(await File(received.content).readAsString(), 'LAN file');
    });

    test('one malformed message does not block later device events', () async {
      final _Harness harness = await _connectedHarness(autoSend: false);
      addTearDown(harness.dispose);

      harness.session.emit(
        const DeviceLinkMessageEvent(<String, Object?>{
          'type': 'file.start',
          'transferId': 'malformed-transfer',
          'name': 'broken.txt',
          'size': 1,
        }),
      );
      harness.session.emit(
        const DeviceLinkMessageEvent(<String, Object?>{
          'type': 'file.chunk',
          'transferId': 'malformed-transfer',
          'index': 0,
          'data': 'not-valid-base64%',
        }),
      );
      harness.session.emit(
        const DeviceLinkMessageEvent(<String, Object?>{
          'type': 'settings.update',
          'vibrationEnabled': false,
        }),
      );
      await _flushEvents();

      expect(harness.controller.devices.single.vibrationEnabled, isFalse);
    });

    test('disconnect keeps trust while delete revokes the device', () async {
      final _Harness harness = await _connectedHarness(autoSend: false);
      addTearDown(harness.dispose);

      await harness.controller.disconnect('phone-one');
      expect(harness.controller.devices.single.manuallyDisconnected, isTrue);
      expect(harness.session.closed, isTrue);

      await harness.controller.deleteDevice('phone-one');
      expect(harness.controller.devices, isEmpty);
      expect(harness.store.document!.devices, isEmpty);
    });
  });

  test('new QR pairing starts with an empty device clipboard list', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'dingdong-pairing-test-',
    );
    final MemoryDeviceLinkStore store = MemoryDeviceLinkStore();
    final InMemoryClipboardStore clipboardStore = InMemoryClipboardStore(
      <ClipboardRecord>[_record('existing', '电脑主机列表内容')],
    );
    late _FakeDeviceLinkSession session;
    final DeviceLinkController controller = DeviceLinkController(
      store: store,
      clipboardStore: clipboardStore,
      transferDirectory: directory,
      pwaBaseUrl: Uri.parse('https://relay.example/app/'),
      relayBaseUrl: Uri.parse('https://relay.example'),
      sessionFactory: ({required relayUrl, required room, required secret}) {
        session = _FakeDeviceLinkSession();
        return session;
      },
    );
    addTearDown(() async {
      await controller.shutdown();
      controller.dispose();
      await directory.delete(recursive: true);
    });

    await controller.start();
    final PendingDevicePairing pairing = (await controller.beginPairing())!;
    expect(pairing.url.query, isEmpty);
    expect(pairing.url.fragment, startsWith('pair='));
    expect(session.connectCalls, 1);

    session.connectedValue = true;
    session.emit(
      const DeviceLinkMessageEvent(<String, Object?>{
        'type': 'hello',
        'device': <String, Object?>{
          'id': 'new-phone',
          'name': '测试手机',
          'kind': 'phone',
          'platform': 'ios-pwa',
        },
        'agentNotificationsEnabled': false,
        'vibrationEnabled': true,
      }),
    );
    await _flushEvents();

    expect(controller.pendingPairing, isNull);
    expect(controller.devices.single.name, '测试手机');
    expect(controller.devices.single.autoSendClipboard, isFalse);
    expect(controller.devices.single.receiveAgentNotifications, isFalse);
    expect(
      session.sent.map((Map<String, Object?> value) => value['type']),
      <Object?>['welcome', 'clipboard.snapshot'],
    );
    final Map<String, Object?> snapshot = session.sent.last;
    expect(snapshot['items'], isA<List<Object?>>());
    expect((snapshot['items']! as List<Object?>), isEmpty);
    expect(
      controller.devices.single.sharedClipboardItemIds,
      isEmpty,
      reason: 'Pairing must never authorize pre-connection host history.',
    );
  });

  test(
    'a fresh QR replaces the old room for the same phone identity',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-repairing-test-',
      );
      final LinkedDevice existing = LinkedDevice(
        id: 'same-phone',
        name: '旧手机名称',
        kind: LinkedDeviceKind.phone,
        platform: 'mobile-pwa',
        room: 'old-room-abcdefghijkl',
        secret: _secret,
        autoSendClipboard: false,
        receiveAgentNotifications: true,
        vibrationEnabled: true,
        manuallyDisconnected: false,
        pairedAt: DateTime.utc(2026, 8, 8),
      );
      final MemoryDeviceLinkStore store = MemoryDeviceLinkStore(
        DeviceLinkDocument(
          localDevice: const LocalDeviceIdentity(
            id: 'desktop-one',
            name: 'Studio',
            platform: 'macos',
          ),
          devices: <LinkedDevice>[existing],
        ),
      );
      final List<_FakeDeviceLinkSession> sessions = <_FakeDeviceLinkSession>[];
      final DeviceLinkController controller = DeviceLinkController(
        store: store,
        clipboardStore: InMemoryClipboardStore(),
        transferDirectory: directory,
        pwaBaseUrl: Uri.parse('https://relay.example/app/'),
        relayBaseUrl: Uri.parse('https://relay.example'),
        sessionFactory: ({required relayUrl, required room, required secret}) {
          final _FakeDeviceLinkSession session = _FakeDeviceLinkSession();
          sessions.add(session);
          return session;
        },
      );
      addTearDown(() async {
        await controller.shutdown();
        controller.dispose();
        await directory.delete(recursive: true);
      });

      await controller.start();
      final _FakeDeviceLinkSession oldSession = sessions.single;
      final PendingDevicePairing pairing = (await controller.beginPairing())!;
      final _FakeDeviceLinkSession newSession = sessions.last;
      newSession.connectedValue = true;
      newSession.emit(
        const DeviceLinkMessageEvent(<String, Object?>{
          'type': 'hello',
          'device': <String, Object?>{
            'id': 'same-phone',
            'name': '重新连接的手机',
            'kind': 'phone',
            'platform': 'mobile-pwa',
          },
        }),
      );
      await _flushEvents();

      expect(controller.pendingPairing, isNull);
      expect(controller.devices.single.room, pairing.payload.room);
      expect(controller.devices.single.secret, pairing.payload.secret);
      expect(controller.devices.single.name, '重新连接的手机');
      expect(oldSession.closed, isTrue);
    },
  );

  test(
    'reconnect restores only records previously sent to that device',
    () async {
      final ClipboardRecord shared = _record('shared', '已经发给手机');
      final ClipboardRecord unshared = _record('unshared', '从未发给手机');
      final _Harness harness = await _connectedHarness(
        autoSend: false,
        clipboardRecords: <ClipboardRecord>[shared, unshared],
        sharedClipboardItemIds: const <String>['shared'],
      );
      addTearDown(harness.dispose);

      harness.session.emit(
        const DeviceLinkMessageEvent(<String, Object?>{
          'type': 'hello',
          'device': <String, Object?>{
            'id': 'phone-one',
            'name': 'iPhone',
            'kind': 'phone',
            'platform': 'ios-pwa',
          },
        }),
      );
      await _flushEvents();

      expect(
        harness.session.sent.map((Map<String, Object?> value) => value['type']),
        <Object?>['welcome', 'clipboard.snapshot', 'clipboard.upsert'],
      );
      expect(harness.session.sent[1]['items'], isEmpty);
      final Map<Object?, Object?> item =
          harness.session.sent.last['item']! as Map<Object?, Object?>;
      expect(item['id'], 'shared');
      expect(harness.session.sent.last['snapshot'], isTrue);
    },
  );

  test('reconnect snapshot skips an oversized legacy text item', () async {
    final ClipboardRecord oversized = _record(
      'oversized',
      List<String>.filled(deviceLinkMaximumTextBytes + 1, 'a').join(),
    );
    final ClipboardRecord safe = _record('safe', '仍可恢复的内容');
    final _Harness harness = await _connectedHarness(
      autoSend: false,
      clipboardRecords: <ClipboardRecord>[oversized, safe],
      sharedClipboardItemIds: const <String>['oversized', 'safe'],
    );
    addTearDown(harness.dispose);

    harness.session.emit(
      const DeviceLinkMessageEvent(<String, Object?>{
        'type': 'hello',
        'device': <String, Object?>{
          'id': 'phone-one',
          'name': 'iPhone',
          'kind': 'phone',
          'platform': 'ios-pwa',
        },
      }),
    );
    await _flushEvents();

    expect(
      harness.session.sent.map((Map<String, Object?> value) => value['type']),
      <Object?>['welcome', 'clipboard.snapshot', 'clipboard.upsert'],
    );
    expect(
      (harness.session.sent.last['item']! as Map<Object?, Object?>)['id'],
      'safe',
    );
  });

  test(
    'reconnect hello preserves the desktop route until settings explicitly change it',
    () async {
      final _Harness harness = await _connectedHarness(autoSend: false);
      addTearDown(harness.dispose);
      await harness.controller.setAgentNotifications('phone-one', false);

      harness.session.emit(
        const DeviceLinkMessageEvent(<String, Object?>{
          'type': 'hello',
          'device': <String, Object?>{
            'id': 'phone-one',
            'name': 'iPhone',
            'kind': 'phone',
            'platform': 'ios-pwa',
          },
          'agentNotificationsEnabled': true,
        }),
      );
      await _flushEvents();
      expect(
        harness.controller.devices.single.receiveAgentNotifications,
        isFalse,
      );

      harness.session.emit(
        const DeviceLinkMessageEvent(<String, Object?>{
          'type': 'settings.update',
          'agentNotificationsEnabled': true,
        }),
      );
      await _flushEvents();
      expect(
        harness.controller.devices.single.receiveAgentNotifications,
        isTrue,
      );
    },
  );

  test('reconnect reuses a superseded session handle', () async {
    final _Harness harness = await _connectedHarness(autoSend: false);
    addTearDown(harness.dispose);
    expect(harness.session.connectCalls, 1);

    harness.session.connectedValue = false;
    harness.session.emit(
      const DeviceLinkStatusEvent(DeviceConnectionStatus.disconnected),
    );
    await _flushEvents();
    await harness.controller.reconnect('phone-one');

    expect(harness.session.connectCalls, 2);
    expect(
      harness.store.document!.devices.single.manuallyDisconnected,
      isFalse,
    );
  });

  test(
    'agent state snapshots keep running tasks separate from unread history',
    () async {
      AgentActivity completed = AgentActivity(
        id: 'activity-1',
        source: 'Codex',
        message: '同步已完成',
        startedAt: DateTime.utc(2026, 8, 11, 8),
        completedAt: DateTime.utc(2026, 8, 11, 8, 10),
        unseen: true,
      );
      final AgentTaskRun running = AgentTaskRun(
        id: 'run-2',
        source: 'Codex',
        task: '继续验证手机状态',
        startedAt: DateTime.utc(2026, 8, 11, 8, 11),
      );
      final _Harness harness = await _connectedHarness(
        autoSend: false,
        agentStateProvider: () => (
          activities: <AgentActivity>[completed],
          activeRuns: <AgentTaskRun>[running],
        ),
      );
      addTearDown(harness.dispose);

      await harness.controller.syncAgentState();

      final Map<String, Object?> first = harness.session.sent.single;
      expect(first['type'], 'agent.state');
      expect(
        (first['running'] as List<Object?>).single,
        containsPair('id', 'run-2'),
      );
      expect(
        (first['completed'] as List<Object?>).single,
        allOf(
          containsPair('id', 'activity-1'),
          containsPair('unseen', true),
          containsPair('startedAt', '2026-08-11T08:00:00.000Z'),
          containsPair('completedAt', '2026-08-11T08:10:00.000Z'),
        ),
      );

      completed = completed.seen();
      await harness.controller.syncAgentState();
      expect(
        ((harness.session.sent.last['completed'] as List<Object?>).single
            as Map<String, Object?>)['unseen'],
        isFalse,
      );
    },
  );

  test(
    'maximum Agent snapshot stays inside the encrypted relay frame',
    () async {
      final String oversized = List<String>.filled(5000, '状态').join();
      final AgentConversationTarget target = AgentConversationTarget(
        client: AgentClient.codex,
        workspacePath: '/workspace/${List<String>.filled(600, 'x').join()}',
      );
      final List<AgentActivity> activities = List<AgentActivity>.generate(
        deviceLinkAgentHistoryLimit + 5,
        (int index) => AgentActivity(
          id: 'activity-$index',
          source: oversized,
          message: oversized,
          task: oversized,
          detail: oversized,
          startedAt: DateTime.utc(2026, 8, 11, 8),
          completedAt: DateTime.utc(2026, 8, 11, 9),
          unseen: true,
          conversationTarget: target,
        ),
      );
      final List<AgentTaskRun> runs = List<AgentTaskRun>.generate(
        deviceLinkAgentRunningLimit + 5,
        (int index) => AgentTaskRun(
          id: 'run-$index',
          source: oversized,
          task: oversized,
          startedAt: DateTime.utc(2026, 8, 11, 9),
          conversationTarget: target,
        ),
      );
      final _Harness harness = await _connectedHarness(
        autoSend: false,
        agentStateProvider: () => (activities: activities, activeRuns: runs),
      );
      addTearDown(harness.dispose);

      await harness.controller.syncAgentState();

      final Map<String, Object?> message = harness.session.sent.single;
      expect(
        message['running'],
        isA<List<Object?>>().having(
          (List<Object?> items) => items.length,
          'length',
          deviceLinkAgentRunningLimit,
        ),
      );
      expect(
        message['completed'],
        isA<List<Object?>>().having(
          (List<Object?> items) => items.length,
          'length',
          deviceLinkAgentHistoryLimit,
        ),
      );
      final String envelope = await SecureMessageCodec.fromBase64Url(
        _secret,
      ).seal(message);
      expect(
        () => encodeDeviceLinkRelayFrame(type: 'data', envelope: envelope),
        returnsNormally,
      );
    },
  );

  test(
    'agent Web Push is compact, encrypted, and carries its message id',
    () async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final Completer<Map<String, Object?>> received =
          Completer<Map<String, Object?>>();
      String? method;
      String? path;
      String? authorization;
      ContentType? contentType;
      server.listen((HttpRequest request) async {
        method = request.method;
        path = request.uri.path;
        authorization = request.headers.value(HttpHeaders.authorizationHeader);
        contentType = request.headers.contentType;
        final String body = await utf8.decoder.bind(request).join();
        received.complete(Map<String, Object?>.from(jsonDecode(body) as Map));
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write('{"accepted":true,"pushStatus":201}');
        await request.response.close();
      });
      final _Harness harness = await _connectedHarness(
        autoSend: false,
        relayBaseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      );
      addTearDown(() async {
        await harness.dispose();
        await server.close(force: true);
      });
      final String fullDetail = List<String>.filled(
        1400,
        '"\\\n\t\u0001🚀详细结果',
      ).join();

      await harness.controller.sendAgentCompleted(
        DingRequest(
          message: List<String>.filled(500, '"\\\n🚀摘要').join(),
          detail: fullDetail,
          source: List<String>.filled(40, 'Codex"\\').join(),
        ),
        activity: AgentActivity(
          id: 'activity-1',
          source: 'Codex',
          message: '完成摘要',
          startedAt: DateTime.utc(2026, 8, 8, 7, 59),
          completedAt: DateTime.utc(2026, 8, 8, 8),
          unseen: true,
        ),
        notificationId: 'completion-1',
      );

      final Map<String, Object?> body = await received.future;
      final String envelope = body['envelope']! as String;
      final String messageId = body['messageId']! as String;
      final Map<String, Object?> pushMessage =
          await SecureMessageCodec.fromBase64Url(_secret).open(envelope);
      expect(utf8.encode(envelope).length, lessThanOrEqualTo(3500));
      expect(method, 'POST');
      expect(path, '/v1/push/abcdefghijklmnopqrstuvwx');
      expect(contentType?.mimeType, ContentType.json.mimeType);
      expect(authorization, startsWith('Bearer '));
      expect(pushMessage['id'], messageId);
      expect(pushMessage['activityId'], 'activity-1');
      expect(pushMessage['type'], 'agent.completed');
      expect(pushMessage['startedAt'], '2026-08-08T07:59:00.000Z');
      expect((pushMessage['detail']! as String).endsWith('…'), isTrue);
      expect(
        harness.session.sent.single['detail'],
        fullDetail,
        reason:
            'The connected phone still receives the complete realtime detail.',
      );
    },
  );
}

const String _secret = 'BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc';

Future<_Harness> _connectedHarness({
  required bool autoSend,
  List<ClipboardRecord> clipboardRecords = const <ClipboardRecord>[],
  List<String> sharedClipboardItemIds = const <String>[],
  Uri? relayBaseUrl,
  AgentStateProvider? agentStateProvider,
}) async {
  final Directory directory = await Directory.systemTemp.createTemp(
    'dingdong-device-link-test-',
  );
  final LinkedDevice device = LinkedDevice(
    id: 'phone-one',
    name: 'iPhone',
    kind: LinkedDeviceKind.phone,
    platform: 'ios-pwa',
    room: 'abcdefghijklmnopqrstuvwx',
    secret: _secret,
    autoSendClipboard: autoSend,
    receiveAgentNotifications: true,
    vibrationEnabled: true,
    manuallyDisconnected: false,
    pairedAt: DateTime.utc(2026, 8, 8),
    sharedClipboardItemIds: sharedClipboardItemIds,
  );
  final MemoryDeviceLinkStore store = MemoryDeviceLinkStore(
    DeviceLinkDocument(
      localDevice: const LocalDeviceIdentity(
        id: 'desktop-one',
        name: 'Studio',
        platform: 'macos',
      ),
      devices: <LinkedDevice>[device],
    ),
  );
  final InMemoryClipboardStore clipboardStore = InMemoryClipboardStore(
    clipboardRecords,
  );
  final _FakeDeviceLinkSession session = _FakeDeviceLinkSession();
  final DeviceLinkController controller = DeviceLinkController(
    store: store,
    clipboardStore: clipboardStore,
    transferDirectory: directory,
    pwaBaseUrl: Uri.parse('https://relay.example/app/'),
    relayBaseUrl: relayBaseUrl ?? Uri.parse('https://relay.example'),
    sessionFactory: ({required relayUrl, required room, required secret}) =>
        session,
    agentStateProvider: agentStateProvider,
  );
  await controller.start();
  session.connectedValue = true;
  session.emit(const DeviceLinkStatusEvent(DeviceConnectionStatus.connected));
  await _flushEvents();
  return _Harness(
    controller: controller,
    session: session,
    store: store,
    clipboardStore: clipboardStore,
    directory: directory,
  );
}

ClipboardRecord _record(String id, String content) {
  return ClipboardRecord(
    id: id,
    group: 'Clipboard',
    title: '测试内容',
    content: content,
    tags: const <String>['clipboard', 'text'],
    pinned: false,
    enabled: true,
    activation: 'taskMatch',
    createdAt: DateTime.utc(2026, 8, 8, 8),
    updatedAt: DateTime.utc(2026, 8, 8, 8),
  );
}

Future<void> _flushEvents() async {
  for (var index = 0; index < 5; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var index = 0; index < 100; index += 1) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Timed out waiting for the asynchronous device-link operation.');
}

final class _Harness {
  const _Harness({
    required this.controller,
    required this.session,
    required this.store,
    required this.clipboardStore,
    required this.directory,
  });

  final DeviceLinkController controller;
  final _FakeDeviceLinkSession session;
  final MemoryDeviceLinkStore store;
  final InMemoryClipboardStore clipboardStore;
  final Directory directory;

  Future<void> dispose() async {
    await controller.shutdown();
    controller.dispose();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

final class _FakeDeviceLinkSession implements DeviceLinkSessionHandle {
  final StreamController<DeviceLinkSessionEvent> _events =
      StreamController<DeviceLinkSessionEvent>.broadcast(sync: true);

  final List<Map<String, Object?>> sent = <Map<String, Object?>>[];
  bool connectedValue = false;
  bool closed = false;
  int connectCalls = 0;

  @override
  bool get connected => connectedValue;

  @override
  Stream<DeviceLinkSessionEvent> get events => _events.stream;

  void emit(DeviceLinkSessionEvent event) => _events.add(event);

  @override
  Future<void> connect() async {
    connectCalls += 1;
  }

  @override
  Future<void> send(Map<String, Object?> message) async {
    if (!connectedValue) throw StateError('offline');
    sent.add(message);
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    connectedValue = false;
    await _events.close();
  }
}
