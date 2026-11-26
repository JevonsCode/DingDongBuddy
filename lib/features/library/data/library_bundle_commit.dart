import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/utils/uuid.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/library_bundle.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';

typedef LibraryBundleCommit = ({
  LibraryBundleImportResult result,
  List<Resource> resources,
  List<TriggerGroup>? groups,
});

/// Rechecks duplicates and binds portable conditions to recipient-owned groups.
Future<LibraryBundleCommit> commitLibraryBundle(
  LibraryBundleImportResult prepared,
  ResourceStore store,
  TriggerGroupStore? groupStore,
) {
  Future<LibraryBundleCommit> commit() async {
    final existing = await store.load();
    final merged = LibraryBundle.mergeResources(
      prepared.imported,
      existing: existing,
    );
    final reviewRules = {
      for (final item in merged.imported)
        if (prepared.reviewRules.containsKey(item.id))
          item.id: prepared.reviewRules[item.id]!,
    };
    final hasConditions = reviewRules.values.any((rules) => rules.isNotEmpty);
    if (hasConditions && groupStore == null) {
      throw StateError('Trigger group store unavailable');
    }
    final previous = hasConditions
        ? await groupStore!.load()
        : <TriggerGroup>[];
    final groups = [...previous];
    final imported = <Resource>[];
    for (final item in merged.imported) {
      final rules = reviewRules[item.id];
      if (rules == null || rules.isEmpty) {
        imported.add(item);
        continue;
      }
      final conditions = rules.toSet();
      var group = groups
          .where(
            (group) =>
                group.rules.toSet().length == conditions.length &&
                conditions.containsAll(group.rules),
          )
          .firstOrNull;
      if (group == null) {
        final now = DateTime.now().toUtc();
        group = TriggerGroup(
          id: generateUuid(),
          name: item.title,
          rules: rules,
          createdAt: now,
          updatedAt: now,
        );
        groups.add(group);
      }
      imported.add(item.copyWith(triggerGroupIds: [group.id], enabled: false));
    }
    final resources = [...existing, ...imported];
    final addedGroups = groups.length != previous.length;
    if (addedGroups) await groupStore!.save(groups);
    try {
      if (imported.isNotEmpty) await store.save(resources);
    } catch (_) {
      if (addedGroups) await groupStore!.save(previous);
      rethrow;
    }
    return (
      result: LibraryBundleImportResult(
        imported: imported,
        duplicateIds: [...prepared.duplicateIds, ...merged.duplicateIds],
        conflictIds: [...prepared.conflictIds, ...merged.conflictIds],
        onlineResources: prepared.onlineResources,
        reviewRules: reviewRules,
      ),
      resources: resources,
      groups: hasConditions ? groups : null,
    );
  }

  Future<LibraryBundleCommit> withGroupLock() =>
      prepared.reviewRules.values.any((rules) => rules.isNotEmpty) &&
          groupStore is ExclusiveTriggerGroupStore
      ? (groupStore as ExclusiveTriggerGroupStore).exclusiveMutation(commit)
      : commit();
  return store is ExclusiveResourceStore
      ? (store as ExclusiveResourceStore).exclusiveMutation(withGroupLock)
      : withGroupLock();
}
