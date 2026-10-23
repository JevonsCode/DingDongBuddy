import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/reminder_audio_importer.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/data/voice_catalog_service.dart';
import 'package:dingdong/features/settings/domain/voice_catalog.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:dingdong/features/settings/ui/voice_catalog_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const attachment = 'https://github.com/user-attachments/files/1234/chime.wav';
Map<String, dynamic> issue({String? body}) => {
  'number': 7,
  'state': 'open',
  'title': '[Voice] Hello 世界 🎶',
  'body':
      body ??
      '### Description\n\n A "gentle" chime. \\ hello\n\n### Audio\n\n[chime.wav]($attachment)\n\n### License\n\nCC0-1.0\n\n### Source\n\nOriginal synthesis.\n\n### Rights confirmation\n\n- [x] I own the rights.\n',
  'html_url': 'https://github.com/$voiceCatalogRepository/issues/7',
  'user': {'login': 'JevonsCode', 'id': 36203025},
  'created_at': '2026-10-23T01:02:03Z',
  'updated_at': '2026-10-23T02:02:03Z',
  'labels': [
    {'name': voiceCatalogLabel},
  ],
  'reactions': {'+1': 4, '-1': 2},
};
Uint8List wave({int frames = 24000}) {
  final bytes = Uint8List(44 + frames * 2);
  final data = ByteData.sublistView(bytes);
  void tag(int at, String text) => bytes.setRange(at, at + 4, text.codeUnits);
  tag(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 8000, Endian.little);
  data.setUint32(28, 16000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, frames * 2, Endian.little);
  return bytes;
}

Future<String> hash(List<int> value) async => (await Sha256().hash(
  value,
)).bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
Future<Map<String, dynamic>> approval(
  CatalogVoice voice,
  Uint8List bytes,
) async => {
  'user': {'id': 36203025},
  'author_association': 'OWNER',
  'body': jsonEncode({
    'dingdongVoiceApproval': 1,
    'issue': 7,
    'metadataSha256': await hash(utf8.encode(voice.metadataJson)),
    'audioSha256': await hash(bytes),
  }),
};

