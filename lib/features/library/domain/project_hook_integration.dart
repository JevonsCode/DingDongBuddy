import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

enum HookDesiredState { enabled, disabled }

enum HookTrustState { unknown, pending }

enum HookReconcileDisposition {
  installed,
  updated,
  unchanged,
  externalSatisfied,
  removed,
  absent,
}

enum HookIntegrationFailureKind { conflict, drift, malformed }

final class HookIntegrationException implements Exception {
  const HookIntegrationException(this.kind, this.message);

  final HookIntegrationFailureKind kind;
  final String message;

  @override
  String toString() => 'HookIntegrationException($kind): $message';
}

enum CodexHookEvent {
  postToolUse('PostToolUse'),
  stop('Stop');

  const CodexHookEvent(this.jsonKey);

  final String jsonKey;
}

final class HookDeployment {
  const HookDeployment({
    required this.deploymentId,
    required this.artifactDigest,
    this.skillRelativePath = '.agents/skills/impeccable',
  });

  final String deploymentId;
  final String artifactDigest;
  final String skillRelativePath;
}

final class CodexEffectiveHook {
  const CodexEffectiveHook({
    required this.eventName,
    required this.command,
    required this.sourcePath,
    this.handlerType = 'command',
    this.enabled = true,
  });

  final String eventName;
  final String command;
  final String sourcePath;
  final String handlerType;
  final bool enabled;
}

abstract interface class CodexProjectHookInventory {
  Future<List<CodexEffectiveHook>> list(Directory projectRoot);
}

final class CodexHookDefinition {
  const CodexHookDefinition({required this.event, required this.entry});

  final CodexHookEvent event;
  final Map<String, Object?> entry;
}

abstract interface class CodexProjectHookAdapter {
  List<CodexHookDefinition> definitionsFor(HookDeployment deployment);

  bool belongsToHookFamily(Object? entry);
}

final class ImpeccableCodexHookAdapter implements CodexProjectHookAdapter {
  const ImpeccableCodexHookAdapter();

  @override
  List<CodexHookDefinition> definitionsFor(HookDeployment deployment) {
    final String scriptPath = path.posix.join(
      deployment.skillRelativePath.replaceAll(r'\', '/'),
      'scripts',
      'hook.mjs',
    );
    final String command =
        'node ${jsonEncode(scriptPath)} '
        '--dingdong-deployment-id ${jsonEncode(deployment.deploymentId)} '
        '--dingdong-artifact-digest ${jsonEncode(deployment.artifactDigest)}';
    return <CodexHookDefinition>[
      CodexHookDefinition(
        event: CodexHookEvent.postToolUse,
        entry: <String, Object?>{
          'matcher': 'Edit|Write|apply_patch',
          'hooks': <Object?>[
            <String, Object?>{
              'type': 'command',
              'command': command,
              'timeout': 5,
              'statusMessage': 'Checking UI changes',
            },
          ],
        },
      ),
      CodexHookDefinition(
        event: CodexHookEvent.stop,
        entry: <String, Object?>{
          'hooks': <Object?>[
            <String, Object?>{
              'type': 'command',
              'command': command,
              'timeout': 30,
              'statusMessage': 'Design deep pass',
            },
          ],
        },
      ),
    ];
  }

  @override
  bool belongsToHookFamily(Object? entry) {
    if (entry is String) {
      return entry
          .replaceAll('\\', '/')
          .contains('skills/impeccable/scripts/hook.mjs');
    }
    if (entry is List) {
      return entry.any(belongsToHookFamily);
    }
    if (entry is Map) {
      return entry.values.any(belongsToHookFamily);
    }
    return false;
  }
}

final class HookReconcileResult {
  const HookReconcileResult({
    required this.disposition,
    required this.trustState,
  });

