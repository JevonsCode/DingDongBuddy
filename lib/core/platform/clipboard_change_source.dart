/// Platform event boundary for efficient clipboard change notifications.
abstract interface class ClipboardChangeSource {
  Stream<void> get changes;

  Future<void> start();

  Future<void> stop();
}
