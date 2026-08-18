import 'dart:async';
import 'dart:io';

typedef AgentRepositoryUrlResolver =
    Future<String?> Function(String workspacePath);

/// Resolves the current repository without relying on a particular Agent
/// client to enrich its Bridge request first.
Future<String?> resolveGitRepositoryUrl(String workspacePath) async {
  final String directory = workspacePath.trim();
  if (directory.isEmpty) {
    return null;
  }
  try {
    final ProcessResult result = await Process.run('git', <String>[
      '-C',
      directory,
      'config',
      '--get',
      'remote.origin.url',
    ]).timeout(const Duration(seconds: 2));
    if (result.exitCode != 0) {
      return null;
    }
    final String value = result.stdout.toString().trim();
    return value.isEmpty ? null : value;
  } on Object {
    return null;
  }
}
