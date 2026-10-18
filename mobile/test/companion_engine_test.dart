import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong_link_protocol/dingdong_link_protocol.dart';
import 'package:dingdong_mobile/link/agent_event.dart';
import 'package:dingdong_mobile/link/companion_engine.dart';
import 'package:dingdong_mobile/link/companion_store.dart';
import 'package:dingdong_mobile/link/relay_peer.dart';
import 'package:flutter_test/flutter_test.dart';

const String _secret = 'q2v9Jx0rTzM8bW1kLs7nPf4aYc6eHd3uGi5oRj2lKwE';
const String _room = 'AbCdEfGhIjKlMnOpQrStUv';

/// Plays the relay plus the desktop host for one peer socket.
final class FakeSocket implements LinkSocket {
  final StreamController<dynamic> _incoming = StreamController<dynamic>();
  final List<Map<String, Object?>> sent = <Map<String, Object?>>[];
  final SecureMessageCodec codec = SecureMessageCodec.fromBase64Url(_secret);
  @override
  int? closeCode;
  @override
  String? closeReason;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  void add(String frame) {
    final Map<String, Object?> decoded = Map<String, Object?>.from(
      jsonDecode(frame) as Map,
    );
    unawaited(
      codec
          .open(decoded['payload']! as String)
          .then((Map<String, Object?> message) => sent.add(message)),
    );
  }

  void relay(String event) => _incoming.add(
    jsonEncode(<String, Object?>{'type': 'relay', 'event': event}),
  );

  Future<void> host(Map<String, Object?> message) async => _incoming.add(
    encodeDeviceLinkRelayFrame(
      type: 'data',
      envelope: await codec.seal(message),
    ),
  );

  void drop({int? code, String? reason}) {
    closeCode = code;
    closeReason = reason;
    unawaited(_incoming.close());
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (!_incoming.isClosed) await _incoming.close();
  }

  List<String> get types => <String>[
    for (final Map<String, Object?> m in sent) m['type']! as String,
  ];
}

final class RecordingNotifier implements AgentNotifier {
  final List<AgentEvent> shown = <AgentEvent>[];
  @override
  Future<void> show(AgentEvent event, {required String hostName}) async =>
      shown.add(event);
}

