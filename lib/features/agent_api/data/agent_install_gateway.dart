import 'dart:isolate';

import 'package:agent_installer/agent_installer.dart';
import 'package:dingdong/features/agent_api/domain/agent_install.dart';

/// Runs agent-installer off the UI isolate; it reads and writes files
/// synchronously.
final class LocalAgentInstallGateway implements AgentInstallGateway {
  LocalAgentInstallGateway({
    required this.mcpCommandPath,
    this.environment,
    this.extensionsDirectory,
    this.backupDirectory,
    this.runInIsolate = true,
  });

  final String mcpCommandPath;

  /// Overrides the process environment, for tests.
  final Map<String, String>? environment;

  /// Defaults to the shared agent-session-launcher extensions directory.
  final String? extensionsDirectory;

  /// Defaults to a `backups/dingdong` folder next to the extensions.
  final String? backupDirectory;

  /// Widget tests cannot wait on other isolates, so they run inline.
  final bool runInIsolate;

  @override
  Future<List<AgentInstallClient>> scan() => _run(_Job.scan, const <String>[]);

  @override
  Future<List<AgentInstallOutcome>> plan(List<String> clientIds) =>
      _run(_Job.plan, clientIds);

  @override
  Future<List<AgentInstallOutcome>> apply(List<String> clientIds) =>
      _run(_Job.apply, clientIds);

  @override
  Future<List<AgentInstallOutcome>> remove(List<String> clientIds) =>
      _run(_Job.remove, clientIds);

  Future<List<T>> _run<T>(_Job job, List<String> clientIds) {
    final _Request request = _Request(
      job,
      clientIds,
      mcpCommandPath,
      environment,
      extensionsDirectory,
      backupDirectory,
    );
    List<T> work() => List<T>.from(_execute(request));
    return runInIsolate ? Isolate.run(work) : Future<List<T>>.sync(work);
  }
}

enum _Job { scan, plan, apply, remove }

final class _Request {
  const _Request(
    this.job,
    this.clientIds,
    this.mcpCommandPath,
    this.environment,
    this.extensionsDirectory,
    this.backupDirectory,
  );

  final _Job job;
  final List<String> clientIds;
  final String mcpCommandPath;
  final Map<String, String>? environment;
  final String? extensionsDirectory;
  final String? backupDirectory;
}

List<Object> _execute(_Request request) {
  final InstallEnvironment env = InstallEnvironment(
    environment: request.environment,
  );
  final String? extensions =
      request.extensionsDirectory ??
      defaultExtensionsDirectory(environment: env.env);
  final String? backups =
      request.backupDirectory ??
      (extensions == null
          ? null
          : '${_parent(extensions, env.separator)}${env.separator}backups'
                '${env.separator}dingdong');
  final AgentInstaller installer = AgentInstaller(
    product: ProductManifest.fromJson(
      dingDongInstallManifest(),
      variables: <String, String>{'appMcp': request.mcpCommandPath},
    ),
    targets: InstallTargets.load(extensionsDirectory: extensions),
    environment: env,
    backupDirectory: backups,
  );
  return switch (request.job) {
    _Job.scan => <AgentInstallClient>[
      for (final ClientStatus s in installer.status())
        AgentInstallClient(
          id: s.scan.id,
          name: s.scan.name,
          detected: s.scan.detected,
          state: AgentInstallState.parse(s.state),
          evidence: s.scan.evidence,
          problem: s.scan.manual,
        ),
    ],
    _Job.plan => _outcomes(installer.plan(request.clientIds)),
    _Job.apply => _outcomes(installer.apply(request.clientIds)),
    _Job.remove => _outcomes(installer.remove(request.clientIds)),
  };
}

List<AgentInstallOutcome> _outcomes(List<ClientResult> results) =>
    <AgentInstallOutcome>[
      for (final ClientResult r in results)
        AgentInstallOutcome(
          id: r.id,
          name: r.name,
          state: AgentInstallState.parse(r.state),
          changes: <AgentInstallChange>[
            for (final PlannedChange c in r.changes)
              AgentInstallChange(path: c.path, action: c.action),
          ],
          problems: r.problems,
          needsHookTrust: r.actions.any((String a) => a.contains('/hooks')),
          needsRestart: r.actions.any((String a) => !a.contains('/hooks')),
        ),
    ];

String _parent(String path, String separator) {
  final int end = path.lastIndexOf(separator);
  return end <= 0 ? path : path.substring(0, end);
}
