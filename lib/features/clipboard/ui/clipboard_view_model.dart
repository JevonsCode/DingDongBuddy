// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dingdong/core/data/data_revision_bus.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/clipboard/data/clipboard_category_rule_store.dart';
import 'package:dingdong/features/clipboard/data/clipboard_group_order_store.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_capture_service.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_category_rule.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_source.dart';
import 'package:dingdong/features/clipboard/domain/managed_clipboard_images.dart';
import 'package:dingdong/features/clipboard/domain/quick_paste_gateway.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:flutter/foundation.dart';

enum ClipboardPasteMode { original, plainText }

/// Observable filters and selection for clipboard history.
final class ClipboardViewModel extends ChangeNotifier {
  ClipboardViewModel(
    ClipboardStore store, {
    ClipboardArchiveStore? archiveStore,
    ClipboardCaptureService? captureService,
    ClipboardGateway? gateway,
    ResourceStore? resourceStore,
    String Function()? idGenerator,
    DateTime Function()? now,
    QuickPasteGateway? quickPasteGateway,
    DataRevisionBus? revisions,
    ClipboardCategoryRuleStore? categoryRuleStore,
    ClipboardGroupOrderStore? groupOrderStore,
    Directory? managedImageDirectory,
  }) : _store = store,
       _archiveStore =
           archiveStore ??
           (store is ClipboardArchiveStore
               ? store as ClipboardArchiveStore
               : InMemoryClipboardArchiveStore()),
       _captureService = captureService,
       _gateway = gateway,
       _resourceStore = resourceStore,
       _idGenerator = idGenerator ?? _generateUuid,
       _now = now ?? _utcNow,
       _quickPasteGateway = quickPasteGateway,
       _revisions = revisions,
       _managedImageDirectory = managedImageDirectory,
       _categoryRuleStore =
           categoryRuleStore ?? InMemoryClipboardCategoryRuleStore(),
       _groupOrderStore = groupOrderStore ?? InMemoryClipboardGroupOrderStore();

  final ClipboardStore _store;
  final ClipboardArchiveStore _archiveStore;
  final ClipboardCaptureService? _captureService;
  final ClipboardGateway? _gateway;
  final ResourceStore? _resourceStore;
  final String Function() _idGenerator;
  final DateTime Function() _now;
  final QuickPasteGateway? _quickPasteGateway;
  final DataRevisionBus? _revisions;
  final Directory? _managedImageDirectory;
  final ClipboardCategoryRuleStore _categoryRuleStore;
  final ClipboardGroupOrderStore _groupOrderStore;
  List<ClipboardRecord> _records = const <ClipboardRecord>[];
  List<ClipboardArchiveEntry> _archives = const <ClipboardArchiveEntry>[];
  List<ClipboardCategoryRule> _categoryRules = const <ClipboardCategoryRule>[];
  final List<String> _groupOrder = <String>[];
  String _query = '';
  ClipboardKind? _selectedKind;
  String? _selectedCategoryId;
  String? _selectedGroup;
  final Set<String> _selectedSourceIds = <String>{};
  ClipboardRecord? _selectedRecord;

  ClipboardRecord? get selectedRecord => _selectedRecord;

  bool get selectedRecordIsArchived =>
      _selectedRecord != null &&
      _archiveEntryForId(_selectedRecord!.id) != null;

  String get query => _query;

  ClipboardKind? get selectedKind => _selectedKind;

  String? get selectedCategoryId => _selectedCategoryId;

  bool get hasActiveFilters =>
      _selectedKind != null ||
      _selectedCategoryId != null ||
      _selectedGroup != null ||
      _selectedSourceIds.isNotEmpty;

  Set<String> get selectedSourceIds =>
      Set<String>.unmodifiable(_selectedSourceIds);

  List<ClipboardSourceOption> get sourceOptions {
    final Map<String, ClipboardSourceOption> options =
        <String, ClipboardSourceOption>{};
    for (final ClipboardRecord record in _activeRecords) {
      final ClipboardSourceOption? option = clipboardSourceOption(
        record.source,
      );
      if (option != null) {
        options.putIfAbsent(option.id, () => option);
      }
    }
    return List<ClipboardSourceOption>.unmodifiable(options.values);
  }

