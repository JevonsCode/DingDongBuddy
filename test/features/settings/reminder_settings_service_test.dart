import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dingdong/features/agent_api/data/agent_router.dart';
import 'package:dingdong/features/agent_api/data/ding_request.dart';
import 'package:dingdong/features/agent_api/data/http_request_data.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/reminder_audio_importer.dart';
import 'package:dingdong/features/settings/data/reminder_settings_service.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late SettingsRepository repository;
  late ReminderSettingsService service;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('jvs-reminders-');
    repository = SettingsRepository(MemoryPreferencesBackend());
    service = ReminderSettingsService(
      repository,
      ReminderAudioImporter(Directory('${root.path}/sounds')),
    );
  });
  tearDown(() async => root.delete(recursive: true));
  test(
    'concurrent patches persist both profiles and preserve defaults',
    () async {
      await Future.wait([
        service.call({'action': 'upsert', 'id': 'error', 'name': 'Error'}),
        service.call({'action': 'upsert', 'id': 'success', 'name': 'Success'}),
      ]);
      await service.call({'action': 'upsert', 'id': 'error', 'color': 'blue'});
      final settings = await repository.load();
      expect(settings.reminderProfiles.map((x) => x.id), [
        'completion',
        'attention',
        'error',
        'success',
      ]);
      expect(settings.reminderProfile('error')!.name, 'Error');
      expect(settings.reminderProfile('error')!.color.name, 'blue');
      await expectLater(
        service.call({
          'action': 'upsert',
          'id': 'attention',
          'kind': 'completion',
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'copies real PCM WAV bytes and keeps shared audio after profile deletion',
    () async {
      final source = File('${root.path}/source.wav');
      await source.writeAsBytes(wave());
      await service.call({
        'action': 'importSound',
        'path': source.path,
        'name': 'Short chime',
      });
      final path =
          (await repository.load()).notificationRules.audioLibrary.single.path;
      await source.delete();
      expect(await File(path).exists(), true);
      for (final id in ['a', 'b']) {
        await service.call({
          'action': 'upsert',
          'id': id,
          'name': id,
          'sound': 'custom',
          'customSoundPath': path,
          'color': 'green',
        });
      }
      await service.call({'action': 'delete', 'id': 'a'});
      expect(
        (await repository.load()).reminderProfile('b')!.customSoundPath,
        path,
      );
      expect(await File(path).exists(), true);
      await expectLater(
        service.call({
          'action': 'upsert',
          'id': 'bad',
          'name': 'Bad',
          'sound': 'custom',
          'customSoundPath': '/unimported.wav',
        }),
        throwsFormatException,
      );
    },
  );
  test('rejects non-audio, incomplete, empty and long WAV files', () {
    expect(
      () => validateWave(Uint8List.fromList(utf8.encode('not audio'))),
      throwsFormatException,
    );
    expect(() => validateWave(wave().sublist(0, 50)), throwsFormatException);
    expect(() => validateWave(wave(seconds: 16)), throwsFormatException);
    expect(() => validateWave(wave(seconds: 0)), throwsFormatException);
  });
  test('loopback API lists, patches and dispatches explicit profiles', () async {
    final delivered = <DingRequest>[];
    final router = AgentRouter(
      reminderSettings: service.call,
      onDing: delivered.add,
    );
    final saved = await router.route(
      HttpRequestData(
        method: 'POST',
        uri: '/settings/reminders',
        body:
            '{"action":"upsert","id":"error","name":"Error","kind":"attention"}',
      ),
    );
    expect(saved.statusCode, 200);
    final response = await router.route(
      HttpRequestData(
        method: 'POST',
        uri: '/ding',
        body: '{"message":"Failed","reminderId":"error"}',
      ),
    );
    expect(response.statusCode, 200);
    expect(delivered.single.reminderId, 'error');
    expect(delivered.single.notificationKind.apiValue, 'attention');
    final unknown = await router.route(
      HttpRequestData(
        method: 'POST',
        uri: '/ding',
        body: '{"reminderId":"missing"}',
      ),
    );
    expect(unknown.statusCode, 400);
    expect(delivered.length, 1);
  });
}

/// A real PCM WAV with silent samples, used only as a deterministic test file.
Uint8List wave({int seconds = 1}) {
  const rate = 8000;
  final length = rate * seconds;
  final bytes = Uint8List(44 + length);
  final data = ByteData.sublistView(bytes);
  void tag(int at, String value) => bytes.setRange(at, at + 4, value.codeUnits);
  tag(0, 'RIFF');
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  tag(36, 'data');
  data.setUint32(4, bytes.length - 8, Endian.little);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate, Endian.little);
  data.setUint16(32, 1, Endian.little);
  data.setUint16(34, 8, Endian.little);
  data.setUint32(40, length, Endian.little);
  return bytes;
}
