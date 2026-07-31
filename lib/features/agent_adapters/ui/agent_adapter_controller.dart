import 'dart:async';

import 'package:dingdong/features/agent_adapters/data/agent_adapter_repository.dart';
import 'package:dingdong/features/agent_adapters/domain/agent_adapter.dart';
import 'package:dingdong/features/agent_adapters/domain/codex_completion_hook.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

final class AgentAdapterController extends ChangeNotifier {
  AgentAdapterController({
    required this.repository,
    this.watchExternalChanges = true,
    this.onAdaptersChanged,
    this.codexCompletionHookGateway,
  });

  final AgentAdapterRepository repository;
  final bool watchExternalChanges;
  final Future<void> Function()? onAdaptersChanged;
  final CodexCompletionHookGateway? codexCompletionHookGateway;

  List<AgentAdapterEntry> _entries = const <AgentAdapterEntry>[];
  AgentAdapterEntry? _selectedEntry;
  List<AgentAdapterRevision> _history = const <AgentAdapterRevision>[];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isCreating = false;
  bool _isCheckingCodexCompletionHook = false;
  CodexCompletionHookStatus _codexCompletionHookStatus =
      const CodexCompletionHookStatus.notChecked();
  String? _error;
  StreamSubscription<void>? _watchSubscription;
  Timer? _reloadDebounce;
  bool _disposed = false;
  int _codexCompletionHookRequest = 0;

  List<AgentAdapterEntry> get entries => _entries;
  AgentAdapterEntry? get selectedEntry => _selectedEntry;
  List<AgentAdapterRevision> get history => _history;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isCreating => _isCreating;
  bool get supportsCodexCompletionHook => codexCompletionHookGateway != null;
  bool get isCheckingCodexCompletionHook => _isCheckingCodexCompletionHook;
  CodexCompletionHookStatus get codexCompletionHookStatus =>
      _codexCompletionHookStatus;
  String? get error => _error;
  String get userDirectoryPath => repository.userDirectory.path;