  final HookReconcileDisposition disposition;
  final HookTrustState trustState;
}

String _definitionCommand(Object? value) {
  if (value is Map) {
    final Object? command = value['command'];
    if (command is String && command.isNotEmpty) {
      return command;
    }
    for (final Object? nested in value.values) {
      final String result = _definitionCommand(nested);
      if (result.isNotEmpty) {
        return result;
      }
    }
  } else if (value is List) {
    for (final Object? nested in value) {
      final String result = _definitionCommand(nested);
      if (result.isNotEmpty) {
        return result;
      }
    }
  }
  return '';
}

String _normalizedEvent(String value) =>
    value.replaceAll('_', '').toLowerCase();

bool _effectiveHooksExactlyMatch(
  List<CodexEffectiveHook> hooks,
  List<CodexHookDefinition> definitions,
) {
  final Map<String, String> expected = <String, String>{
    for (final CodexHookDefinition definition in definitions)
      definition.event.jsonKey: _definitionCommand(definition.entry),
  };
  return hooks.length == expected.length &&
      expected.entries.every(
        (MapEntry<String, String> entry) =>
            hooks
                .where(
                  (CodexEffectiveHook hook) =>
                      hook.enabled &&
                      _normalizedEvent(hook.handlerType) == 'command' &&
                      _normalizedEvent(hook.eventName) ==
                          _normalizedEvent(entry.key) &&
                      hook.command == entry.value,
                )
                .length ==
            1,
      );
}

final class CodexProjectHookIntegration {
  factory CodexProjectHookIntegration({
    required Directory projectRoot,
    CodexProjectHookInventory? inventory,
  }) => CodexProjectHookIntegration._(projectRoot, inventory);

  CodexProjectHookIntegration._(this._projectRoot, this._inventory);

  static const int _receiptSchemaVersion = 1;
  static const String _receiptFileName = '.dingdong-hook-receipts.json';
  static const String _lockFileName = '.dingdong-hook-integration.lock';
  static final Object _lockZoneKey = Object();
  static final Map<String, Future<void>> _mutationBarriers =
      <String, Future<void>>{};

  final Directory _projectRoot;
  final CodexProjectHookInventory? _inventory;

  Future<HookReconcileResult> reconcile({
    required HookDesiredState desiredState,
    required HookDeployment deployment,
    required CodexProjectHookAdapter adapter,
  }) async {
    final String projectKey = await _canonicalProjectKey(_projectRoot);
    final Set<String> heldProjects =
        Zone.current[_lockZoneKey] as Set<String>? ?? const <String>{};
    if (heldProjects.contains(projectKey)) {
      return _reconcile(
        desiredState: desiredState,
        deployment: deployment,
        adapter: adapter,
      );
    }
    final Future<void> previous =
        _mutationBarriers[projectKey] ?? Future<void>.value();
    final Completer<void> gate = Completer<void>();
    _mutationBarriers[projectKey] = gate.future;
    await previous;
    RandomAccessFile? lock;
    var locked = false;
    try {
      final Directory lockDirectory = Directory(
        path.join(projectKey, '.codex'),
      );
      await lockDirectory.create(recursive: true);
      lock = await File(
        path.join(lockDirectory.path, _lockFileName),
      ).open(mode: FileMode.append);
      await lock.lock(FileLock.exclusive);
      locked = true;
      return await runZoned(
        () => _reconcile(
          desiredState: desiredState,
          deployment: deployment,
          adapter: adapter,
        ),
        zoneValues: <Object, Object>{
          _lockZoneKey: <String>{...heldProjects, projectKey},
        },
      );
    } finally {
      try {
        if (locked) {
          await lock?.unlock();
        }
      } finally {
        try {
          await lock?.close();
        } finally {
          gate.complete();
          if (identical(_mutationBarriers[projectKey], gate.future)) {
            unawaited(_mutationBarriers.remove(projectKey));
          }
        }
      }
    }
  }

