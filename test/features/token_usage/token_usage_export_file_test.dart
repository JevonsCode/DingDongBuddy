import 'dart:io';

import 'package:dingdong/platform/file_selector_token_usage_export.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/file_selector');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory temporary;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('dingdong-token-export-');
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await temporary.delete(recursive: true);
  });

  test('save dialog writes exact UTF-8 CSV at the chosen path', () async {
    final selected = File(path.join(temporary.path, '我的统计,2026.csv'));
    MethodCall? dialog;
    messenger.setMockMethodCallHandler(channel, (call) async {
      dialog = call;
      return selected.path;
    });
    const contents = 'date,source,total_tokens\r\n2026-01-01,codex,12345\r\n';
    expect(
      await saveTokenUsageCsv(
        contents: contents,
        suggestedName: 'dingdong-token-usage-2026-codex.csv',
        confirmButtonText: '导出 CSV',
        fileTypeLabel: 'CSV 文件',
      ),
      isTrue,
    );
    expect(dialog!.method, 'getSavePath');
    final arguments = dialog!.arguments as Map<Object?, Object?>;
    expect(arguments['suggestedName'], 'dingdong-token-usage-2026-codex.csv');
    expect(arguments['confirmButtonText'], '导出 CSV');
    expect(
      (arguments['acceptedTypeGroups'] as List).single,
      containsPair('extensions', ['csv']),
    );
    expect(await selected.readAsString(), contents);
  });

  test('cancelling the native save dialog creates no file', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(
      await saveTokenUsageCsv(
        contents: 'date,source,total_tokens\r\n',
        suggestedName: 'usage.csv',
        confirmButtonText: 'Export CSV',
        fileTypeLabel: 'CSV files',
      ),
      isFalse,
    );
    expect(await temporary.list().toList(), isEmpty);
  });
}
