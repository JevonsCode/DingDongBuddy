import 'dart:async';

enum DataCollection { clipboard, library }

/// Process-local invalidation channel shared by feature view models.
final class DataRevisionBus {
  final StreamController<DataCollection> _controller =
      StreamController<DataCollection>.broadcast(sync: true);

  Stream<DataCollection> get changes => _controller.stream;

  void changed(DataCollection collection) => _controller.add(collection);

  Future<void> dispose() => _controller.close();
}