  Future<HookReconcileResult> _reconcile({
    required HookDesiredState desiredState,
    required HookDeployment deployment,
    required CodexProjectHookAdapter adapter,
  }) async {
    final File hooksFile = File(
      path.join(_projectRoot.path, '.codex', 'hooks.json'),
    );
    final File receiptFile = File(
      path.join(_projectRoot.path, '.codex', _receiptFileName),
    );
    final _FileSnapshot hooksSnapshot = await _snapshot(hooksFile);
    final _FileSnapshot receiptSnapshot = await _snapshot(receiptFile);
    final Map<String, Object?> manifest = _decodeObjectOrEmpty(
      hooksSnapshot,
      label: 'Codex hooks file',
    );
    final Map<String, Object?> currentReceipt = _decodeObjectOrEmpty(
      receiptSnapshot,
      label: 'DingDong hook ownership receipt',
    );
    _validateManifest(manifest);
    _validateReceipt(currentReceipt, exists: receiptSnapshot.exists);
    final List<CodexHookDefinition> definitions = adapter.definitionsFor(
      deployment,
    );
    final String deploymentKey = _deploymentKey(deployment.deploymentId);
    final Map<String, Object?> currentDeployments =
        currentReceipt['deployments'] is Map
        ? Map<String, Object?>.from(currentReceipt['deployments']! as Map)
        : <String, Object?>{};
    if (desiredState == HookDesiredState.enabled) {
      final HookReconcileResult? external = await _preflightEffectiveHooks(
        hooksFile: hooksFile,
        manifest: manifest,
        hasOwnedReceipt: currentDeployments.containsKey(deploymentKey),
        definitions: definitions,
        adapter: adapter,
      );
      if (external != null) {
        return external;
      }
    }
    final Map<String, Object?> ownedDeployment = _ownedDeployment(
      deployment: deployment,
      deploymentKey: deploymentKey,
      definitions: definitions,
    );
    if (desiredState == HookDesiredState.disabled) {
      final Object? rawOwnedDeployment = currentDeployments[deploymentKey];
      if (rawOwnedDeployment is! Map) {
        final HookReconcileResult? external = await _preflightUnownedDisable(
          manifest: manifest,
          definitions: definitions,
          adapter: adapter,
        );
        if (external != null) {
          return external;
        }
        return const HookReconcileResult(
          disposition: HookReconcileDisposition.absent,
          trustState: HookTrustState.unknown,
        );
      }
      final List<CodexHookDefinition> ownedDefinitions =
          _definitionsFromReceipt(rawOwnedDeployment);
      if (!_manifestContainsExactlyOnce(manifest, ownedDefinitions)) {
        throw const HookIntegrationException(
          HookIntegrationFailureKind.drift,
          'Owned Codex hook entries changed after DingDong installed them.',
        );
      }
      _removeDefinitions(manifest, ownedDefinitions);
      currentDeployments.remove(deploymentKey);
      final String nextHooks = _encodeObject(manifest);
      final String? nextReceipt = currentDeployments.isEmpty
          ? null
          : _encodeObject(<String, Object?>{
              'schemaVersion': _receiptSchemaVersion,
              'deployments': currentDeployments,
            });
      await _commitDisable(
        hooksFile: hooksFile,
        hooksBefore: hooksSnapshot,
        hooksAfter: nextHooks,
        receiptFile: receiptFile,
        receiptBefore: receiptSnapshot,
        receiptAfter: nextReceipt,
      );
      return const HookReconcileResult(
        disposition: HookReconcileDisposition.removed,
        trustState: HookTrustState.pending,
      );
    }
    if (_jsonEquals(currentDeployments[deploymentKey], ownedDeployment) &&
        _manifestContainsExactlyOnce(manifest, definitions)) {
      return const HookReconcileResult(
        disposition: HookReconcileDisposition.unchanged,
        trustState: HookTrustState.pending,
      );
    }
    if (!currentDeployments.containsKey(deploymentKey) &&
        _manifestContainsExactlyOnce(manifest, definitions)) {
      return const HookReconcileResult(
        disposition: HookReconcileDisposition.externalSatisfied,
        trustState: HookTrustState.unknown,
      );
    }
    if (!currentDeployments.containsKey(deploymentKey) &&
        _hasExternalConflict(manifest, definitions, adapter)) {
      throw const HookIntegrationException(
        HookIntegrationFailureKind.conflict,
        'A different Impeccable hook definition already exists.',
      );
    }
    var disposition = HookReconcileDisposition.installed;
    final Object? priorOwnedDeployment = currentDeployments[deploymentKey];
    if (priorOwnedDeployment is Map) {
      final List<CodexHookDefinition> priorDefinitions =
          _definitionsFromReceipt(priorOwnedDeployment);
      if (!_manifestContainsExactlyOnce(manifest, priorDefinitions)) {
        throw const HookIntegrationException(
          HookIntegrationFailureKind.drift,
          'Owned Codex hook entries changed after DingDong installed them.',
        );
      }
      _removeDefinitions(manifest, priorDefinitions);
      disposition = HookReconcileDisposition.updated;
    }
    final Map<String, Object?> hooks = manifest['hooks'] is Map
        ? Map<String, Object?>.from(manifest['hooks']! as Map)
        : <String, Object?>{};
    for (final CodexHookDefinition definition in definitions) {
      final List<Object?> entries = hooks[definition.event.jsonKey] is List
          ? List<Object?>.from(hooks[definition.event.jsonKey]! as List)
          : <Object?>[];
      entries.add(definition.entry);
      hooks[definition.event.jsonKey] = entries;
    }
    manifest['hooks'] = hooks;

    currentDeployments[deploymentKey] = ownedDeployment;
    final String nextHooks = _encodeObject(manifest);
    final String nextReceipt = _encodeObject(<String, Object?>{
      'schemaVersion': _receiptSchemaVersion,
      'deployments': currentDeployments,
    });
    await _commitEnable(
      hooksFile: hooksFile,
      hooksBefore: hooksSnapshot,
      hooksAfter: nextHooks,
      receiptFile: receiptFile,
      receiptBefore: receiptSnapshot,
      receiptAfter: nextReceipt,
    );
    return HookReconcileResult(
      disposition: disposition,
      trustState: HookTrustState.pending,
    );
  }

