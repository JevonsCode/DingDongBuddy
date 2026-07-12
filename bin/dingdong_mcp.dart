import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/app/app_data_paths.dart';
import 'package:dingdong/features/agent_api/data/loopback_mcp_tool_executor.dart';
import 'package:dingdong/features/agent_api/data/mcp_server.dart';
import 'package:dingdong/features/agent_api/data/native_mcp_installer.dart';

Future<void> main() async {
  final String home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;
  final String codexHome =
      Platform.environment['CODEX_HOME'] ??
      '$home${Platform.pathSeparator}.codex';
  final McpServer server = McpServer(
    executor: LoopbackMcpToolExecutor(
      DartIoMcpHttpTransport(AppDataPaths.current().activePortFile),
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
