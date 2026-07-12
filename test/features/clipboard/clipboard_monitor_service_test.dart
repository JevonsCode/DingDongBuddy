import 'dart:async';

import 'package:dingdong/core/platform/clipboard_change_source.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_capture_service.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_monitor_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'monitor captures one record for each platform change while running',
    () async {
      final _FakeClipboardChangeSource source = _FakeClipboardChangeSource();
      final _MutableClipboardGateway gateway = _MutableClipboardGateway();
      final InMemoryClipboardStore store = InMemoryClipboardStore();
      final ClipboardMonitorService monitor = ClipboardMonitorService(
        source: source,
        captureService: ClipboardCaptureService(
          gateway: gateway,
          store: store,
          idGenerator: () => 'MONITORED-ID',
          now: () => DateTime.utc(2026, 7, 12),
        ),
      );

      await monitor.start();
      gateway.text = 'dart test';
      source.emit();
      await Future<void>.delayed(Duration.zero);

      expect(monitor.isRunning, isTrue);
      expect(store.list(limit: 10).single.content, 'dart test');

      await monitor.stop();
      gateway.text = 'ignored after stop';
      source.emit();
      await Future<void>.delayed(Duration.zero);

      expect(monitor.isRunning, isFalse);
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

  @override
  Future<ClipboardSnapshot> read() async => ClipboardSnapshot(text: text);

  @override
  Future<void> writeFiles(List<String> paths) async {}

  @override
  Future<void> writeText(String text) async {}
}
