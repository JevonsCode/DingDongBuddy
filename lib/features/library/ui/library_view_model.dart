import 'dart:async';
import 'dart:math';

import 'package:dingdong/core/data/data_revision_bus.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/library_bundle.dart';
import 'package:dingdong/features/library/domain/library_importer.dart';
import 'package:dingdong/features/library/domain/resource_update_fetcher.dart';
import 'package:flutter/foundation.dart';

/// Observable state and commands for the resource library workspace.
final class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel(
    this._repository, {
    String Function()? idGenerator,
    DateTime Function()? now,
    LibraryImporter? importer,
    this.updateFetcher,
    DataRevisionBus? revisions,
  }) : _idGenerator = idGenerator ?? _generateUuid,
       _now = now ?? _utcNow,
       _importer =
           importer ?? LibraryImporter(idGenerator: idGenerator, now: now) {
    _revisionSubscription = revisions?.changes
        .where((DataCollection change) => change == DataCollection.library)
        .listen((_) => unawaited(load()));
  }

  final ResourceStore _repository;
  final String Function() _idGenerator;
  final DateTime Function() _now;
  final LibraryImporter _importer;
  final ResourceUpdateFetcher? updateFetcher;
  StreamSubscription<DataCollection>? _revisionSubscription;
  List<Resource> _resources = const <Resource>[];
  String _query = '';
  ResourceType? _selectedType;
  String? _selectedGroup;
  bool _pinnedOnly = false;
  Resource? _selectedResource;
  bool _isCreating = false;
  final Set<String> _transferSelectionIds = <String>{};

  String get query => _query;

  ResourceType? get selectedType => _selectedType;

  String? get selectedGroup => _selectedGroup;

  List<String> get groups {
    final Map<String, int> typeOrderByGroup = <String, int>{};
    for (final Resource resource in _resources) {
      final String group = resource.group.trim();
      if (!resource.type.isLibraryResource || group.isEmpty) {
        continue;
      }
      final int order = resource.type.index;
      final int? current = typeOrderByGroup[group];
      if (current == null || order < current) {
        typeOrderByGroup[group] = order;
      }
    }
    final List<String> values = typeOrderByGroup.keys.toList();
    return values..sort((String left, String right) {
      final int typeComparison = typeOrderByGroup[left]!.compareTo(
        typeOrderByGroup[right]!,
      );
      return typeComparison != 0
          ? typeComparison
          : left.toLowerCase().compareTo(right.toLowerCase());
    });
  }

  bool get pinnedOnly => _pinnedOnly;

  Resource? get selectedResource => _selectedResource;

  bool get isCreating => _isCreating;

  int get transferSelectionCount => _transferSelectionIds.length;

  bool isSelectedForTransfer(String id) => _transferSelectionIds.contains(id);

  List<Resource> get allResources => List<Resource>.unmodifiable(_resources);

  List<Resource> get pinnedResources => List<Resource>.unmodifiable(
    _resources.where((Resource resource) => resource.pinned),
  );

  List<Resource> get visibleResources {
    final String needle = _query.trim().toLowerCase();
    final Iterable<Resource> filtered = _resources.where((Resource resource) {
      if (!resource.type.isLibraryResource) {
        return false;
      }
      if (_selectedType != null && resource.type != _selectedType) {
        return false;
      }
      if (_selectedGroup != null && resource.group != _selectedGroup) {
        return false;
      }
      if (_pinnedOnly && !resource.pinned) {
        return false;
      }
      if (needle.isEmpty) {
        return true;
      }
      return resource.title.toLowerCase().contains(needle) ||
          resource.content.toLowerCase().contains(needle) ||
          resource.group.toLowerCase().contains(needle) ||
          resource.tags.any(
            (String tag) => tag.toLowerCase().contains(needle),
          ) ||
          (resource.updateUrl?.toLowerCase().contains(needle) ?? false);
    });
    return List<Resource>.unmodifiable(<Resource>[
      ...filtered.where((Resource resource) => resource.pinned),
      ...filtered.where((Resource resource) => !resource.pinned),
    ]);
  }

  Future<void> load() async {
    _resources = await _repository.load();
    _transferSelectionIds.removeWhere(
      (String id) => !_resources.any((Resource resource) => resource.id == id),
    );
    notifyListeners();
  }

  void toggleTransferSelection(String id) {
    if (!_transferSelectionIds.add(id)) {
      _transferSelectionIds.remove(id);
    }
    notifyListeners();
  }

  void selectAllVisibleForTransfer() {
    _transferSelectionIds.addAll(
      visibleResources.map((Resource resource) => resource.id),
    );
    notifyListeners();
  }

  void clearTransferSelection() {
    _transferSelectionIds.clear();
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setTypeFilter(ResourceType? value) {
    _selectedType = value;
    _selectedGroup = null;
    _pinnedOnly = false;
    notifyListeners();
  }

  void setGroupFilter(String? value) {
    _selectedGroup = value;
    _selectedType = null;
    _pinnedOnly = false;
    notifyListeners();
  }

  void setPinnedOnly(bool value) {
    _pinnedOnly = value;
    if (value) {
      _selectedType = null;
    }
    notifyListeners();
  }

  void selectResource(Resource resource) {
    _isCreating = false;
    _selectedResource = resource;
    notifyListeners();
  }

  void startCreating() {
    _selectedResource = null;
    _isCreating = true;
    notifyListeners();
  }

  /// Returns the compact resource workspace to its result list.
  void closeEditor() {
    _selectedResource = null;
    _isCreating = false;
    notifyListeners();
  }

  Future<void> create({
    required ResourceType type,
    required String title,
    required String content,
  }) async {
    final DateTime timestamp = _now().toUtc();
    final Resource resource = Resource(
      id: _idGenerator(),
      type: type,
      title: title,
      content: content,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    await save(resource);
    _isCreating = false;
  }

  Future<void> deleteSelected() async {
    final Resource? selected = _selectedResource;
    if (selected == null) {
      return;
    }
    _resources = _resources
        .where((Resource resource) => resource.id != selected.id)
        .toList(growable: false);
    _transferSelectionIds.remove(selected.id);
    await _repository.save(_resources);
    _selectedResource = null;
    notifyListeners();
  }

  Future<void> save(Resource resource) async {
    _resources = <Resource>[
      ..._resources.where((Resource item) => item.id != resource.id),
      resource,
    ];
    await _repository.save(_resources);
    _selectedResource = resource;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_revisionSubscription?.cancel());
    super.dispose();
  }

  /// Replaces the selected resource body with content from its update link.
  Future<Resource?> syncSelectedFromUpdateLink({String? overrideUrl}) async {
    final Resource? selected = _selectedResource;
    final ResourceUpdateFetcher? fetcher = updateFetcher;
    final String link = (overrideUrl ?? selected?.updateUrl ?? '').trim();
    if (selected == null || fetcher == null || link.isEmpty) {
      return null;
    }
    final String content = await fetcher.fetch(Uri.parse(link));
    final Resource updated = selected.copyWith(
      content: content,
      updateUrl: link,
      updatedAt: _now().toUtc(),
    );
    await save(updated);
    return updated;
  }

  Future<LibraryImportResult> importDirectory({
    required ResourceType type,
    required String path,
    String? group,
    List<String>? tags,
  }) async {
    final LibraryImportResult result = await _importer.scan(
      LibraryImportRequest(type: type, path: path, group: group, tags: tags),
      existing: _resources,
    );
    if (result.imported.isNotEmpty) {
      _resources = <Resource>[..._resources, ...result.imported];
      await _repository.save(_resources);
      _selectedResource = result.imported.first;
      _isCreating = false;
      notifyListeners();
    }
    return result;
  }

  Future<LibraryBundleImportResult> importBundleJson(String contents) async {
    final LibraryBundleImportResult result = LibraryBundle.decode(
      contents,
      existing: _resources,
    );
    if (result.imported.isNotEmpty) {
      _resources = <Resource>[..._resources, ...result.imported];
      await _repository.save(_resources);
      _selectedResource = result.imported.first;
      _isCreating = false;
      notifyListeners();
    }
    return result;
  }

  String exportJson() {
    final List<Resource> exportable = _transferSelectionIds.isEmpty
        ? visibleResources
        : _resources
              .where(
                (Resource resource) =>
                    _transferSelectionIds.contains(resource.id),
              )
              .toList(growable: false);
    return LibraryBundle.encode(exportable, generatedAt: _now());
  }
}

DateTime _utcNow() => DateTime.now().toUtc();

String _generateUuid() {
  final Random random = Random.secure();
  final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final String hex = bytes
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
          '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
          '${hex.substring(20)}'
      .toUpperCase();
}
