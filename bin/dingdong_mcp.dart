import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/app/app_data_paths.dart';
import 'package:dingdong/features/agent_api/data/completion_hook_notifier.dart';
import 'package:dingdong/features/agent_api/data/loopback_mcp_tool_executor.dart';
import 'package:dingdong/features/agent_api/data/mcp_server.dart';
import 'package:dingdong/features/agent_api/data/native_mcp_installer.dart';

Future<void> main(List<String> arguments) async {
  final DartIoMcpHttpTransport transport = DartIoMcpHttpTransport(
    AppDataPaths.current().activePortFile,
  );
  if (arguments.contains('--notify-stop')) {
    await _notifyStop(transport);
    return;
  }
  final String home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;
  final String codexHome =
      Platform.environment['CODEX_HOME'] ??
      '$home${Platform.pathSeparator}.codex';
  final McpServer server = McpServer(
    executor: LoopbackMcpToolExecutor(
      transport,
      installer: NativeMcpInstaller(
        codexConfigFile: File('$codexHome${Platform.pathSeparator}config.toml'),
        claudeConfigFile: File(
          '$home${Platform.pathSeparator}.claude${Platform.pathSeparator}.mcp.json',
        ),
      ),
    ),
  );
  await for (final String line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final String? response = await server.handleLine(line);
    if (response != null) {
      stdout.writeln(response);
    }
  }
}

Future<void> _notifyStop(DartIoMcpHttpTransport transport) async {
  final String hookInput = await stdin.transform(utf8.decoder).join();
  try {
    await CompletionHookNotifier(transport).notify(hookInput);
  } on Object {
    // Completion alerts must never block or fail the Agent's Stop lifecycle.
  }
}
