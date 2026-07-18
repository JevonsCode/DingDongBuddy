import 'dart:async';
import 'dart:math';

import 'package:dingdong/core/data/data_revision_bus.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/library_bundle.dart';
import 'package:dingdong/features/library/domain/library_importer.dart';
import 'package:dingdong/features/library/domain/resource_update_fetcher.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:flutter/foundation.dart';

/// Observable state and commands for the resource library workspace.
final class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel(
    this._repository, {
    String Function()? idGenerator,
    DateTime Function()? now,
    LibraryImporter? importer,
    this.updateFetcher,
    this.skillPackageInstaller,
    TriggerGroupStore? triggerGroupStore,
    DataRevisionBus? revisions,
  }) : _idGenerator = idGenerator ?? _generateUuid,
       _now = now ?? _utcNow,
       _triggerGroupStore = triggerGroupStore ?? InMemoryTriggerGroupStore(),
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
  final SkillPackageInstaller? skillPackageInstaller;
  final TriggerGroupStore _triggerGroupStore;
  StreamSubscription<DataCollection>? _revisionSubscription;
  List<Resource> _resources = const <Resource>[];
  List<TriggerGroup> _triggerGroups = const <TriggerGroup>[];
  String _query = '';
  ResourceType? _selectedType;
  String? _selectedGroup;
  bool _pinnedOnly = false;
  Resource? _selectedResource;
  bool _isCreating = false;
  ResourceType _creatingType = ResourceType.prompt;
  final Set<String> _selectedIds = <String>{};

  String get query => _query;

  ResourceType? get selectedType => _selectedType;

  String? get selectedGroup => _selectedGroup;

  List<String> get groups {
    final Map<String, int> typeOrderByGroup = <String, int>{};
    for (final Resource resource in _resources) {
      final String group = resource.group.trim();
      if (!resource.type.isConfigurableAgentResource || group.isEmpty) {
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

  ResourceType get creatingType => _creatingType;

  List<TriggerGroup> get triggerGroups {
    final List<TriggerGroup> groups = List<TriggerGroup>.of(_triggerGroups);
    groups.sort(
      (TriggerGroup left, TriggerGroup right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    return List<TriggerGroup>.unmodifiable(groups);
  }

  int get selectionCount => _selectedIds.length;

  bool isSelected(String id) => _selectedIds.contains(id);

  bool get allVisibleSelected {
    final List<Resource> visible = visibleResources;
    return visible.isNotEmpty &&
        visible.every(
          (Resource resource) => _selectedIds.contains(resource.id),
        );
  }

  List<Resource> get allResources => List<Resource>.unmodifiable(_resources);

  List<Resource> get configurableResources => List<Resource>.unmodifiable(
    _resources.where(
      (Resource resource) => resource.type.isConfigurableAgentResource,
    ),
  );

  List<Resource> get pinnedResources => List<Resource>.unmodifiable(
    _resources.where(
      (Resource resource) =>
          resource.type.isConfigurableAgentResource && resource.pinned,
    ),
  );

  List<Resource> get visibleResources {
    final String needle = _query.trim().toLowerCase();
    final Iterable<Resource> filtered = _resources.where((Resource resource) {
      if (!resource.type.isConfigurableAgentResource) {
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
    _triggerGroups = await _triggerGroupStore.load();
    _selectedIds.removeWhere(
      (String id) => !_resources.any((Resource resource) => resource.id == id),
    );
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (!_selectedIds.add(id)) {
      _selectedIds.remove(id);
    }
    notifyListeners();
  }

  void toggleAllVisible() {
    final Set<String> visibleIds = visibleResources
        .map((Resource resource) => resource.id)
        .toSet();
    if (visibleIds.isNotEmpty && visibleIds.every(_selectedIds.contains)) {
      _selectedIds.removeAll(visibleIds);
    } else {
      _selectedIds.addAll(visibleIds);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
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
    _creatingType = _selectedType ?? ResourceType.prompt;
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
    String? group,
    List<String>? tags,
    String? updateUrl,
    String? packagePath,
    String? note,
    bool? pinned,
    bool? enabled,
    ResourceActivation? activation,
    List<String>? triggerGroupIds,
  }) async {
    final DateTime timestamp = _now().toUtc();
    final Resource resource = Resource(
      id: _idGenerator(),
      type: type,
      group: group,
      title: title,
      content: content,
      tags: tags ?? const <String>[],
      updateUrl: updateUrl,
      packagePath: packagePath,
      note: note,
      pinned: pinned ?? false,
      enabled: enabled ?? true,
      activation: activation,
      triggerGroupIds: triggerGroupIds ?? const <String>[],
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
    _selectedIds.remove(selected.id);
    await _repository.save(_resources);
    _selectedResource = null;
    notifyListeners();
  }

  Future<void> deleteResources(Set<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    _resources = _resources
        .where((Resource resource) => !ids.contains(resource.id))
        .toList(growable: false);
    _selectedIds.removeAll(ids);
    if (ids.contains(_selectedResource?.id)) {
      _selectedResource = null;
      _isCreating = false;
    }
    await _repository.save(_resources);
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

  Future<TriggerGroup> createTriggerGroup({
    required String name,
    required List<TriggerRule> rules,
  }) async {
    final DateTime timestamp = _now().toUtc();
    final TriggerGroup group = TriggerGroup(
      id: _idGenerator(),
      name: name,
      rules: rules,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    _triggerGroups = <TriggerGroup>[..._triggerGroups, group];
    await _triggerGroupStore.save(_triggerGroups);
    notifyListeners();
    return group;
  }

  Future<void> updateTriggerGroup(TriggerGroup group) async {
    _triggerGroups = <TriggerGroup>[
      ..._triggerGroups.where((TriggerGroup item) => item.id != group.id),
      group.copyWith(updatedAt: _now().toUtc()),
    ];
    await _triggerGroupStore.save(_triggerGroups);
    notifyListeners();
  }

  Future<void> deleteTriggerGroup(String id) async {
    _triggerGroups = _triggerGroups
        .where((TriggerGroup group) => group.id != id)
        .toList(growable: false);
    _resources = _resources
        .map(
          (Resource resource) => resource.triggerGroupIds.contains(id)
              ? resource.copyWith(
                  triggerGroupIds: resource.triggerGroupIds
                      .where((String groupId) => groupId != id)
                      .toList(growable: false),
                  updatedAt: _now().toUtc(),
                )
              : resource,
        )
        .toList(growable: false);
    await _triggerGroupStore.save(_triggerGroups);
    await _repository.save(_resources);
    final String? selectedId = _selectedResource?.id;
    if (selectedId != null) {
      _selectedResource = _resources
          .where((Resource resource) => resource.id == selectedId)
          .firstOrNull;
    }
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

  Future<String> fetchUpdateContent(String updateUrl) async {
    final ResourceUpdateFetcher? fetcher = updateFetcher;
    final String link = updateUrl.trim();
    if (fetcher == null || link.isEmpty) {
      throw StateError('Resource update is unavailable.');
    }
    return fetcher.fetch(Uri.parse(link));
  }

  Future<SkillPackageInstallResult> installSkillPackage(
    String updateUrl,
  ) async {
    final SkillPackageInstaller? installer = skillPackageInstaller;
    final String link = updateUrl.trim();
    if (installer == null || link.isEmpty) {
      throw StateError('Skill package installation is unavailable.');
    }
    return installer.install(Uri.parse(link));
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
    final List<Resource> exportable = _selectedIds.isEmpty
        ? visibleResources
        : _resources
              .where((Resource resource) => _selectedIds.contains(resource.id))
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
