/// What DingDong installs into Agent clients, and the results it shows.
library;

/// DingDong's own integration: the MCP server plus completion and
/// session-start Hooks, the same entries the setup prompt asks an Agent to
/// add. Resources (prompts, Skills, managed MCP servers) are synced
/// separately and are not part of this manifest.
Map<String, Object?> dingDongInstallManifest() => <String, Object?>{
  'schemaVersion': 1,
  'product': 'dingdong',
  'name': 'DingDong',
  'version': '1',
  'mcp': <String, Object?>{
    'name': 'dingdong',
    'command': '{appMcp}',
    'args': <String>[],
    // A same-name server whose command lacks this is someone else's and is
    // left alone; DingDong entries added by hand carry it too.
    'markers': <String>['dingdong_mcp'],
  },
  'hooks': <String, Object?>{
    // Earlier hand-made entries are recognized by the executable name.
    'markers': <String>['dingdong_mcp'],
    'events': <String, Object?>{
      'sessionStart': <String, Object?>{
        'command': <String>[
          '{appMcp}',
          '--acknowledge-session-start',
          '--source',
          '{clientName}',
        ],
        'matcher': 'startup|resume',
        'timeoutSec': 15,
        'statusMessage': 'Acknowledging DingDong reminders',
      },
      'stop': <String, Object?>{
        'command': <String>[
          '{appMcp}',
          '--notify-stop',
          '--source',
          '{clientName}',
        ],
        'timeoutSec': 15,
        'statusMessage': 'Sending DingDong completion notification',
      },
    },
  },
  'clients': <String, Object?>{
    // Cursor's final-reply event carries the text DingDong shows as the
    // notification summary; its session start cannot tell resume apart.
    'cursor': <String, Object?>{
      'hooks': <String, Object?>{
        'events': <String, Object?>{
          'sessionStart': null,
          'stop': null,
          'agentResponse': <String, Object?>{
            'command': <String>[
              '{appMcp}',
              '--notify-stop',
              '--source',
              '{clientName}',
            ],
            'timeoutSec': 15,
          },
        },
      },
    },
    'codex': <String, Object?>{
      'hooks': <String, Object?>{
        'events': <String, Object?>{
          'sessionStart': <String, Object?>{'matcher': r'^(startup|resume)$'},
        },
      },
    },
  },
};

enum AgentInstallState {
  connected,
  updateAvailable,
  notConnected,
  conflict,
  manual,
  unsupported;

  static AgentInstallState parse(String value) => switch (value) {
    'connected' => connected,
    'update_available' => updateAvailable,
    'not_connected' => notConnected,
    'conflict' => conflict,
    'manual' => manual,
    _ => unsupported,
  };

  /// Whether installing would add or refresh something.
  bool get installable => this == notConnected || this == updateAvailable;

  /// Whether DingDong is at least partly installed and can be removed.
  bool get removable => this == connected || this == updateAvailable;
}

/// One Agent client found on this computer.
final class AgentInstallClient {
  const AgentInstallClient({
    required this.id,
    required this.name,
    required this.detected,
    required this.state,
    this.evidence = const <String>[],
    this.problem,
  });

  final String id;
  final String name;
  final bool detected;
  final AgentInstallState state;

  /// What showed the client is installed, for example `~/.codex`.
  final List<String> evidence;

  /// Why the client cannot be installed automatically, if it cannot.
  final String? problem;
}

/// One file an install or removal creates, updates or deletes.
final class AgentInstallChange {
  const AgentInstallChange({required this.path, required this.action});

  /// Home-relative display path, such as `~/.claude.json`.
  final String path;

  /// `create`, `update` or `delete`.
  final String action;
}

/// The planned or applied work for one client.
final class AgentInstallOutcome {
  const AgentInstallOutcome({
    required this.id,
    required this.name,
    required this.state,
    this.changes = const <AgentInstallChange>[],
    this.problems = const <String>[],
    this.needsRestart = false,
    this.needsHookTrust = false,
  });

  final String id;
  final String name;
  final AgentInstallState state;
  final List<AgentInstallChange> changes;
  final List<String> problems;

  /// The client loads the change only after a restart or reload.
  final bool needsRestart;

  /// Codex runs new Hooks only after the person trusts them in `/hooks`.
  final bool needsHookTrust;
}

/// Scans Agent clients and installs DingDong into the selected ones.
abstract interface class AgentInstallGateway {
  Future<List<AgentInstallClient>> scan();

  /// What [apply] would change, without writing anything.
  Future<List<AgentInstallOutcome>> plan(List<String> clientIds);

  Future<List<AgentInstallOutcome>> apply(List<String> clientIds);

  Future<List<AgentInstallOutcome>> remove(List<String> clientIds);
}
