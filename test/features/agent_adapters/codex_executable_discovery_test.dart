import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/agent_adapters/data/codex_completion_hook_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  for (final String appName in <String>['ChatGPT.app', 'Codex.app']) {
    test(
      'finds the nested Codex CLI in a user-installed $appName',
      () async {
        final Directory home = await Directory.systemTemp.createTemp(
          'jvs-a codex discovery ',
        );
        addTearDown(() => home.delete(recursive: true));
        final File executable = File(
          path.joinAll(<String>[
            home.path,
            'Applications',
            appName,
            'Contents',
            'Resources',
            'codex-cli',
            'CodexCLI.app',
            'Contents',
            'MacOS',
            'codex',
          ]),
        );
        await executable.parent.create(recursive: true);
        // Synthetic protocol peer: no model requests or real conversations.
        final String response = jsonEncode(<String, Object?>{
          'id': 2,
          'result': <String, Object?>{'fixture': appName},
        });
        await executable.writeAsString('''#!/bin/sh
while IFS= read -r line; do
  case "\$line" in
    *'"id":1'*) printf '%s\\n' '{"id":1,"result":{}}' ;;
    *'"id":2'*) printf '%s\\n' '$response' ;;
  esac
done
''');
        final ProcessResult chmod = await Process.run('/bin/chmod', <String>[
          '+x',
          executable.path,
        ]);
        expect(chmod.exitCode, 0);

        CodexAppServerConnection? connection;
        Map<String, Object?>? result;
        Object? failure;
        try {
          connection = await NativeCodexAppServerConnectionFactory(
            homeDirectory: home.path,
            environment: const <String, String>{
              'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
            },
          ).open();
          result = await connection.request('dingdong/fixture');
        } on Object catch (error) {
          failure = error;
        } finally {
          await connection?.close();
        }

        expect(
          result,
          <String, Object?>{'fixture': appName},
          reason:
              'The installed desktop CLI must be found without PATH: '
              '${failure.runtimeType}',
        );
      },
      skip: !Platform.isMacOS,
    );
  }
}
