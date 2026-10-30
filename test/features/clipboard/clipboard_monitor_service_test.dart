import 'dart:async';

import 'package:dingdong/core/platform/clipboard_change_source.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_capture_service.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_monitor_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'captures the latest change received while an earlier read is busy',
    () async {
      final source = _FakeClipboardChangeSource();
      final gateway = _MutableClipboardGateway();
      final store = InMemoryClipboardStore();
      var id = 0;
      final monitor = ClipboardMonitorService(
        source: source,
        captureService: ClipboardCaptureService(
          gateway: gateway,
          store: store,
          idGenerator: () => 'copy-${id++}',
        ),
      );
      final firstRead = Completer<ClipboardSnapshot>();
      gateway.pendingRead = firstRead;
      await monitor.start();
      source.emit();
      gateway.text = 'latest external copy';
      source.emit();
      source.emit();
      firstRead.complete(
        const ClipboardSnapshot(text: 'earlier external copy'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        store.list(limit: 10).map((record) => record.content),
        containsAll(['earlier external copy', 'latest external copy']),
      );
      expect(
        gateway.reads,
        2,
        reason: 'Coalesce pending changes into one fresh read.',
      );
      await monitor.stop();
    },
  );

  test(
    'stopping discards queued reads until monitoring is started again',
    () async {
      final source = _FakeClipboardChangeSource();
      final gateway = _MutableClipboardGateway();
      final monitor = ClipboardMonitorService(
        source: source,
        captureService: ClipboardCaptureService(
          gateway: gateway,
          store: InMemoryClipboardStore(),
        ),
      );
      final firstRead = Completer<ClipboardSnapshot>();
      gateway.pendingRead = firstRead;
      await monitor.start();
      source.emit();
      source.emit();
      await monitor.stop();
      firstRead.complete(const ClipboardSnapshot(text: 'already in flight'));
      await Future<void>.delayed(Duration.zero);
      expect(gateway.reads, 1);
      await monitor.start();
      source.emit();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.reads, 2);
      await monitor.stop();
    },
  );

  test(
    'monitor captures one record for each platform change while running',
    () async {
      final _FakeClipboardChangeSource source = _FakeClipboardChangeSource();
      final _MutableClipboardGateway gateway = _MutableClipboardGateway();
      final InMemoryClipboardStore store = InMemoryClipboardStore();
      int detectedCopies = 0;
      final ClipboardMonitorService monitor = ClipboardMonitorService(
        source: source,
        captureService: ClipboardCaptureService(
          gateway: gateway,
          store: store,
          idGenerator: () => 'MONITORED-ID',
          now: () => DateTime.utc(2026, 7, 12),
        ),
        onCopyDetected: () => detectedCopies += 1,
      );

      await monitor.start();
      gateway.text = 'dart test';
      source.emit();
      await Future<void>.delayed(Duration.zero);

      expect(monitor.isRunning, isTrue);
      expect(detectedCopies, 1);
      expect(store.list(limit: 10).single.content, 'dart test');

      await monitor.stop();
      gateway.text = 'ignored after stop';
      source.emit();
      await Future<void>.delayed(Duration.zero);

      expect(monitor.isRunning, isFalse);
      expect(detectedCopies, 1);
      expect(store.list(limit: 10), hasLength(1));
    },
  );
}

final class _FakeClipboardChangeSource implements ClipboardChangeSource {
  final StreamController<void> _controller = StreamController<void>.broadcast(
    sync: true,
  );

  @override
  Stream<void> get changes => _controller.stream;

  void emit() => _controller.add(null);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

final class _MutableClipboardGateway implements ClipboardGateway {
  String? text;
  Completer<ClipboardSnapshot>? pendingRead;
  int reads = 0;

  @override
  Future<ClipboardSnapshot> read() async {
    reads += 1;
    final pending = pendingRead;
    pendingRead = null;
    return pending == null
        ? ClipboardSnapshot(text: text)
        : await pending.future;
  }

  @override
  Future<void> writeFiles(List<String> paths) async {}

  @override
  Future<void> writeText(String text) async {}
}