  List<ClipboardCategoryRule> get categoryRules =>
      List<ClipboardCategoryRule>.unmodifiable(_categoryRules);

  List<ClipboardCategoryRule> get availableCategories => _categoryRules
      .where(
        (ClipboardCategoryRule rule) =>
            rule.enabled &&
            _activeRecords.any(
              (ClipboardRecord record) => rule.matches(record),
            ),
      )
      .toList(growable: false);

  ClipboardCategoryRule? categoryFor(ClipboardRecord record) {
    for (final ClipboardCategoryRule rule in _categoryRules) {
      if (rule.matches(record)) {
        return rule;
      }
    }
    return null;
  }

  String? get selectedGroup => _selectedGroup;

  List<String> get groups {
    // Keep groups from the durable order file even when they currently have
    // no records. This is important for recovery: a user can select an empty
    // PageID group and explicitly assign reviewed records to it later.
    final Map<String, String> valuesByKey = <String, String>{};
    void addGroup(String value) {
      final String group = value.trim();
      if (group.isEmpty || isAutomaticClipboardGroup(group)) {
        return;
      }
      valuesByKey.putIfAbsent(_groupKey(group), () => group);
    }

    for (final String group in _groupOrder) {
      addGroup(group);
    }
    for (final ClipboardArchiveEntry entry in _archives) {
      for (final String group in entry.record.groupNames) {
        addGroup(group);
      }
    }

    final Map<String, int> orderByKey = <String, int>{};
    for (int index = 0; index < _groupOrder.length; index++) {
      final String group = _groupOrder[index].trim();
      if (group.isNotEmpty && !isAutomaticClipboardGroup(group)) {
        orderByKey.putIfAbsent(_groupKey(group), () => index);
      }
    }

    final List<String> groups = valuesByKey.values.toList();
    return groups..sort((String left, String right) {
      final int? leftRank = orderByKey[_groupKey(left)];
      final int? rightRank = orderByKey[_groupKey(right)];
      if (leftRank != null || rightRank != null) {
        if (leftRank == null) return 1;
        if (rightRank == null) return -1;
        return leftRank.compareTo(rightRank);
      }
      return _groupKey(left).compareTo(_groupKey(right));
    });
  }

  List<ClipboardRecord> get allRecords =>
      List<ClipboardRecord>.unmodifiable(<ClipboardRecord>[
        ..._records,
        ..._archives.map((ClipboardArchiveEntry entry) => entry.record),
      ]);

  List<ClipboardRecord> get archiveRecords =>
      List<ClipboardRecord>.unmodifiable(
        _archives.map((ClipboardArchiveEntry entry) => entry.record),
      );

  List<ClipboardRecord> get _activeRecords => _selectedGroup == null
      ? _records
      : _archives.map((ClipboardArchiveEntry entry) => entry.record).toList();

  List<ClipboardRecord> get visibleRecords {
    final String needle = _query.trim().toLowerCase();
    return List<ClipboardRecord>.unmodifiable(
      _activeRecords.where((ClipboardRecord record) {
        if (_selectedKind != null && record.kind != _selectedKind) {
          return false;
        }
        if (_selectedCategoryId != null &&
            categoryFor(record)?.id != _selectedCategoryId) {
          return false;
        }
        if (_selectedGroup != null &&
            !record.groupNames.any(
              (String group) => _groupKey(group) == _groupKey(_selectedGroup!),
            )) {
          return false;
        }
        final ClipboardSourceOption? source = clipboardSourceOption(
          record.source,
        );
        if (_selectedSourceIds.isNotEmpty &&
            (source == null || !_selectedSourceIds.contains(source.id))) {
          return false;
        }
        return needle.isEmpty ||
            record.title.toLowerCase().contains(needle) ||
            record.content.toLowerCase().contains(needle) ||
            (record.source?.toLowerCase().contains(needle) ?? false) ||
            record.groupNames.any(
              (String group) => group.toLowerCase().contains(needle),
            ) ||
            record.tags.any((String tag) => tag.toLowerCase().contains(needle));
      }),
    );
  }

