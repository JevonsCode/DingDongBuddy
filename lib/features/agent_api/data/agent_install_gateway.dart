import 'dart:io';
import 'dart:isolate';

import 'package:agent_installer/agent_installer.dart';
// The pinned upstream currently exposes no removal dry-run. Reuse its exact
// component edits so the preview and remove cannot diverge in parsing/ownership.
import 'package:dingdong/features/agent_api/data/agent_installer_edits.dart'
    as installer_edits;
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
    this.previewOnly = false,
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
  final bool previewOnly;

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

  @override
  Future<List<AgentInstallOutcome>> planRemoval(List<String> clientIds) =>
      _run(_Job.planRemoval, clientIds);

  Future<List<T>> _run<T>(_Job job, List<String> clientIds) {
    if (previewOnly && (job == _Job.apply || job == _Job.remove)) {
      return Future<List<T>>.error(
        StateError('Agent installation is read-only in DEV.'),
      );
    }
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

enum _Job { scan, plan, apply, remove, planRemoval }

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
    _Job.planRemoval => _removalPlan(installer, request.clientIds),
  };
}

List<AgentInstallOutcome> _removalPlan(
  AgentInstaller installer,
  List<String> ids,
) => [for (final id in ids) _planClientRemoval(installer, id)];

AgentInstallOutcome _planClientRemoval(AgentInstaller installer, String id) {
  final target = installer.targets.targets[id];
  if (target == null) throw ArgumentError.value(id, 'clientId');
  final status = installer.status([id]).single;
  if (!status.scan.platformSupported || status.scan.manual != null) {
    return AgentInstallOutcome(
      id: id,
      name: target.name,
      state: AgentInstallState.parse(status.state),
      problems: [status.scan.manual ?? 'Unsupported platform'],
    );
  }
  final work = installer_edits.buildWork(
    target,
    installer.product.forTarget(target),
    installer.env,
  );
  final problems = work.blocked.values.toList();
  if (work.directories.isNotEmpty) {
    throw StateError('Directory cleanup needs an upstream removal plan.');
  }
  final partsByPath = <String, List<installer_edits.TextPart>>{};
  for (final part in work.text) {
    (partsByPath[part.path] ??= []).add(part);
  }
  final changes = <AgentInstallChange>[];
  for (final entry in partsByPath.entries) {
    try {
      final file = File(entry.key);
      final before = file.existsSync() ? file.readAsStringSync() : null;
      var after = before;
      final components = <String>{};
      for (final part in entry.value) {
        final next = part.uninstall(after);
        if (next != after) components.add(part.component);
        after = next;
      }
      if (after != before && after?.trim() == '{}') after = null;
      if (after != before) {
        changes.add(
          AgentInstallChange(
            path: installer.env.display(entry.key),
            action: after == null ? 'delete' : 'update',
            components: components.toList(),
          ),
        );
      }
    } on Object catch (error) {
      problems.add('${installer.env.display(entry.key)}: $error');
    }
  }
  return AgentInstallOutcome(
    id: id,
    name: target.name,
    state: AgentInstallState.parse(installer.status([id]).single.state),
    changes: changes,
    problems: problems,
  );
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
              AgentInstallChange(
                path: c.path,
                action: c.action,
                components: c.components,
              ),
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