  Future<HookReconcileResult?> _preflightEffectiveHooks({
    required File hooksFile,
    required Map<String, Object?> manifest,
    required bool hasOwnedReceipt,
    required List<CodexHookDefinition> definitions,
    required CodexProjectHookAdapter adapter,
  }) async {
    final CodexProjectHookInventory? inventory = _inventory;
    if (inventory == null) {
      return null;
    }
    final List<CodexEffectiveHook> effective = await inventory.list(
      _projectRoot,
    );
    final String localHooksPath = _sourcePath(hooksFile.path);
    final String inlineConfigPath = path.normalize(
      File(path.join(_projectRoot.path, '.codex', 'config.toml')).absolute.path,
    );
    if (effective.any(
      (CodexEffectiveHook hook) =>
          _sourcePath(hook.sourcePath) == inlineConfigPath,
    )) {
      throw const HookIntegrationException(
        HookIntegrationFailureKind.conflict,
        'Project inline Hooks already use .codex/config.toml; refusing to add '
        'a second project Hook representation.',
      );
    }
    final List<CodexEffectiveHook> externalFamily = effective
        .where(
          (CodexEffectiveHook hook) =>
              _sourcePath(hook.sourcePath) != localHooksPath &&
              adapter.belongsToHookFamily(hook.command),
        )
        .toList(growable: false);
    if (externalFamily.isEmpty) {
      return null;
    }
    if (hasOwnedReceipt || adapter.belongsToHookFamily(manifest['hooks'])) {
      throw const HookIntegrationException(
        HookIntegrationFailureKind.conflict,
        'Impeccable Hooks exist in both the project hooks file and another '
        'Codex source. Codex would run both definitions additively.',
      );
    }
    final bool exact = _effectiveHooksExactlyMatch(externalFamily, definitions);
    if (exact) {
      return const HookReconcileResult(
        disposition: HookReconcileDisposition.externalSatisfied,
        trustState: HookTrustState.unknown,
      );
    }
    throw const HookIntegrationException(
      HookIntegrationFailureKind.conflict,
      'Another Codex source already provides an Impeccable Hook. Codex runs '
      'matching Hooks additively, so DingDong will not install a duplicate.',
    );
  }

  Future<HookReconcileResult?> _preflightUnownedDisable({
    required Map<String, Object?> manifest,
    required List<CodexHookDefinition> definitions,
    required CodexProjectHookAdapter adapter,
  }) async {
    final bool hasLocalFamily = adapter.belongsToHookFamily(manifest['hooks']);
    final bool localExact =
        hasLocalFamily &&
        _manifestContainsExactlyOnce(manifest, definitions) &&
        !_hasExternalConflict(manifest, definitions, adapter);
    if (hasLocalFamily && !localExact) {
      throw const HookIntegrationException(
        HookIntegrationFailureKind.conflict,
        'An unowned local Impeccable Hook is partial or has a different '
        'definition. Review its source with Codex /hooks.',
      );
    }

    final CodexProjectHookInventory? inventory = _inventory;
    if (inventory != null) {
      final List<CodexEffectiveHook> effectiveFamily =
          (await inventory.list(_projectRoot))
              .where((CodexEffectiveHook hook) {
                return adapter.belongsToHookFamily(hook.command);
              })
              .toList(growable: false);
      if (effectiveFamily.isNotEmpty &&
          !_effectiveHooksExactlyMatch(effectiveFamily, definitions)) {
        throw const HookIntegrationException(
          HookIntegrationFailureKind.conflict,
          'An external Impeccable Hook is partial, duplicated, disabled, or '
          'has a different definition. Review its source with Codex /hooks.',
        );
      }
      if (effectiveFamily.isNotEmpty) {
        return const HookReconcileResult(
          disposition: HookReconcileDisposition.externalSatisfied,
          trustState: HookTrustState.unknown,
        );
      }
    }
    if (localExact) {
      return const HookReconcileResult(
        disposition: HookReconcileDisposition.externalSatisfied,
        trustState: HookTrustState.unknown,
      );
    }
    return null;
  }

