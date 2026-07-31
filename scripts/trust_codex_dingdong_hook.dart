import 'dart:io';

import 'package:dingdong/features/agent_adapters/data/codex_completion_hook_gateway.dart';
import 'package:dingdong/features/agent_adapters/domain/codex_completion_hook.dart';
import 'package:path/path.dart' as path;

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    _writeUsage();
    return;
  }
  final String? homeDirectory =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (homeDirectory == null || homeDirectory.trim().isEmpty) {
    stderr.writeln('Could not determine the current user home directory.');
    exitCode = 2;
    return;
  }
  final String? configuredMcpPath = _argumentValue(arguments, '--mcp-path');
  final String? mcpPath =
      configuredMcpPath ??
      (Platform.isMacOS
          ? '/Applications/DingDong.app/Contents/MCP/bundle/bin/dingdong_mcp'
          : null);
  if (mcpPath == null || !path.isAbsolute(mcpPath)) {
    stderr.writeln('Pass the absolute DingDong launcher with --mcp-path.');
    _writeUsage();
    exitCode = 2;
    return;
  }

  final CodexAppServerCompletionHookGateway gateway =
      CodexAppServerCompletionHookGateway(
        connectionFactory: NativeCodexAppServerConnectionFactory(
          homeDirectory: homeDirectory,
        ),
        homeDirectory: homeDirectory,
        dingDongMcpCommandPath: mcpPath,
      );
  final bool apply = arguments.contains('--apply');
  final CodexCompletionHookStatus before = await gateway.inspect();
  _writeStatus(apply ? 'Before' : 'Current', before);
  if (!apply) {
    stdout.writeln();
    stdout.writeln(
      before.canRepair
          ? 'No changes made. Re-run with --apply to trust and enable only this exact Hook hash.'
          : 'No changes made.',
    );
    exitCode = before.isOperational ? 0 : 1;
    return;
  }
  if (before.isOperational) {
    stdout.writeln(
      'The DingDong completion Hook is already trusted and enabled.',
    );
    return;
  }
  if (!before.canRepair) {
    stderr.writeln(
      'Refusing to write: the exact installed DingDong Hook and current hash were not verified.',
    );
    exitCode = 2;
    return;
  }

  final CodexCompletionHookStatus after = await gateway.repair(
    expectedKey: before.key!,
    expectedHash: before.currentHash!,
  );
  stdout.writeln();
  _writeStatus('After', after);
  if (!after.isOperational) {
    stderr.writeln('Codex did not confirm the Hook as trusted and enabled.');
    exitCode = 1;
  }
}

String? _argumentValue(List<String> arguments, String name) {
  final int index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) {
    return null;
  }
  return arguments[index + 1];
}

void _writeStatus(String label, CodexCompletionHookStatus status) {
  stdout.writeln('$label review: ${status.review.name}');
  stdout.writeln('$label enabled: ${status.enabled}');
  if (status.command != null) {
    stdout.writeln('$label command: ${status.command}');
  }
  if (status.currentHash != null) {
    stdout.writeln('$label hash: ${status.currentHash}');
  }
  if (status.detail != null) {
    stdout.writeln('$label detail: ${status.detail}');
  }
}

void _writeUsage() {
  stdout.writeln(
    'Usage: dart run scripts/trust_codex_dingdong_hook.dart '
    '[--apply] [--mcp-path /absolute/path/to/dingdong_mcp]',
  );
  stdout.writeln('Without --apply the script only inspects Codex.');
}
