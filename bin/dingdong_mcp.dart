import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/app/app_data_paths.dart';
import 'package:dingdong/features/agent_api/data/completion_hook_notifier.dart';
import 'package:dingdong/features/agent_api/data/loopback_mcp_tool_executor.dart';
import 'package:dingdong/features/agent_api/data/mcp_server.dart';

Future<void> main(List<String> arguments) async {
  final DartIoMcpHttpTransport transport = DartIoMcpHttpTransport(
    AppDataPaths.current().activePortFile,
  );
  if (arguments.contains('--notify-stop')) {
    await _notifyStop(
      transport,
      sourceOverride: _argumentValue(arguments, '--source'),
    );
    return;
  }
  final McpServer server = McpServer(
    executor: LoopbackMcpToolExecutor(transport),
  );
  await for (final String line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final String? response = await server.handleLine(line);
    if (response != null) {
      stdout.writeln(response);
    }
  }
}

Future<void> _notifyStop(
  DartIoMcpHttpTransport transport, {
  String? sourceOverride,
}) async {
  final String hookInput = await stdin.transform(utf8.decoder).join();
  try {
    await CompletionHookNotifier(
      transport,
    ).notify(hookInput, sourceOverride: sourceOverride);
  } on Object {
    // Completion alerts must never block or fail the Agent's Stop lifecycle.
  }
  stdout.write('{}');
}

String? _argumentValue(List<String> arguments, String name) {
  final int index = arguments.indexOf(name);
  if (index >= 0 && index + 1 < arguments.length) {
    final String value = arguments[index + 1].trim();
    return value.isEmpty ? null : value;
  }
  final String prefix = '$name=';
  for (final String argument in arguments) {
    if (argument.startsWith(prefix)) {
      final String value = argument.substring(prefix.length).trim();
      return value.isEmpty ? null : value;
    }
  }
  return null;
}
