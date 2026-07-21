// ignore_for_file: prefer_initializing_formals

import 'dart:async';
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
import 'package:dingdong/features/clipboard/domain/quick_paste_gateway.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:flutter/foundation.dart';

/// Observable filters and selection for clipboard history.
final class ClipboardViewModel extends ChangeNotifier {
  ClipboardViewModel(
    this._store, {
    ClipboardCaptureService? captureService,
    ClipboardGateway? gateway,
    ResourceStore? resourceStore,
    String Function()? idGenerator,
    DateTime Function()? now,
    QuickPasteGateway? quickPasteGateway,
    DataRevisionBus? revisions,
    ClipboardCategoryRuleStore? categoryRuleStore,
    ClipboardGroupOrderStore? groupOrderStore,
  }) : _captureService = captureService,
       _gateway = gateway,
       _resourceStore = resourceStore,
       _idGenerator = idGenerator ?? _generateUuid,
       _now = now ?? _utcNow,
       _quickPasteGateway = quickPasteGateway,
       _revisions = revisions,
       _categoryRuleStore =
           categoryRuleStore ?? InMemoryClipboardCategoryRuleStore(),
       _groupOrderStore = groupOrderStore ?? InMemoryClipboardGroupOrderStore();

  final ClipboardStore _store;
  final ClipboardCaptureService? _captureService;
  final ClipboardGateway? _gateway;
  final ResourceStore? _resourceStore;
  final String Function() _idGenerator;
  final DateTime Function() _now;
  final QuickPasteGateway? _quickPasteGateway;
  final DataRevisionBus? _revisions;
  final ClipboardCategoryRuleStore _categoryRuleStore;
  final ClipboardGroupOrderStore _groupOrderStore;
  List<ClipboardRecord> _records = const <ClipboardRecord>[];
  List<ClipboardCategoryRule> _categoryRules = const <ClipboardCategoryRule>[];
  final List<String> _groupOrder = <String>[];
  String _query = '';
  ClipboardKind? _selectedKind;
  String? _selectedCategoryId;
  String? _selectedGroup;
  ClipboardRecord? _selectedRecord;

  ClipboardRecord? get selectedRecord => _selectedRecord;

  ClipboardKind? get selectedKind => _selectedKind;

  String? get selectedCategoryId => _selectedCategoryId;

  List<ClipboardCategoryRule> get categoryRules =>
      List<ClipboardCategoryRule>.unmodifiable(_categoryRules);

  List<ClipboardCategoryRule> get availableCategories => _categoryRules
      .where(
        (ClipboardCategoryRule rule) =>
            rule.enabled &&
            _records.any((ClipboardRecord record) => rule.matches(record)),
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
    final Set<String> values = _records
        .expand((ClipboardRecord record) => record.groupNames)
        .map((String group) => group.trim())
        .where(
          (String group) =>
              group.isNotEmpty && !_legacyAutomaticGroups.contains(group),
        )
        .toSet();
    final List<String> groups = values.toList();
    return groups..sort((String left, String right) {
      final int leftRank = _groupOrder.indexOf(left);
      final int rightRank = _groupOrder.indexOf(right);
      if (leftRank >= 0 || rightRank >= 0) {
        if (leftRank < 0) return 1;
        if (rightRank < 0) return -1;
        return leftRank.compareTo(rightRank);
      }
      return left.toLowerCase().compareTo(right.toLowerCase());
    });
  }

  List<ClipboardRecord> get allRecords =>
      List<ClipboardRecord>.unmodifiable(_records);

  List<ClipboardRecord> get visibleRecords {
    final String needle = _query.trim().toLowerCase();
    return List<ClipboardRecord>.unmodifiable(
      _records.where((ClipboardRecord record) {
        if (_selectedKind != null && record.kind != _selectedKind) {
          return false;
        }
        if (_selectedCategoryId != null &&
            categoryFor(record)?.id != _selectedCategoryId) {
          return false;
        }
        if (_selectedGroup != null &&
            !record.groupNames.contains(_selectedGroup)) {
          return false;
        }
        return needle.isEmpty ||
            record.title.toLowerCase().contains(needle) ||
            record.content.toLowerCase().contains(needle) ||
            record.groupNames.any(
              (String group) => group.toLowerCase().contains(needle),
            ) ||
            record.tags.any((String tag) => tag.toLowerCase().contains(needle));
      }),
    );
  }