  Future<void> load() async {
    _startWatching();
    final String? selectedId = _selectedEntry?.id;
    final String? selectedKey = _selectedEntry?.key;
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final AgentAdapterCatalog catalog = await repository.load();
      _entries = catalog.entries;
      if (!_isCreating) {
        _selectedEntry = _findEntry(selectedKey, selectedId);
        _history = _selectedEntry == null
            ? const <AgentAdapterRevision>[]
            : await repository.historyFor(_selectedEntry!);
      }
    } on Object catch (caught) {
      _error = _message(caught);
    } finally {
      _isLoading = false;
      _notify();
      _refreshCodexCompletionHookForSelection();
    }
  }

  Future<void> select(AgentAdapterEntry entry) async {
    _isCreating = false;
    _selectedEntry = entry;
    _history = await repository.historyFor(entry);
    _error = null;
    _notify();
    _refreshCodexCompletionHookForSelection();
  }

  void beginCreate() {
    _isCreating = true;
    _selectedEntry = null;
    _history = const <AgentAdapterRevision>[];
    _clearCodexCompletionHookStatus();
    _error = null;
    _notify();
  }

  Future<void> refreshCodexCompletionHook() async {
    final CodexCompletionHookGateway? gateway = codexCompletionHookGateway;
    if (gateway == null || _selectedEntry?.id != 'codex') {
      return;
    }
    final int request = ++_codexCompletionHookRequest;
    _isCheckingCodexCompletionHook = true;
    _codexCompletionHookStatus = const CodexCompletionHookStatus.notChecked();
    _notify();
    final CodexCompletionHookStatus status = await gateway.inspect();
    if (_disposed || request != _codexCompletionHookRequest) {
      return;
    }
    _isCheckingCodexCompletionHook = false;
    _codexCompletionHookStatus = status;
    _notify();
  }

  Future<void> repairCodexCompletionHook() async {
    final CodexCompletionHookGateway? gateway = codexCompletionHookGateway;
    final CodexCompletionHookStatus before = _codexCompletionHookStatus;
    if (gateway == null || _selectedEntry?.id != 'codex' || !before.canRepair) {
      return;
    }
    final int request = ++_codexCompletionHookRequest;
    _isCheckingCodexCompletionHook = true;
    _notify();
    final CodexCompletionHookStatus status = await gateway.repair(
      expectedKey: before.key!,
      expectedHash: before.currentHash!,
    );
    if (_disposed || request != _codexCompletionHookRequest) {
      return;
    }
    _isCheckingCodexCompletionHook = false;
    _codexCompletionHookStatus = status;
    _notify();
  }

  Future<void> save(String document) async {
    _isSaving = true;
    _error = null;
    _notify();
    try {
      final String id = AgentAdapter.parse(document).id;
      await repository.save(
        document,
        existing: _isCreating ? null : _selectedEntry,
      );
      _isCreating = false;
      await _reloadAndSelect(id);
      await onAdaptersChanged?.call();
    } on Object catch (caught) {
      _error = _message(caught);
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  Future<void> resetToBuiltIn() async {
    final AgentAdapterEntry? entry = _selectedEntry;
    if (entry == null) {
      return;
    }
    _isSaving = true;
    _error = null;
    _notify();
    try {
      await repository.resetToBuiltIn(entry);
      await _reloadAndSelect(entry.id);
      await onAdaptersChanged?.call();
    } on Object catch (caught) {
      _error = _message(caught);
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  Future<void> deleteCustom() async {
    final AgentAdapterEntry? entry = _selectedEntry;
    if (entry == null) {
      return;
    }
    _isSaving = true;
    _error = null;
    _notify();
    try {
      await repository.deleteCustom(entry);
      _selectedEntry = null;
      await load();
      if (_error == null) {
        await onAdaptersChanged?.call();
      }
    } on Object catch (caught) {
      _error = _message(caught);
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  String newAdapterTemplate() {
    final Set<String> ids = _entries
        .map((AgentAdapterEntry entry) => entry.id)
        .toSet();
    String id = 'new-agent';
    int suffix = 2;
    while (ids.contains(id)) {
      id = 'new-agent-$suffix';
      suffix += 1;
    }
    return '''
schemaVersion: 1
id: $id
displayName: New Agent

detect:
  directory: ~/.$id

skills:
  global: ~/.$id/skills
  project: .$id/skills

mcp:
  file: ~/.$id/mcp.json
  format: mcpServers-json
''';
  }

  String destinationFor(String document) {
    try {
      final String id = AgentAdapter.parse(document).id;
      return path.join(userDirectoryPath, '$id.yaml');
    } on Object {
      return userDirectoryPath;
    }
  }

  Future<void> _reloadAndSelect(String id) async {
    final AgentAdapterCatalog catalog = await repository.load();
    _entries = catalog.entries;
    _selectedEntry = _entries
        .where((AgentAdapterEntry entry) => entry.id == id)
        .firstOrNull;
    _history = _selectedEntry == null
        ? const <AgentAdapterRevision>[]
        : await repository.historyFor(_selectedEntry!);
  }

  AgentAdapterEntry? _findEntry(String? key, String? id) {
    if (_entries.isEmpty) {
      return null;
    }
    for (final AgentAdapterEntry entry in _entries) {
      if (entry.key == key) {
        return entry;
      }
    }
    for (final AgentAdapterEntry entry in _entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return _entries.first;
  }

  void _refreshCodexCompletionHookForSelection() {
    if (_selectedEntry?.id == 'codex' && codexCompletionHookGateway != null) {
      unawaited(refreshCodexCompletionHook());
      return;
    }
    _clearCodexCompletionHookStatus();
  }

  void _clearCodexCompletionHookStatus() {
    _codexCompletionHookRequest += 1;
    _isCheckingCodexCompletionHook = false;
    _codexCompletionHookStatus = const CodexCompletionHookStatus.notChecked();
  }

  void _startWatching() {
    if (!watchExternalChanges) {
      return;
    }
    _watchSubscription ??= repository.watch().listen(
      (_) => _scheduleExternalReload(),
    );
  }

  void _scheduleExternalReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 180), () {
      if (_disposed) {
        return;
      }
      if (_isSaving) {
        _scheduleExternalReload();
        return;
      }
      unawaited(_reloadExternalChanges());
    });
  }

  Future<void> _reloadExternalChanges() async {
    final String previousCatalog = _catalogFingerprint();
    await load();
    if (_error != null || _disposed) {
      return;
    }
    if (previousCatalog == _catalogFingerprint()) {
      return;
    }
    try {
      await onAdaptersChanged?.call();
    } on Object catch (caught) {
      _error = _message(caught);
      _notify();
    }
  }

  String _catalogFingerprint() => _entries
      .map(
        (AgentAdapterEntry entry) =>
            '${entry.key}\u0000${entry.document}\u0000${entry.error ?? ''}',
      )
      .join('\u0001');

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> close() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _codexCompletionHookRequest += 1;
    _reloadDebounce?.cancel();
    final StreamSubscription<void>? subscription = _watchSubscription;
    _watchSubscription = null;
    await subscription?.cancel();
    super.dispose();
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _codexCompletionHookRequest += 1;
    _reloadDebounce?.cancel();
    unawaited(_watchSubscription?.cancel());
    _watchSubscription = null;
    super.dispose();
  }
}

String _message(Object error) => error
    .toString()
    .replaceFirst('FormatException: ', '')
    .replaceFirst('Bad state: ', '');
