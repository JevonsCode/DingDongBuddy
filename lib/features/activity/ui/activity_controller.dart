import 'dart:math';

import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:flutter/foundation.dart';

/// Bounded process-local Agent completion feed and unseen reveal state.
final class ActivityController extends ChangeNotifier {
  ActivityController({String Function()? idGenerator, DateTime Function()? now})
    : _idGenerator = idGenerator ?? _generateId,
      _now = now ?? DateTime.now;

  final String Function() _idGenerator;
  final DateTime Function() _now;
  List<AgentActivity> _activities = const <AgentActivity>[];
  int _revealRevision = 0;

  List<AgentActivity> get activities =>
      List<AgentActivity>.unmodifiable(_activities);

  int get unseenCount =>
      _activities.where((AgentActivity item) => item.unseen).length;

  int get revealRevision => _revealRevision;

  void record({required String source, required String message}) {
    final AgentActivity activity = AgentActivity(
      id: _idGenerator(),
      source: source.trim().isEmpty ? 'Agent' : source.trim(),
      message: message.trim().isEmpty ? 'Task complete' : message.trim(),
      completedAt: _now().toUtc(),
      unseen: true,
    );
    _activities = <AgentActivity>[activity, ..._activities.take(19)];
    notifyListeners();
  }

  void requestReveal() {
    if (unseenCount == 0) {
      return;
    }
    _revealRevision += 1;
    notifyListeners();
  }

  void markAllSeen() {
    if (unseenCount == 0) {
      return;
    }
    _activities = _activities
        .map((AgentActivity item) => item.unseen ? item.seen() : item)
        .toList(growable: false);
    notifyListeners();
  }
}

String _generateId() {
  final Random random = Random.secure();
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${random.nextInt(1 << 32).toRadixString(36)}';
}