String _link() =>
    'https://dingdong.xn--m8txu.com/app/#pair=${DevicePairingPayload(room: _room, secret: _secret, hostId: 'host-1', hostName: '工作电脑', relayUrl: Uri.parse('https://dingdong.xn--m8txu.com')).encode()}';

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  late Directory temp;
  late List<FakeSocket> sockets;
  late List<Map<String, Object?>> emitted;
  late RecordingNotifier notifier;
  late CompanionEngine engine;

  Future<CompanionEngine> build() async {
    final CompanionStore store = await CompanionStore.load(
      File('${temp.path}/companion.json'),
    );
    return CompanionEngine(
      store: store,
      notifier: notifier,
      downloadDirectory: Directory('${temp.path}/downloads'),
      emit: emitted.add,
      connector: (Uri uri) async {
        expect(uri.queryParameters['side'], 'peer');
        expect(uri.path, '/v1/rooms/$_room');
        final FakeSocket socket = FakeSocket();
        sockets.add(socket);
        return socket;
      },
    )..start();
  }

  Future<FakeSocket> pairAndWelcome() async {
    await engine.handleCommand(<String, Object?>{
      'cmd': 'pair',
      'link': _link(),
      'deviceName': 'Xiaomi 13 Ultra',
    });
    await _settle();
    final FakeSocket socket = sockets.last;
    socket
      ..relay('ready')
      ..relay('host_joined');
    await _settle();
    await socket.host(<String, Object?>{
      'type': 'welcome',
      'host': <String, Object?>{'name': '工作电脑'},
    });
    await _settle();
    return socket;
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dingdong_mobile_test');
    sockets = <FakeSocket>[];
    emitted = <Map<String, Object?>>[];
    notifier = RecordingNotifier();
    engine = await build();
  });

  tearDown(() async {
    await engine.dispose();
    await temp.delete(recursive: true);
  });

  test('pairs, says hello as an Android phone and pins the relay', () async {
    final FakeSocket socket = await pairAndWelcome();
    expect(socket.types, <String>['hello', 'settings.update']);
    final Map<String, Object?> device =
        socket.sent.first['device']! as Map<String, Object?>;
    expect(device['kind'], 'phone');
    expect(device['platform'], 'android');
    expect(device['name'], 'Xiaomi 13 Ultra');
    // No fileTransferVersion: the desktop then uses the v1 file messages.
    expect(socket.sent.first.containsKey('fileTransferVersion'), isFalse);
    expect(socket.sent[1]['transportPreference'], 'serviceRelay');
    final Map<String, Object?> snapshot = engine.snapshot();
    final Map<String, Object?> computer =
        (snapshot['computers']! as List).single as Map<String, Object?>;
    expect(computer['state'], 'connected');
  });

  test('reminders use their kind channel and silent ones stay quiet', () async {
    final FakeSocket socket = await pairAndWelcome();
    Future<void> remind(String id, String kind, {bool silent = false}) =>
        socket.host(<String, Object?>{
          'type': 'agent.completed',
          'id': id,
          'notificationKind': kind,
          'source': 'Claude Code',
          'summary': '测试',
          if (silent) 'silent': true,
        });
    await remind('a', 'completion');
    await remind('b', 'attention');
    await remind('c', 'completion', silent: true);
    await remind('a', 'completion');
    await _settle();
    expect(
      notifier.shown.map((AgentEvent e) => e.kind.channelId).toList(),
      <String>['agent_completion_v2', 'agent_attention_v2'],
    );
    final Map<String, Object?> computer =
        (engine.snapshot()['computers']! as List).single
            as Map<String, Object?>;
    expect((computer['events']! as List).length, 3);
  });

  test('agent.state history never notifies', () async {
    final FakeSocket socket = await pairAndWelcome();
    await socket.host(<String, Object?>{
      'type': 'agent.state',
      'running': <Object?>[
        <String, Object?>{'id': 'r1', 'task': '迁移', 'source': 'Codex'},
      ],
      'completed': <Object?>[
        <String, Object?>{'id': 'old', 'summary': '早先完成', 'unseen': false},
      ],
    });
    await _settle();
    expect(notifier.shown, isEmpty);
    final Map<String, Object?> computer =
        (engine.snapshot()['computers']! as List).single
            as Map<String, Object?>;
    expect((computer['runs']! as List).single, containsPair('task', '迁移'));
    expect((computer['events']! as List).single, containsPair('unseen', false));
  });

  test('a reminder still alerts when agent.state listed it first', () async {
    // The real desktop broadcasts agent.state (with the new activity) just
    // before agent.completed carrying the same id.
    final FakeSocket socket = await pairAndWelcome();
    final Map<String, Object?> activity = <String, Object?>{
      'id': 'activity-1',
      'activityId': 'activity-1',
      'notificationKind': 'attention',
      'summary': '需要确认',
      'unseen': true,
    };
    await socket.host(<String, Object?>{
      'type': 'agent.state',
      'running': <Object?>[],
      'completed': <Object?>[activity],
    });
    await socket.host(<String, Object?>{
      'type': 'agent.completed',
      ...activity,
    });
    await _settle();
    expect(notifier.shown.single.id, 'activity-1');
    expect(notifier.shown.single.kind, AgentKind.attention);
  });

  test('clipboard items arrive and are dropped while offline', () async {
    final FakeSocket socket = await pairAndWelcome();
    await socket.host(<String, Object?>{
      'type': 'clipboard.snapshot',
      'items': <Object?>[],
    });
    await socket.host(<String, Object?>{
      'type': 'clipboard.upsert',
      'item': <String, Object?>{
        'id': 'i1',
        'title': '命令',
        'kind': 'command',
        'content': 'flutter test',
        'sources': <String>['终端'],
      },
    });
    await _settle();
    await engine.handleCommand(<String, Object?>{
      'cmd': 'copy',
      'room': _room,
      'itemId': 'i1',
    });
    expect(
      emitted.where((Map<String, Object?> e) => e['kind'] == 'copy').single,
      containsPair('content', 'flutter test'),
    );
    socket.relay('host_left');
    await _settle();
    final Map<String, Object?> computer =
        (engine.snapshot()['computers']! as List).single
            as Map<String, Object?>;
    expect(computer['items'], isEmpty);
    expect(computer['state'], 'waiting');
  });

  test('sends text and a file with the v1 transfer messages', () async {
    final FakeSocket socket = await pairAndWelcome();
    await engine.handleCommand(<String, Object?>{
      'cmd': 'sendText',
      'room': _room,
      'text': '你好电脑',
    });
    final File file = File('${temp.path}/note.bin')
      ..writeAsBytesSync(List<int>.generate(70000, (int i) => i % 251));
    await engine.handleCommand(<String, Object?>{
      'cmd': 'sendFile',
      'room': _room,
      'path': file.path,
      'name': 'note.bin',
    });
    await _settle();
    expect(socket.types.skip(2).toList(), <String>[
      'clipboard.create',
      'file.start',
      'file.chunk',
      'file.chunk',
      'file.chunk',
      'file.end',
    ]);
    expect(socket.sent[2]['content'], '你好电脑');
    expect(socket.sent[3]['size'], 70000);
    final List<int> rebuilt = <int>[
      for (final Map<String, Object?> m in socket.sent)
        if (m['type'] == 'file.chunk') ...base64Decode(m['data']! as String),
    ];
    expect(rebuilt, file.readAsBytesSync());
  });

  test('downloads a requested file and hands it to the UI', () async {
    final FakeSocket socket = await pairAndWelcome();
    await engine.handleCommand(<String, Object?>{
      'cmd': 'requestFile',
      'room': _room,
      'itemId': 'f1',
    });
    await _settle();
    expect(socket.sent.last, containsPair('type', 'file.request'));
    await socket.host(<String, Object?>{
      'type': 'file.start',
      'transferId': 't1',
      'itemId': 'f1',
      'name': 'report.txt',
      'size': 5,
    });
    await socket.host(<String, Object?>{
      'type': 'file.chunk',
      'transferId': 't1',
      'index': 0,
      'data': base64Encode(utf8.encode('hello')),
    });
    await socket.host(<String, Object?>{
      'type': 'file.end',
      'transferId': 't1',
    });
    await _settle();
    final Map<String, Object?> done = emitted.lastWhere(
      (Map<String, Object?> e) => e['kind'] == 'downloaded',
    );
    expect(done['name'], 'report.txt');
    expect(File(done['path']! as String).readAsStringSync(), 'hello');
  });

  test('reconnects after a drop but not after being replaced', () async {
    final FakeSocket first = await pairAndWelcome();
    first.drop();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(sockets.length, 2);
    sockets.last.drop(code: 1008, reason: 'Replaced by a newer connection');
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    expect(sockets.length, 2);
    final Map<String, Object?> computer =
        (engine.snapshot()['computers']! as List).single
            as Map<String, Object?>;
    expect(computer['state'], 'replaced');
  });

  test('pairings and history survive a service restart', () async {
    final FakeSocket socket = await pairAndWelcome();
    await socket.host(<String, Object?>{
      'type': 'agent.completed',
      'id': 'persist',
      'notificationKind': 'attention',
    });
    await _settle();
    await engine.dispose();
    engine = await build();
    await _settle();
    expect(sockets.length, 2, reason: 'the restored pairing reconnects');
    final Map<String, Object?> computer =
        (engine.snapshot()['computers']! as List).single
            as Map<String, Object?>;
    expect(computer['hostName'], '工作电脑');
    expect((computer['events']! as List).single, containsPair('id', 'persist'));
  });
}
