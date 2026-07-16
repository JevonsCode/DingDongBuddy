import 'package:dingdong/features/library/data/trigger_group_file_service.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';

abstract interface class TriggerGroupStore {
  Future<List<TriggerGroup>> load();

  Future<void> save(List<TriggerGroup> groups);
}

final class TriggerGroupRepository implements TriggerGroupStore {
  TriggerGroupRepository(this._service);

  final TriggerGroupFileService _service;

  @override
  Future<List<TriggerGroup>> load() => _service.readGroups();

  @override
  Future<void> save(List<TriggerGroup> groups) =>
      _service.writeAtomically(groups);
}

final class InMemoryTriggerGroupStore implements TriggerGroupStore {
  InMemoryTriggerGroupStore([
    List<TriggerGroup> groups = const <TriggerGroup>[],
  ]) : _groups = List<TriggerGroup>.of(groups);

  List<TriggerGroup> _groups;

  @override
  Future<List<TriggerGroup>> load() async => List<TriggerGroup>.of(_groups);

  @override
  Future<void> save(List<TriggerGroup> groups) async {
    _groups = List<TriggerGroup>.of(groups);
  }
}
