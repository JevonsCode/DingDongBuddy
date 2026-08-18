import 'dart:async';
import 'dart:io';

import 'package:dingdong/features/library/data/trigger_group_file_service.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';

abstract interface class TriggerGroupStore {
  Future<List<TriggerGroup>> load();

  Future<void> save(List<TriggerGroup> groups);
}

abstract interface class ExclusiveTriggerGroupStore {
  Future<T> exclusiveMutation<T>(Future<T> Function() action);
}

abstract interface class TriggerGroupFileLocator {
  File? get triggerGroupFile;
}

final class TriggerGroupRepository
    implements
        TriggerGroupStore,
        ExclusiveTriggerGroupStore,
        TriggerGroupFileLocator {
  TriggerGroupRepository(this._service);

  final TriggerGroupFileService _service;

  @override
  File get triggerGroupFile => _service.file;

  @override
  Future<T> exclusiveMutation<T>(Future<T> Function() action) =>
      _service.exclusive(action);

  @override
  Future<List<TriggerGroup>> load() => _service.readGroups();

  @override
  Future<void> save(List<TriggerGroup> groups) =>
      _service.writeAtomically(groups);
}

final class InMemoryTriggerGroupStore
    implements
        TriggerGroupStore,
        ExclusiveTriggerGroupStore,
        TriggerGroupFileLocator {
  InMemoryTriggerGroupStore([
    List<TriggerGroup> groups = const <TriggerGroup>[],
  ]) : _groups = List<TriggerGroup>.of(groups);

  List<TriggerGroup> _groups;
  Future<void> _mutationBarrier = Future<void>.value();

  @override
  File? get triggerGroupFile => null;

  @override
  Future<T> exclusiveMutation<T>(Future<T> Function() action) async {
    final Future<void> previous = _mutationBarrier;
    final Completer<void> gate = Completer<void>();
    _mutationBarrier = gate.future;
    await previous;
    try {
      return await action();
    } finally {
      gate.complete();
    }
  }

  @override
  Future<List<TriggerGroup>> load() async => List<TriggerGroup>.of(_groups);

  @override
  Future<void> save(List<TriggerGroup> groups) async {
    _groups = List<TriggerGroup>.of(groups);
  }
}