void main() {
  test(
    'shared JavaScript/Dart fixture canonicalization and PCM hash agree',
    () async {
      final fixture =
          jsonDecode(
                await File(
                  'test/fixtures/voices/approval-v1.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      final voice = CatalogVoice.fromIssue(
        fixture['issue'] as Map<String, dynamic>,
      )!;
      expect(voice.metadataJson, fixture['metadataJson']);
      expect(
        await hash(utf8.encode(voice.metadataJson)),
        fixture['metadataSha256'],
      );
      expect(
        await approvedAudioHash(voice, [fixture['approval']]),
        fixture['audioSha256'],
      );
      final bytes = await File(
        'test/fixtures/voices/one-second-pcm.wav',
      ).readAsBytes();
      expect(await hash(bytes), fixture['audioSha256']);
      expect(validateCatalogWave(bytes), 1);
    },
  );
  test(
    'canonical fields, API identity/time/votes and Markdown stay plain text',
    () {
      final voice = CatalogVoice.fromIssue(issue())!;
      expect(voice.title, 'Hello 世界 🎶');
      expect(voice.author, 'JevonsCode');
      expect(voice.likes, 4);
      expect(voice.createdAt, DateTime.utc(2026, 10, 23, 1, 2, 3));
      expect(jsonDecode(voice.metadataJson), [
        '[Voice] Hello 世界 🎶',
        'A "gentle" chime. \\ hello',
        attachment,
        'Original synthesis.',
        'CC0-1.0',
        '- [x] I own the rights.',
      ]);
    },
  );
  test(
    'rejects unsafe URLs, closed issues, PRs, wrong repo and unchecked rights',
    () {
      for (final url in [
        'http://github.com/user-attachments/files/1234/chime.wav',
        '$attachment?token=x',
        '$attachment#x',
        'https://evil.test/chime.wav',
        'https://github.com.evil.test/user-attachments/files/1234/chime.wav',
        'https://user@github.com/user-attachments/files/1234/chime.wav',
        'https://github.com:443/user-attachments/files/1234/chime.wav',
        'https://github.com/user-attachments/files/1234/script.exe',
      ]) {
        expect(
          CatalogVoice.fromIssue(
            issue(
              body: (issue()['body'] as String).replaceAll(attachment, url),
            ),
          ),
          isNull,
          reason: url,
        );
      }
      expect(CatalogVoice.fromIssue({...issue(), 'state': 'closed'}), isNull);
      expect(CatalogVoice.fromIssue({...issue(), 'pull_request': {}}), isNull);
      expect(CatalogVoice.fromIssue({...issue(), 'labels': []}), isNull);
      expect(
        CatalogVoice.fromIssue({
          ...issue(),
          'html_url': 'https://github.com/evil/repo/issues/7',
        }),
        isNull,
      );
      expect(
        CatalogVoice.fromIssue(
          issue(body: (issue()['body'] as String).replaceAll('[x]', '[ ]')),
        ),
        isNull,
      );
    },
  );
  test('duplicate fields/URLs fail and CRLF normalization matches the web', () {
    final body = issue()['body'] as String;
    expect(
      CatalogVoice.fromIssue(issue(body: '$body\n### Description\nOther')),
      isNull,
    );
    expect(
      CatalogVoice.fromIssue(
        issue(
          body: body.replaceAll(
            '[chime.wav]($attachment)',
            '$attachment $attachment',
          ),
        ),
      ),
      isNull,
    );
    expect(
      CatalogVoice.fromIssue(
        issue(body: body.replaceAll('CC0-1.0', '_No response_')),
      ),
      isNull,
    );
    expect(
      CatalogVoice.fromIssue(
        issue(body: body.replaceAll('\n', '\r\n')),
      )!.metadataJson,
      CatalogVoice.fromIssue(issue())!.metadataJson,
    );
  });
  test(
    'public 3-second limit independent of unchanged local 15-second limit',
    () {
      expect(validateCatalogWave(wave()), 3);
      expect(
        () => validateCatalogWave(wave(frames: 24001)),
        throwsFormatException,
      );
      expect(() => validateWave(wave(frames: 120000)), returnsNormally);
      expect(() => validateWave(wave(frames: 120001)), throwsFormatException);
    },
  );
  test(
    'rejects forged rate, partial frames, RIFF mismatch and duplicate chunks',
    () {
      final rate = wave();
      ByteData.sublistView(rate).setUint32(28, 999999, Endian.little);
      expect(() => validateCatalogWave(rate), throwsFormatException);
      final riff = wave();
      ByteData.sublistView(riff).setUint32(4, 1, Endian.little);
      expect(() => validateCatalogWave(riff), throwsFormatException);
      final dup = Uint8List.fromList([...wave(), ...wave().sublist(12, 36)]);
      ByteData.sublistView(dup).setUint32(4, dup.length - 8, Endian.little);
      expect(() => validateCatalogWave(dup), throwsFormatException);
      final partial = Uint8List.fromList([...wave(frames: 1), 0, 0]);
      ByteData.sublistView(
        partial,
      ).setUint32(4, partial.length - 8, Endian.little);
      ByteData.sublistView(partial).setUint32(40, 3, Endian.little);
      expect(() => validateCatalogWave(partial), throwsFormatException);
    },
  );
  test('fmt18 extension must be empty, matching browser and review helper', () {
    final original = wave();
    final extended = Uint8List.fromList([
      ...original.sublist(0, 36),
      0,
      0,
      ...original.sublist(36),
    ]);
    final view = ByteData.sublistView(extended);
    view.setUint32(4, extended.length - 8, Endian.little);
    view.setUint32(16, 18, Endian.little);
    expect(validateCatalogWave(extended), 3);
    view.setUint16(36, 1, Endian.little);
    expect(() => validateCatalogWave(extended), throwsFormatException);
  });
  test(
    'owner approval binds current fields and cannot be forged by body claims',
    () async {
      final voice = CatalogVoice.fromIssue(issue())!;
      final comment = await approval(voice, wave());
      expect(await approvedAudioHash(voice, [comment]), await hash(wave()));
      expect(
        await approvedAudioHash(voice, [
          {
            ...comment,
            'user': {'id': 1},
          },
        ]),
        isNull,
      );
      expect(
        await approvedAudioHash(voice, [
          {...comment, 'author_association': 'CONTRIBUTOR'},
        ]),
        isNull,
      );
      final changedSource = CatalogVoice.fromIssue(
        issue(
          body: (issue()['body'] as String).replaceAll(
            'Original synthesis.',
            'Other source.',
          ),
        ),
      )!;
      expect(await approvedAudioHash(changedSource, [comment]), isNull);
      expect(
        await approvedAudioHash(voice, [
          {...comment, 'body': '🕵🏻‍♀️[DOT]\n${comment['body']}'},
        ]),
        await hash(wave()),
      );
      expect(
        await approvedAudioHash(voice, [
          {...comment, 'body': 'Other prefix\n${comment['body']}'},
        ]),
        isNull,
      );
      final altered = CatalogVoice.fromIssue({
        ...issue(),
        'title': 'Different',
      })!;
      expect(await approvedAudioHash(altered, [comment]), isNull);
      final rights = CatalogVoice.fromIssue(
        issue(
          body: (issue()['body'] as String).replaceAll(
            'I own the rights.',
            'Other claim.',
          ),
        ),
      )!;
      expect(await approvedAudioHash(rights, [comment]), isNull);
    },
  );
  test(
    'API pages cached; exact Issue lookup rejects arbitrary hosts before request',
    () async {
      var calls = 0;
      final service = VoiceCatalogService(
        clientFactory: () => _Client((uri) {
          calls++;
          return _Response.json(
            uri.path.endsWith('/issues/7') ? issue() : [issue()],
          );
        }),
      );
      expect((await service.load()).voices.single.number, 7);
      await service.load();
      expect(calls, 1);
      await service.load(refresh: true);
      expect(calls, 2);
      expect(
        (await service.findIssue(
          'https://github.com/$voiceCatalogRepository/issues/7',
        )).number,
        7,
      );
      await expectLater(
        service.findIssue('https://evil.test/issues/7'),
        throwsFormatException,
      );
      expect(calls, 3);
    },
  );
  test(
    'subscription revalidates approval, pins bytes and persists provenance',
    () async {
      final voice = CatalogVoice.fromIssue(issue())!;
      final comment = await approval(voice, wave());
      final root = await Directory.systemTemp.createTemp('voice-catalog-');
      addTearDown(() => root.delete(recursive: true));
      final service = VoiceCatalogService(
        clientFactory: () => _Client((uri) {
          if (uri.path.endsWith('/comments')) return _Response.json([comment]);
          if (uri.host == 'github.com') return _Response(wave());
          return _Response.json(issue());
        }),
      );
      final audio = await service.subscribe(voice, root);
      expect(await File(audio.path).readAsBytes(), wave());
      expect(audio.sourceIssue, voice.issueUrl.toString());
      expect(audio.sourceAuthor, voice.author);
      expect(audio.sourceLicense, voice.license);
      expect(audio.sourceAttribution, voice.source);
      expect(audio.audioSha256, await hash(wave()));
      expect(audio.metadataSha256, await hash(utf8.encode(voice.metadataJson)));
      expect((await service.subscribe(voice, root)).path, audio.path);
      expect(await root.list().length, 1);
      final rules = NotificationRules(audioLibrary: [audio]);
      expect(
        NotificationRules.parse(rules.encode()).audioLibrary.single,
        audio,
      );
    },
  );
  test(
    'unapproved/changed bytes never written and unsafe redirects rejected',
    () async {
      final voice = CatalogVoice.fromIssue(issue())!;
      final comment = await approval(voice, wave());
      final root = await Directory.systemTemp.createTemp(
        'voice-catalog-reject-',
      );
      addTearDown(() => root.delete(recursive: true));
      for (final kind in ['unapproved', 'hash', 'redirect']) {
        final service = VoiceCatalogService(
          clientFactory: () => _Client((uri) {
            if (uri.path.endsWith('/comments')) {
              return _Response.json(kind == 'unapproved' ? [] : [comment]);
            }
            if (uri.host == 'github.com') {
              return kind == 'redirect'
                  ? _Response(
                      [],
                      statusCode: 302,
                      location: 'http://127.0.0.1/private',
                    )
                  : _Response(wave(frames: 100));
            }
            return _Response.json(issue());
          }),
        );
        await expectLater(
          service.subscribe(voice, root),
          throwsFormatException,
          reason: kind,
        );
        expect(await root.list().length, 0);
      }
    },
  );
  test(
    'later approval pages supersede old hashes and incomplete pagination fails closed',
    () async {
      final voice = CatalogVoice.fromIssue(issue())!;
      final bytes = wave(frames: 100);
      final oldApproval = await approval(voice, wave());
      final newApproval = await approval(voice, bytes);
      final root = await Directory.systemTemp.createTemp('voice-pagination-');
      addTearDown(() => root.delete(recursive: true));
      for (final incomplete in [false, true]) {
        var downloads = 0;
        final service = VoiceCatalogService(
          clientFactory: () => _Client((uri) {
            if (uri.path.endsWith('/comments')) {
              if (incomplete || uri.queryParameters['page'] == '1') {
                return _Response.json([
                  oldApproval,
                  ...List.generate(99, (_) => {'body': 'discussion'}),
                ]);
              }
              return _Response.json([newApproval]);
            }
            if (uri.host == 'github.com') {
              downloads++;
              return _Response(bytes);
            }
            return _Response.json(issue());
          }),
        );
        if (incomplete) {
          await expectLater(
            service.subscribe(voice, root),
            throwsFormatException,
          );
          expect(downloads, 0);
        } else {
          final audio = await service.subscribe(voice, root);
          expect(audio.audioSha256, await hash(bytes));
          expect(downloads, 1);
        }
      }
    },
  );
  testWidgets(
    'subscribe adds a picker choice without selecting it; unsubscribe preserves active files',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final voice = CatalogVoice.fromIssue(issue())!;
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('voice-catalog-ui-'),
      ))!;
      addTearDown(() => tester.runAsync(() => root.delete(recursive: true)));
      final model = SettingsViewModel(
        SettingsRepository(MemoryPreferencesBackend()),
      );
      await model.load();
      addTearDown(model.dispose);
      final before = model.settings.reminderProfiles
          .map((v) => v.toJson())
          .toList();
      final file = File('${root.path}/subscribed.wav');
      await tester.runAsync(() => file.writeAsBytes(wave()));
      final service = _WidgetCatalog(
        voice,
        ReminderAudio(
          name: voice.title,
          path: file.path,
          sourceIssue: voice.issueUrl.toString(),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceCatalogDialog(
              viewModel: model,
              service: service,
              directory: root,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hello 世界 🎶'), findsOneWidget);
      await tester.tap(find.text('Subscribe'));
      await tester.pumpAndSettle();
      expect(model.settings.notificationRules.audioLibrary, hasLength(1));
      expect(service.subscribeCalls, 1);
      expect(
        model.settings.reminderProfiles.map((v) => v.toJson()).toList(),
        before,
      );
      final path = model.settings.notificationRules.audioLibrary.single.path;
      await tester.tap(find.text('Unsubscribe'));
      await tester.pumpAndSettle();
      expect(model.settings.notificationRules.audioLibrary, isEmpty);
      expect(await tester.runAsync(() => File(path).exists()), true);
      expect(
        model.settings.reminderProfiles.map((v) => v.toJson()).toList(),
        before,
      );
    },
  );
  testWidgets(
    'repeated subscribe is single-flight and closing cancels registration',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final voice = CatalogVoice.fromIssue(issue())!;
      final model = SettingsViewModel(
        SettingsRepository(MemoryPreferencesBackend()),
      );
      await model.load();
      addTearDown(model.dispose);
      final pending = Completer<ReminderAudio>();
      final service = _WidgetCatalog(
        voice,
        ReminderAudio(
          name: voice.title,
          path: '/tmp/inert-catalog-test.wav',
          sourceIssue: voice.issueUrl.toString(),
        ),
        pending: pending,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => VoiceCatalogDialog(
                    viewModel: model,
                    service: service,
                    directory: Directory('/tmp'),
                  ),
                ),
                child: const Text('Open catalog'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open catalog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subscribe'));
      await tester.tap(find.text('Subscribe'));
      await tester.pump();
      expect(service.subscribeCalls, 1);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(VoiceCatalogDialog), findsNothing);
      pending.complete(service.audio);
      await tester.pumpAndSettle();
      expect(model.settings.notificationRules.audioLibrary, isEmpty);
      expect(find.text('Open catalog'), findsOneWidget);
    },
  );
  testWidgets(
    '64 saved subscriptions scroll at small height without hiding dialog controls',
    (tester) async {
      tester.view.physicalSize = const Size(700, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final voice = CatalogVoice.fromIssue(issue())!;
      final model = SettingsViewModel(
        SettingsRepository(MemoryPreferencesBackend()),
      );
      await model.load();
      addTearDown(model.dispose);
      final saved = List.generate(
        64,
        (i) => ReminderAudio(
          name: 'Saved voice $i',
          path: '/tmp/inert-voice-$i.wav',
          sourceIssue:
              'https://github.com/$voiceCatalogRepository/issues/${i + 1}',
          sourceAuthor: 'author',
          sourceLicense: 'CC0-1.0',
          sourceAttribution: 'Original synthesis.',
        ),
      );
      await model.setNotificationRules(
        model.settings.notificationRules.copyWith(audioLibrary: saved),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceCatalogDialog(
              viewModel: model,
              service: _WidgetCatalog(voice, saved.first),
              directory: Directory('/tmp'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subscribed on this device'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Close').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.byType(ListView).last);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Close').hitTestable(), findsOneWidget);
      expect(find.text('Saved voice 63').hitTestable(), findsOneWidget);
      expect(model.settings.notificationRules.audioLibrary, hasLength(64));
    },
  );
  test('rate limits and oversized responses fail explicitly', () async {
    for (final response in [
      _Response([], statusCode: 429),
      _Response([], contentLength: 999999999),
    ]) {
      final service = VoiceCatalogService(
        clientFactory: () => _Client((_) => response),
      );
      await expectLater(
        service.load(),
        throwsA(anyOf(isA<HttpException>(), isA<FormatException>())),
      );
    }
  });
}

class _Client implements HttpClient {
  _Client(this.respond);
  final _Response Function(Uri) respond;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(respond(url));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  _Request(this.response);
  final _Response response;
  @override
  final HttpHeaders headers = _Headers();
  @override
  Future<HttpClientResponse> close() async => response;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  _Headers([this.location]);
  final String? location;
  @override
  String? value(String name) =>
      name == HttpHeaders.locationHeader ? location : null;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(
    this.bytes, {
    this.statusCode = 200,
    int? contentLength,
    String? location,
  }) : contentLength = contentLength ?? bytes.length,
       headers = _Headers(location);
  factory _Response.json(Object value) =>
      _Response(utf8.encode(jsonEncode(value)));
  final List<int> bytes;
  @override
  final int statusCode;
  @override
  final int contentLength;
  @override
  final HttpHeaders headers;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable([bytes]).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _WidgetCatalog implements VoiceCatalogGateway {
  _WidgetCatalog(this.voice, this.audio, {this.pending});
  final CatalogVoice voice;
  final ReminderAudio audio;
  final Completer<ReminderAudio>? pending;
  int subscribeCalls = 0;
  @override
  Future<VoiceCatalogPage> load({int page = 1, bool refresh = false}) async =>
      VoiceCatalogPage([voice]);
  @override
  Future<CatalogVoice> findIssue(String link) async => voice;
  @override
  Future<ReminderAudio> subscribe(
    CatalogVoice voice,
    Directory directory,
  ) async {
    subscribeCalls++;
    final waiting = pending;
    if (waiting != null) return waiting.future;
    return audio;
  }
}