  void load() {
    _records = _store.list(limit: 5000);
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

  int groupItemCount(String group) {
    final String normalized = group.trim().toLowerCase();
    if (normalized.isEmpty) return 0;
    return _records
        .where(
          (ClipboardRecord record) => record.groupNames.any(
            (String value) => value.toLowerCase() == normalized,
          ),
        )
        .length;
  }

  void deleteGroup(String group) {
    final String normalized = group.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final Set<String> affectedIds = _records
        .where(
          (ClipboardRecord record) => record.groupNames.any(
            (String value) => value.toLowerCase() == normalized,
          ),
        )
        .map((ClipboardRecord record) => record.id)
        .toSet();
    _groupOrder.removeWhere(
      (String value) => value.toLowerCase() == normalized,
    );
    _groupOrderStore.save(_groupOrder);
    if (_selectedGroup?.toLowerCase() == normalized) {
      _selectedGroup = null;
    }
    if (affectedIds.isEmpty) {
      notifyListeners();
      return;
    }
    _updateMany(
      affectedIds,
      (ClipboardRecord record) => record.copyWith(
        groups: record.groupNames
            .where((String value) => value.toLowerCase() != normalized)
            .toList(growable: false),
        updatedAt: _now().toUtc(),
      ),
    );
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

  Future<void> restoreVisibleAt(int index) async {
    final List<ClipboardRecord> visible = visibleRecords;
    if (index < 0 || index >= visible.length) {
      return;
    }
    _selectedRecord = visible[index];
    notifyListeners();
    await restoreSelected();
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
    _store.save(updated);
    _revisions?.changed(DataCollection.clipboard);
    _records = <ClipboardRecord>[
      updated,
      ..._records.where((ClipboardRecord record) => record.id != updated.id),
    ];
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
    final ClipboardRecord updated = selected.copyWith(
      title: title.trim(),
      content: content,
      groups: requestedGroup == selected.group
          ? selected.groupNames
          : <String>[requestedGroup],
      tags: _uniqueTags(<String>[...selected.tags, ...tags]),
      updatedAt: _now().toUtc(),
    );
    _store.save(updated);
    _revisions?.changed(DataCollection.clipboard);
    _records = <ClipboardRecord>[
      updated,
      ..._records.where((ClipboardRecord record) => record.id != updated.id),
    ];
    _selectedRecord = updated;
    notifyListeners();
  }

  void addSelectedToGroups(Set<String> groups) {
    final ClipboardRecord? selected = _selectedRecord;
    if (selected == null) {
      return;
    }
    final ClipboardRecord updated = selected.copyWith(
      groups: _uniqueGroups(<String>[...selected.groupNames, ...groups]),
      updatedAt: _now().toUtc(),
    );
    _store.save(updated);
    _revisions?.changed(DataCollection.clipboard);
    _records = <ClipboardRecord>[
      updated,
      ..._records.where((ClipboardRecord record) => record.id != updated.id),
    ];
    _selectedRecord = updated;
    notifyListeners();
  }

  void addManyToGroups(Set<String> ids, Set<String> groups) {
    _updateMany(
      ids,
      (ClipboardRecord record) => record.copyWith(
        groups: _uniqueGroups(<String>[...record.groupNames, ...groups]),
        updatedAt: _now().toUtc(),
      ),
    );
  }

  void setEnabledMany(Set<String> ids, bool enabled) {
    _updateMany(
      ids,
      (ClipboardRecord record) =>
          record.copyWith(enabled: enabled, updatedAt: _now().toUtc()),
    );
  }

  void deleteMany(Set<String> ids) {
    for (final String id in ids) {
      _store.delete(id);
    }
    _records = _records
        .where((ClipboardRecord record) => !ids.contains(record.id))
        .toList(growable: false);
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
    _records = _records
        .map((ClipboardRecord record) {
          if (!ids.contains(record.id)) return record;
          final ClipboardRecord updated = update(record);
          _store.save(updated);
          return updated;
        })
        .toList(growable: false);
    if (selectedId != null) {
      final int selectedIndex = _records.indexWhere(
        (ClipboardRecord record) => record.id == selectedId,
      );
      _selectedRecord = selectedIndex < 0 ? null : _records[selectedIndex];
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
    _store.delete(selected.id);
    _revisions?.changed(DataCollection.clipboard);
    _records = _records
        .where((ClipboardRecord record) => record.id != selected.id)
        .toList(growable: false);
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

  Future<void> restoreSelected() async {
    await copySelected();
    if (_selectedRecord != null) {
      await _quickPasteGateway?.pasteIntoPreviousApplication();
    }
  }

  /// Copies the selected record without pasting into another application.
  Future<void> copySelected() async {
    final ClipboardRecord? selected = _selectedRecord;
    final ClipboardGateway? gateway = _gateway;
    if (selected == null || gateway == null) {
      return;
    }
    if (selected.tags.contains('file-url')) {
      final List<String> paths = selected.content
          .split('\n')
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toList(growable: false);
      if (paths.isNotEmpty) {
        await gateway.writeFiles(paths);
        return;
      }
    }
    await gateway.writeText(selected.content);
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
    _records = _store.list(limit: 5000);
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
}

const Set<String> _legacyAutomaticGroups = <String>{
  'Archive',
  'Clipboard',
  'Code',
  'Commands',
  'Email',
  'Files',
  'Images',
  'JSON',
  'Paths',
  'Sensitive',
  'URLs',
};

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