  void load() {
    _records = _store.list(limit: 5000, includeProtectedBeyondLimit: true);
    _archives = _archiveStore.listArchives();
    _categoryRules = List<ClipboardCategoryRule>.of(_categoryRuleStore.load());
    _groupOrder
      ..clear()
      ..addAll(_groupOrderStore.load());
    if (_selectedCategoryId != null &&
        !_categoryRules.any(
          (ClipboardCategoryRule rule) =>
              rule.enabled && rule.id == _selectedCategoryId,
        )) {
      _selectedCategoryId = null;
    }
    _pruneSelectedSources();
    _ensureSelectionVisible();
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    _ensureSelectionVisible();
    notifyListeners();
  }

  void setKind(ClipboardKind? value) {
    _selectedKind = value;
    _selectedCategoryId = null;
    _ensureSelectionVisible();
    notifyListeners();
  }

  void setCategory(String? value) {
    _selectedCategoryId = value;
    _selectedKind = null;
    _ensureSelectionVisible();
    notifyListeners();
  }

  void reorderCategories(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _categoryRules.length) return;
    final ClipboardCategoryRule moved = _categoryRules.removeAt(oldIndex);
    _categoryRules.insert(newIndex.clamp(0, _categoryRules.length), moved);
    _categoryRuleStore.save(_categoryRules);
    notifyListeners();
  }

  void saveCategoryRule(ClipboardCategoryRule rule) {
    final String? validationError = rule.validationError;
    if (validationError != null) {
      throw FormatException(validationError);
    }
    final int index = _categoryRules.indexWhere(
      (ClipboardCategoryRule item) => item.id == rule.id,
    );
    if (index < 0) {
      _categoryRules = <ClipboardCategoryRule>[..._categoryRules, rule];
    } else {
      _categoryRules = <ClipboardCategoryRule>[
        ..._categoryRules.take(index),
        rule,
        ..._categoryRules.skip(index + 1),
      ];
    }
    _categoryRuleStore.save(_categoryRules);
    notifyListeners();
  }

  void deleteCategoryRule(String id) {
    _categoryRules = _categoryRules
        .where((ClipboardCategoryRule rule) => rule.id != id)
        .toList(growable: false);
    if (_selectedCategoryId == id) {
      _selectedCategoryId = null;
    }
    _categoryRuleStore.save(_categoryRules);
    _ensureSelectionVisible();
    notifyListeners();
  }

  void moveGroup(String group, {required String before}) {
    if (group == before) return;
    final List<String> current = groups;
    _groupOrder
      ..clear()
      ..addAll(current);
    _groupOrder.remove(group);
    _groupOrder.insert(_groupOrder.indexOf(before), group);
    _groupOrderStore.save(_groupOrder);
    notifyListeners();
  }

  void reorderGroups(int oldIndex, int newIndex) {
    final List<String> visible = groups;
    if (oldIndex < 0 || oldIndex >= visible.length) return;
    final String moved = visible.removeAt(oldIndex);
    visible.insert(newIndex.clamp(0, visible.length), moved);
    _groupOrder
      ..clear()
      ..addAll(visible);
    _groupOrderStore.save(_groupOrder);
    notifyListeners();
  }

  void setGroup(String? value) {
    _selectedGroup = value;
    _ensureSelectionVisible();
    notifyListeners();
  }

  void moveGroupSelection(int offset) {
    if (offset == 0 || groups.isEmpty) return;
    final List<String?> destinations = <String?>[null, ...groups];
    final int current = _selectedGroup == null
        ? 0
        : destinations.indexWhere(
            (String? group) =>
                group != null && _groupKey(group) == _groupKey(_selectedGroup!),
          );
    final int next = ((current < 0 ? 0 : current) + offset).clamp(
      0,
      destinations.length - 1,
    );
    setGroup(destinations[next]);
  }

  void selectGroupAt(int index) {
    final List<String> available = groups;
    if (index < 0 || index >= available.length) return;
    setGroup(available[index]);
  }

  void toggleSource(String id) {
    final bool available = sourceOptions.any(
      (ClipboardSourceOption option) => option.id == id,
    );
    if (!available) {
      return;
    }
    if (!_selectedSourceIds.add(id)) {
      _selectedSourceIds.remove(id);
    }
    _ensureSelectionVisible();
    notifyListeners();
  }

  void clearSources() {
    if (_selectedSourceIds.isEmpty) {
      return;
    }
    _selectedSourceIds.clear();
    _ensureSelectionVisible();
    notifyListeners();
  }

  void clearFilters() {
    if (!hasActiveFilters) {
      return;
    }
    _selectedKind = null;
    _selectedCategoryId = null;
    _selectedGroup = null;
    _selectedSourceIds.clear();
    _ensureSelectionVisible();
    notifyListeners();
  }

  int groupItemCount(String group) {
    final String normalized = _groupKey(group);
    if (normalized.isEmpty) return 0;
    return _archives
        .where(
          (ClipboardArchiveEntry entry) => entry.record.groupNames.any(
            (String value) => _groupKey(value) == normalized,
          ),
        )
        .length;
  }

  void deleteGroup(String group) {
    final String normalized = _groupKey(group);
    if (normalized.isEmpty) return;
    final Set<String> affectedIds = _archives
        .where(
          (ClipboardArchiveEntry entry) => entry.record.groupNames.any(
            (String value) => _groupKey(value) == normalized,
          ),
        )
        .map((ClipboardArchiveEntry entry) => entry.record.id)
        .toSet();
    _groupOrder.removeWhere((String value) => _groupKey(value) == normalized);
    _groupOrderStore.save(_groupOrder);
    if (_selectedGroup != null && _groupKey(_selectedGroup!) == normalized) {
      _selectedGroup = null;
    }
    if (affectedIds.isEmpty) {
      notifyListeners();
      return;
    }
    final DateTime timestamp = _now().toUtc();
    for (final String id in affectedIds) {
      final ClipboardArchiveEntry? entry = _archiveEntryForId(id);
      if (entry == null) continue;
      final List<String> remaining = entry.record.groupNames
          .where((String value) => _groupKey(value) != normalized)
          .toList(growable: false);
      if (remaining.isEmpty) {
        _archiveStore.deleteArchive(id);
      } else {
        _archiveStore.saveArchive(
          ClipboardArchiveEntry(
            record: entry.record.copyWith(
              groups: remaining,
              updatedAt: timestamp,
            ),
            sourceClipboardId: entry.sourceClipboardId,
            archivedAt: entry.archivedAt,
          ),
        );
      }
    }
    _archives = _archiveStore.listArchives();
    _ensureSelectionVisible();
    _revisions?.changed(DataCollection.clipboard);
    notifyListeners();
  }

  void select(ClipboardRecord record) {
    _selectedRecord = record;
    notifyListeners();
  }

  void moveSelection(int offset) {
    final List<ClipboardRecord> visible = visibleRecords;
    if (visible.isEmpty) {
      return;
    }
    final int current = _selectedRecord == null
        ? -1
        : visible.indexWhere(
            (ClipboardRecord record) => record.id == _selectedRecord?.id,
          );
    final int next = current < 0
        ? (offset < 0 ? visible.length - 1 : 0)
        : (current + offset).clamp(0, visible.length - 1);
    _selectedRecord = visible[next];
    notifyListeners();
  }

  Future<bool> restoreVisibleAt(
    int index, {
    ClipboardPasteMode mode = ClipboardPasteMode.original,
  }) async {
    final List<ClipboardRecord> visible = visibleRecords;
    if (index < 0 || index >= visible.length) {
      return false;
    }
    _selectedRecord = visible[index];
    notifyListeners();
    return restoreSelected(mode: mode);
  }

  void togglePinned() {
    final ClipboardRecord? selected = _selectedRecord;
    if (selected == null) {
      return;
    }
    final bool pinned = !selected.pinned;
    final ClipboardRecord updated = selected.copyWith(
      pinned: pinned,
      activation: pinned ? 'always' : 'taskMatch',
      updatedAt: _now().toUtc(),
    );
    _saveSelectedRecord(updated);
    _revisions?.changed(DataCollection.clipboard);
    _reloadRecords();
    _selectedRecord = updated;
    notifyListeners();
  }

  void organizeSelected({
    required String title,
    required String content,
    required String group,
    required List<String> tags,
  }) {
    final ClipboardRecord? selected = _selectedRecord;
    if (selected == null || title.trim().isEmpty || content.trim().isEmpty) {
      return;
    }
    final String requestedGroup = group.trim();
    final bool contentChanged = content != selected.content;
    final bool archived = _archiveEntryForId(selected.id) != null;
    final ClipboardRecord updated = selected.copyWith(
      title: title.trim(),
      content: content,
      replaceFormattedText: contentChanged,
      groups: archived && requestedGroup == selected.group
          ? selected.groupNames
          : archived && requestedGroup.isNotEmpty
          ? <String>[requestedGroup]
          : const <String>[],
      tags: _uniqueTags(<String>[...selected.tags, ...tags]),
      updatedAt: _now().toUtc(),
    );
    _saveSelectedRecord(updated);
    _revisions?.changed(DataCollection.clipboard);
    _reloadRecords();
    _selectedRecord = updated;
    if (!archived && requestedGroup.isNotEmpty) {
      _archiveSource(updated, <String>{requestedGroup});
    }
    notifyListeners();
  }

  void addSelectedToGroups(Set<String> groups) {
    final ClipboardRecord? selected = _selectedRecord;
    if (selected == null) {
      return;
    }
    final ClipboardArchiveEntry? archive = _archiveEntryForId(selected.id);
    if (archive == null) {
      _archiveSource(selected, groups);
    } else {
      final ClipboardRecord updated = selected.copyWith(
        groups: _uniqueGroups(<String>[...selected.groupNames, ...groups]),
        updatedAt: _now().toUtc(),
      );
      _archiveStore.saveArchive(
        ClipboardArchiveEntry(
          record: updated,
          sourceClipboardId: archive.sourceClipboardId,
          archivedAt: archive.archivedAt,
        ),
      );
      _reloadRecords();
      _selectedRecord = updated;
    }
    _revisions?.changed(DataCollection.clipboard);
    notifyListeners();
  }

  void addManyToGroups(Set<String> ids, Set<String> groups) {
    // The caller owns the recovery scope: only these explicit IDs are
    // changed. Do not infer IDs from title/content/tags here.
    for (final String id in ids) {
      final ClipboardArchiveEntry? archive = _archiveEntryForId(id);
      if (archive != null) {
        _archiveStore.saveArchive(
          ClipboardArchiveEntry(
            record: archive.record.copyWith(
              groups: _uniqueGroups(<String>[
                ...archive.record.groupNames,
                ...groups,
              ]),
              updatedAt: _now().toUtc(),
            ),
            sourceClipboardId: archive.sourceClipboardId,
            archivedAt: archive.archivedAt,
          ),
        );
        continue;
      }
      final ClipboardRecord? source = _recordForId(id);
      if (source != null) {
        _archiveSource(source, groups, reload: false);
      }
    }
    _reloadRecords();
    _ensureSelectionVisible();
    _revisions?.changed(DataCollection.clipboard);
    notifyListeners();
  }

  void setEnabledMany(Set<String> ids, bool enabled) {
    _updateMany(
      ids,
      (ClipboardRecord record) =>
          record.copyWith(enabled: enabled, updatedAt: _now().toUtc()),
    );
  }

  void deleteMany(Set<String> ids) {
    final List<ClipboardRecord> deleted = <ClipboardRecord>[];
    for (final String id in ids) {
      final ClipboardArchiveEntry? archive = _archiveEntryForId(id);
      if (archive != null) {
        _archiveStore.deleteArchive(id);
        deleted.add(archive.record);
      } else {
        final ClipboardRecord? source = _recordForId(id);
        _store.delete(id);
        if (source != null) deleted.add(source);
      }
    }
    _reloadRecords();
    for (final ClipboardRecord record in deleted) {
      _deleteManagedImageIfUnreferenced(record);
    }
    _pruneSelectedSources();
    if (ids.contains(_selectedRecord?.id)) _selectedRecord = null;
    _ensureSelectionVisible();
    _revisions?.changed(DataCollection.clipboard);
    notifyListeners();
  }

  void _updateMany(
    Set<String> ids,
    ClipboardRecord Function(ClipboardRecord record) update,
  ) {
    final String? selectedId = _selectedRecord?.id;
    for (final String id in ids) {
      final ClipboardArchiveEntry? archive = _archiveEntryForId(id);
      if (archive != null) {
        _archiveStore.saveArchive(
          ClipboardArchiveEntry(
            record: update(archive.record),
            sourceClipboardId: archive.sourceClipboardId,
            archivedAt: archive.archivedAt,
          ),
        );
      } else {
        final ClipboardRecord? source = _recordForId(id);
        if (source != null) _store.save(update(source));
      }
    }
    _reloadRecords();
    if (selectedId != null) {
      final int selectedIndex = allRecords.indexWhere(
        (ClipboardRecord record) => record.id == selectedId,
      );
      _selectedRecord = selectedIndex < 0 ? null : allRecords[selectedIndex];
    }
    _ensureSelectionVisible();
    _revisions?.changed(DataCollection.clipboard);
    notifyListeners();
  }

  void deleteSelected() {
    final ClipboardRecord? selected = _selectedRecord;
    if (selected == null) {
      return;
    }
    final ClipboardArchiveEntry? archive = _archiveEntryForId(selected.id);
    if (archive != null) {
      _archiveStore.deleteArchive(selected.id);
    } else {
      _store.delete(selected.id);
    }
    _revisions?.changed(DataCollection.clipboard);
    _reloadRecords();
    _deleteManagedImageIfUnreferenced(selected);
    _pruneSelectedSources();
    _selectedRecord = null;
    _ensureSelectionVisible();
    notifyListeners();
  }

  Future<Resource?> promoteSelected(ResourceType targetType) async {
    final ClipboardRecord? selected = _selectedRecord;
    final ResourceStore? resourceStore = _resourceStore;
    if (selected == null ||
        resourceStore == null ||
        !targetType.isLibraryResource) {
      return null;
    }
    final DateTime timestamp = _now().toUtc();
    final Resource resource = Resource(
      id: _idGenerator(),
      type: targetType,
      title: selected.title,
      content: selected.content,
      tags: _uniqueTags(
        selected.tags.where((String tag) => tag != 'clipboard').toList(),
      ),
      source: 'Clipboard Promotion',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    await resourceStore.save(<Resource>[
      ...await resourceStore.load(),
      resource,
    ]);
    _revisions?.changed(DataCollection.library);
    return resource;
  }

  Future<bool> restoreSelected({
    ClipboardPasteMode mode = ClipboardPasteMode.original,
  }) async {
    final bool copied = await copySelected(mode: mode);
    if (copied) {
      await _quickPasteGateway?.pasteIntoPreviousApplication();
    }
    return copied;
  }

  /// Copies the selected record without pasting into another application.
  Future<bool> copySelected({
    ClipboardPasteMode mode = ClipboardPasteMode.original,
  }) async {
    final ClipboardRecord? selected = _selectedRecord;
    final ClipboardGateway? gateway = _gateway;
    if (selected == null || gateway == null) {
      return false;
    }
    if (mode == ClipboardPasteMode.plainText && !selected.canPasteAsPlainText) {
      return false;
    }
    if (selected.tags.contains('file-url')) {
      final List<String> paths = selected.content
          .split('\n')
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toList(growable: false);
      if (paths.isNotEmpty) {
        if (mode == ClipboardPasteMode.original &&
            selected.kind == ClipboardKind.image &&
            paths.length == 1 &&
            gateway is ImageClipboardGateway) {
          final ImageClipboardGateway imageGateway =
              gateway as ImageClipboardGateway;
          final bool written = await imageGateway.writeImageFile(paths.single);
          if (written) {
            return true;
          }
        }
        await gateway.writeFiles(paths);
        return true;
      }
    }
    if (mode == ClipboardPasteMode.original &&
        selected.hasFormattedText &&
        gateway is FormattedTextClipboardGateway) {
      final FormattedTextClipboardGateway formattedGateway =
          gateway as FormattedTextClipboardGateway;
      await formattedGateway.writeFormattedText(
        plainText: selected.content,
        htmlData: selected.htmlData,
        rtfData: selected.rtfData,
      );
      return true;
    }
    await gateway.writeText(selected.content);
    return true;
  }

  void _archiveSource(
    ClipboardRecord source,
    Set<String> groups, {
    bool reload = true,
  }) {
    final List<String> requestedGroups = _uniqueGroups(groups);
    if (requestedGroups.isEmpty) return;
    final DateTime timestamp = _now().toUtc();
    ClipboardArchiveEntry? entry;
    for (final ClipboardArchiveEntry candidate in _archives) {
      if (candidate.sourceClipboardId == source.id) {
        entry = candidate;
        break;
      }
    }
    if (entry != null) {
      _archiveStore.saveArchive(
        ClipboardArchiveEntry(
          record: entry.record.copyWith(
            groups: _uniqueGroups(<String>[
              ...entry.record.groupNames,
              ...requestedGroups,
            ]),
            updatedAt: timestamp,
          ),
          sourceClipboardId: entry.sourceClipboardId,
          archivedAt: entry.archivedAt,
        ),
      );
    } else {
      final ClipboardRecord snapshot = ClipboardRecord(
        id: _idGenerator(),
        group: requestedGroups.first,
        groups: requestedGroups,
        title: source.title,
        content: source.content,
        htmlData: source.htmlData,
        rtfData: source.rtfData,
        tags: List<String>.of(source.tags),
        source: source.source,
        pinned: source.pinned,
        enabled: source.enabled,
        activation: source.activation,
        sortOrder: source.sortOrder,
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      _archiveStore.saveArchive(
        ClipboardArchiveEntry(
          record: snapshot,
          sourceClipboardId: source.id,
          archivedAt: timestamp,
        ),
      );
    }
    if (reload) _reloadRecords();
  }

  void _saveSelectedRecord(ClipboardRecord record) {
    final ClipboardArchiveEntry? archive = _archiveEntryForId(record.id);
    if (archive == null) {
      _store.save(record);
      return;
    }
    _archiveStore.saveArchive(
      ClipboardArchiveEntry(
        record: record,
        sourceClipboardId: archive.sourceClipboardId,
        archivedAt: archive.archivedAt,
      ),
    );
  }

  ClipboardRecord? _recordForId(String id) {
    for (final ClipboardRecord record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }

  ClipboardArchiveEntry? _archiveEntryForId(String id) {
    for (final ClipboardArchiveEntry entry in _archives) {
      if (entry.record.id == id) return entry;
    }
    return null;
  }

  void _reloadRecords() {
    _records = _store.list(limit: 5000, includeProtectedBeyondLimit: true);
    _archives = _archiveStore.listArchives();
  }

  void _deleteManagedImageIfUnreferenced(ClipboardRecord deleted) {
    final Directory? directory = _managedImageDirectory;
    if (directory == null ||
        allRecords.any(
          (ClipboardRecord record) =>
              record.content == deleted.content &&
              record.tags.contains('image') &&
              record.tags.contains('file-url'),
        )) {
      return;
    }
    deleteManagedClipboardImage(deleted, directory);
  }

  Future<void> captureNow() async {
    final ClipboardCaptureService? service = _captureService;
    if (service == null) {
      return;
    }
    final ClipboardRecord? captured = await service.capture();
    if (captured == null) {
      return;
    }
    _reloadRecords();
    _pruneSelectedSources();
    _selectedRecord = captured;
    notifyListeners();
    _revisions?.changed(DataCollection.clipboard);
  }

  void _ensureSelectionVisible() {
    final List<ClipboardRecord> visible = visibleRecords;
    if (visible.isEmpty) {
      _selectedRecord = null;
      return;
    }
    final String? selectedId = _selectedRecord?.id;
    for (final ClipboardRecord record in visible) {
      if (record.id == selectedId) {
        _selectedRecord = record;
        return;
      }
    }
    _selectedRecord = visible.first;
  }

  void _pruneSelectedSources() {
    if (_selectedSourceIds.isEmpty) {
      return;
    }
    final Set<String> availableSourceIds = sourceOptions
        .map((ClipboardSourceOption option) => option.id)
        .toSet();
    _selectedSourceIds.removeWhere(
      (String id) => !availableSourceIds.contains(id),
    );
  }
}

List<String> _uniqueTags(List<String> tags) {
  final Set<String> seen = <String>{};
  return tags
      .where((String tag) {
        final String normalized = tag.trim().toLowerCase();
        return normalized.isNotEmpty && seen.add(normalized);
      })
      .map((String tag) => tag.trim())
      .toList(growable: false);
}

String _groupKey(String value) => value.trim().toLowerCase();

List<String> _uniqueGroups(Iterable<String> values) {
  final Set<String> seen = <String>{};
  return values
      .map((String value) => value.trim())
      .where(
        (String value) => value.isNotEmpty && seen.add(value.toLowerCase()),
      )
      .toList(growable: false);
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