  String _sourcePath(String value) {
    final String absolute = path.isAbsolute(value)
        ? value
        : path.join(_projectRoot.absolute.path, value);
    return path.normalize(path.absolute(absolute));
  }

  static String _deploymentKey(String deploymentId) =>
      'dingdong:codex-project:$deploymentId';
}

Future<String> _canonicalProjectKey(Directory projectRoot) async {
  final String absolute = path.normalize(path.absolute(projectRoot.path));
  try {
    return path.normalize(await Directory(absolute).resolveSymbolicLinks());
  } on FileSystemException {
    return absolute;
  }
}

List<CodexHookDefinition> _definitionsFromReceipt(Object? deployment) {
  if (deployment is! Map || deployment['ownedEntries'] is! List) {
    throw const HookIntegrationException(
      HookIntegrationFailureKind.malformed,
      'The DingDong hook ownership receipt is malformed.',
    );
  }
  final List<CodexHookDefinition> definitions = <CodexHookDefinition>[];
  for (final Object? rawEntry in deployment['ownedEntries']! as List) {
    if (rawEntry is! Map ||
        rawEntry['event'] is! String ||
        rawEntry['definition'] is! Map) {
      throw const HookIntegrationException(
        HookIntegrationFailureKind.malformed,
        'The DingDong hook ownership receipt is malformed.',
      );
    }
    final CodexHookEvent event = switch (rawEntry['event']) {
      'PostToolUse' => CodexHookEvent.postToolUse,
      'Stop' => CodexHookEvent.stop,
      _ => throw const HookIntegrationException(
        HookIntegrationFailureKind.malformed,
        'The DingDong hook ownership receipt has an unknown event.',
      ),
    };
    definitions.add(
      CodexHookDefinition(
        event: event,
        entry: Map<String, Object?>.from(rawEntry['definition']! as Map),
      ),
    );
  }
  return definitions;
}

void _removeDefinitions(
  Map<String, Object?> manifest,
  List<CodexHookDefinition> definitions,
) {
  final Map<String, Object?> hooks = Map<String, Object?>.from(
    manifest['hooks']! as Map,
  );
  for (final CodexHookDefinition definition in definitions) {
    final List<Object?> entries = List<Object?>.from(
      hooks[definition.event.jsonKey]! as List,
    );
    entries.removeWhere(
      (Object? entry) => _jsonEquals(entry, definition.entry),
    );
    if (entries.isEmpty) {
      hooks.remove(definition.event.jsonKey);
    } else {
      hooks[definition.event.jsonKey] = entries;
    }
  }
  if (hooks.isEmpty) {
    manifest.remove('hooks');
  } else {
    manifest['hooks'] = hooks;
  }
}

Map<String, Object?> _ownedDeployment({
  required HookDeployment deployment,
  required String deploymentKey,
  required List<CodexHookDefinition> definitions,
}) {
  return <String, Object?>{
    'deploymentId': deployment.deploymentId,
    'artifactDigest': deployment.artifactDigest,
    'trustState': HookTrustState.pending.name,
    'ownedEntries': definitions
        .map(
          (CodexHookDefinition definition) => <String, Object?>{
            'ownedKey': '$deploymentKey:${definition.event.jsonKey}',
            'event': definition.event.jsonKey,
            'definition': definition.entry,
          },
        )
        .toList(),
  };
}

bool _manifestContainsExactlyOnce(
  Map<String, Object?> manifest,
  List<CodexHookDefinition> definitions,
) {
  if (manifest['hooks'] is! Map) {
    return false;
  }
  final Map<String, Object?> hooks = Map<String, Object?>.from(
    manifest['hooks']! as Map,
  );
  for (final CodexHookDefinition definition in definitions) {
    if (hooks[definition.event.jsonKey] is! List) {
      return false;
    }
    final List<Object?> entries = List<Object?>.from(
      hooks[definition.event.jsonKey]! as List,
    );
    if (entries
            .where((Object? entry) => _jsonEquals(entry, definition.entry))
            .length !=
        1) {
      return false;
    }
  }
  return true;
}

bool _hasExternalConflict(
  Map<String, Object?> manifest,
  List<CodexHookDefinition> definitions,
  CodexProjectHookAdapter adapter,
) {
  if (manifest['hooks'] is! Map) {
    return false;
  }
  final Map<String, Object?> hooks = Map<String, Object?>.from(
    manifest['hooks']! as Map,
  );
  var familyEntryCount = 0;
  for (final Object? rawEntries in hooks.values) {
    if (rawEntries is List) {
      familyEntryCount += rawEntries
          .where((Object? entry) => adapter.belongsToHookFamily(entry))
          .length;
    }
  }
  if (familyEntryCount > 0 && familyEntryCount != definitions.length) {
    return true;
  }
  for (final CodexHookDefinition definition in definitions) {
    final Object? rawEntries = hooks[definition.event.jsonKey];
    if (rawEntries is! List) {
      continue;
    }
    final List<Object?> entries = List<Object?>.from(rawEntries);
    final int exactCount = entries
        .where((Object? entry) => _jsonEquals(entry, definition.entry))
        .length;
    if (exactCount > 1) {
      return true;
    }
    if (entries.any(
      (Object? entry) =>
          !_jsonEquals(entry, definition.entry) &&
          adapter.belongsToHookFamily(entry),
    )) {
      return true;
    }
  }
  return false;
}

bool _jsonEquals(Object? left, Object? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) {
      return false;
    }
    for (final Object? key in left.keys) {
      if (!right.containsKey(key) || !_jsonEquals(left[key], right[key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (!_jsonEquals(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

void _validateManifest(Map<String, Object?> manifest) {
  final Object? rawHooks = manifest['hooks'];
  if (rawHooks == null) {
    return;
  }
  if (rawHooks is! Map) {
    throw const HookIntegrationException(
      HookIntegrationFailureKind.malformed,
      'Codex hooks must be a JSON object keyed by hook event.',
    );
  }
  for (final Object? entries in rawHooks.values) {
    if (entries is! List) {
      throw const HookIntegrationException(
        HookIntegrationFailureKind.malformed,
        'Each Codex hook event must contain a JSON array.',
      );
    }
  }
}

void _validateReceipt(Map<String, Object?> receipt, {required bool exists}) {
  if (!exists) {
    return;
  }
  if (receipt['schemaVersion'] != 1 || receipt['deployments'] is! Map) {
    throw const HookIntegrationException(
      HookIntegrationFailureKind.malformed,
      'The DingDong hook ownership receipt is malformed.',
    );
  }
  final Map<String, Object?> deployments = Map<String, Object?>.from(
    receipt['deployments']! as Map,
  );
  for (final MapEntry<String, Object?> item in deployments.entries) {
    final Object? value = item.value;
    if (value is! Map ||
        value['deploymentId'] is! String ||
        value['artifactDigest'] is! String ||
        value['trustState'] is! String ||
        item.key != _deploymentKeyFor(value['deploymentId']! as String)) {
      throw const HookIntegrationException(
        HookIntegrationFailureKind.malformed,
        'The DingDong hook ownership receipt is malformed.',
      );
    }
    final String trustState = value['trustState']! as String;
    if (trustState != HookTrustState.unknown.name &&
        trustState != HookTrustState.pending.name) {
      throw const HookIntegrationException(
        HookIntegrationFailureKind.malformed,
        'The DingDong hook ownership receipt has an unknown trust state.',
      );
    }
    final List<CodexHookDefinition> definitions = _definitionsFromReceipt(
      value,
    );
    final List<Object?> ownedEntries = List<Object?>.from(
      value['ownedEntries']! as List,
    );
    for (var index = 0; index < definitions.length; index += 1) {
      final Map<Object?, Object?> rawEntry =
          ownedEntries[index]! as Map<Object?, Object?>;
      if (rawEntry['ownedKey'] !=
          '${item.key}:${definitions[index].event.jsonKey}') {
        throw const HookIntegrationException(
          HookIntegrationFailureKind.malformed,
          'The DingDong hook ownership receipt has a non-canonical key.',
        );
      }
    }
  }
}

String _deploymentKeyFor(String deploymentId) =>
    'dingdong:codex-project:$deploymentId';

final class _FileSnapshot {
  const _FileSnapshot({required this.exists, required this.contents});

  final bool exists;
  final String? contents;
}

Future<_FileSnapshot> _snapshot(File file) async {
  if (!await file.exists()) {
    return const _FileSnapshot(exists: false, contents: null);
  }
  return _FileSnapshot(exists: true, contents: await file.readAsString());
}

Map<String, Object?> _decodeObjectOrEmpty(
  _FileSnapshot snapshot, {
  required String label,
}) {
  if (!snapshot.exists) {
    return <String, Object?>{};
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(snapshot.contents!);
  } on FormatException {
    throw HookIntegrationException(
      HookIntegrationFailureKind.malformed,
      '$label is not valid JSON.',
    );
  }
  if (decoded is! Map) {
    throw HookIntegrationException(
      HookIntegrationFailureKind.malformed,
      '$label must contain a JSON object.',
    );
  }
  return Map<String, Object?>.from(decoded);
}

String _encodeObject(Map<String, Object?> value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

Future<void> _commitEnable({
  required File hooksFile,
  required _FileSnapshot hooksBefore,
  required String hooksAfter,
  required File receiptFile,
  required _FileSnapshot receiptBefore,
  required String receiptAfter,
}) async {
  await _replaceAtomicallyIfUnchanged(receiptFile, receiptAfter, receiptBefore);
  try {
    await _replaceAtomicallyIfUnchanged(hooksFile, hooksAfter, hooksBefore);
  } on Object {
    await _restoreSnapshot(
      receiptFile,
      before: _FileSnapshot(exists: true, contents: receiptAfter),
      restore: receiptBefore,
    );
    rethrow;
  }
}

Future<void> _commitDisable({
  required File hooksFile,
  required _FileSnapshot hooksBefore,
  required String hooksAfter,
  required File receiptFile,
  required _FileSnapshot receiptBefore,
  required String? receiptAfter,
}) async {
  await _replaceAtomicallyIfUnchanged(hooksFile, hooksAfter, hooksBefore);
  try {
    if (receiptAfter == null) {
      await _deleteAtomicallyIfUnchanged(receiptFile, receiptBefore);
    } else {
      await _replaceAtomicallyIfUnchanged(
        receiptFile,
        receiptAfter,
        receiptBefore,
      );
    }
  } on Object {
    await _restoreSnapshot(
      hooksFile,
      before: _FileSnapshot(exists: true, contents: hooksAfter),
      restore: hooksBefore,
    );
    rethrow;
  }
}

Future<void> _restoreSnapshot(
  File file, {
  required _FileSnapshot before,
  required _FileSnapshot restore,
}) async {
  if (restore.exists) {
    await _replaceAtomicallyIfUnchanged(file, restore.contents!, before);
  } else {
    await _deleteAtomicallyIfUnchanged(file, before);
  }
}

var _temporaryFileSequence = 0;

Future<void> _replaceAtomicallyIfUnchanged(
  File file,
  String contents,
  _FileSnapshot expected,
) async {
  await file.parent.create(recursive: true);
  final File temporary = await _reserveSibling(file, 'tmp');
  try {
    await temporary.writeAsString(contents, flush: true);
    await _requireUnchanged(file, expected);
    await temporary.rename(file.path);
  } finally {
    if (await temporary.exists()) {
      await temporary.delete();
    }
  }
}

Future<void> _deleteAtomicallyIfUnchanged(
  File file,
  _FileSnapshot expected,
) async {
  await _requireUnchanged(file, expected);
  if (!expected.exists) {
    return;
  }
  final File removed = await _reserveSibling(file, 'removed');
  await removed.delete();
  try {
    await file.rename(removed.path);
    await removed.delete();
  } finally {
    if (await removed.exists() && !await file.exists()) {
      await removed.rename(file.path);
    }
  }
}

Future<File> _reserveSibling(File file, String marker) async {
  while (true) {
    _temporaryFileSequence += 1;
    final File candidate = File(
      '${file.path}.dingdong-$marker.$pid.$_temporaryFileSequence',
    );
    try {
      return await candidate.create(exclusive: true);
    } on FileSystemException {
      continue;
    }
  }
}

Future<void> _requireUnchanged(File file, _FileSnapshot expected) async {
  final _FileSnapshot current = await _snapshot(file);
  if (current.exists != expected.exists ||
      current.contents != expected.contents) {
    throw const HookIntegrationException(
      HookIntegrationFailureKind.drift,
      'The Codex hook files changed while DingDong was reconciling them.',
    );
  }
}
