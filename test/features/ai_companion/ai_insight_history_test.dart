import 'dart:io';

import 'package:dingdong/features/ai_companion/data/ai_companion_store.dart';
import 'package:dingdong/features/ai_companion/data/ai_insight_history.dart';
import 'package:dingdong/features/ai_companion/ui/ai_companion_controller.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'history persists, paginates and updates the same local/cloud analysis',
    () {
      final directory = Directory.systemTemp.createTempSync('jvs-ai-history-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = '${directory.path}/history.sqlite3';
      final history = AiInsightHistory(path);
      final now = DateTime.utc(2026, 10, 23);
      for (var i = 0; i < 45; i++) {
        history.save(
          AiCompanionReport(createdAt: now.add(Duration(minutes: i))),
          automatic: true,
        );
      }
      final latest = now.add(const Duration(minutes: 44));
      history.save(
        AiCompanionReport(
          createdAt: latest,
          cloudSummary: 'Review resource scope.',
          localOnly: false,
        ),
        automatic: true,
      );
      final restored = AiInsightHistory(path);
      expect(restored.count, 45);
      expect(restored.page().length, 20);
      expect(
        restored.page().first.report.cloudSummary,
        'Review resource scope.',
      );
      expect(restored.page(offset: 40).length, 5);
      expect(restored.page(offset: 40).last.report.createdAt, now);
    },
  );

  test(
    'keychain failure preserves local settings, edits and analysis',
    () async {
      final secrets = _DeniedSecrets();
      final store = AiCompanionPreferencesStore(
        MemoryPreferencesBackend(),
        secretStore: secrets,
      );
      await store.saveSettings(
        const AiCompanionSettings(
          providerEndpoint: 'http://gateway.example/coding-plan',
          model: 'test',
          usageOptimization: true,
        ),
      );
      final controller = AiCompanionController(
        store: store,
        loadMetadata: () async => const AiCompanionMetadata(),
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.error, AiCompanionError.credentialUnavailable);
      expect(controller.settings.usageOptimization, true);
      await controller.saveSettings(
        controller.settings.copyWith(tokenOptimization: true),
      );
      expect(controller.error, isNull);
      expect(controller.settings.tokenOptimization, true);
      expect(secrets.reads, 1);
      await controller.analyze();
      expect(controller.report, isNotNull);
      expect(controller.error, isNull);
    },
  );

  test(
    'automatic defaults on, respects manual mode, and deduplicates across restarts',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'jvs-ai-automatic-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final history = AiInsightHistory('${directory.path}/history.sqlite3');
      final store = AiCompanionPreferencesStore(
        MemoryPreferencesBackend(),
        secretStore: _DeniedSecrets(),
      );
      await store.saveSettings(
        const AiCompanionSettings(usageOptimization: true),
      );
      var now = DateTime.utc(2026, 10, 23);
      AiCompanionController make() => AiCompanionController(
        store: store,
        history: history,
        now: () => now,
        loadMetadata: () async => const AiCompanionMetadata(),
      );
      final controller = make();
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.settings.automaticAnalysis, true);
      await controller.analyze(automatic: true);
      expect(history.count, 1);
      now = now.add(const Duration(hours: 1));
      final restored = make();
      addTearDown(restored.dispose);
      await restored.load();
      await restored.analyze(automatic: true);
      expect(history.count, 1);
      await restored.saveSettings(
        restored.settings.copyWith(
          automaticAnalysis: false,
          tokenOptimization: true,
        ),
      );
      now = now.add(const Duration(hours: 1));
      await restored.analyze(automatic: true);
      expect(history.count, 1);
      await restored.analyze();
      expect(history.count, 2);
      expect(history.page().first.automatic, false);
    },
  );
}

final class _DeniedSecrets implements AiCompanionSecretStore {
  int reads = 0;
  @override
  Future<String?> read() async {
    reads++;
    throw PlatformException(
      code: 'Unexpected security result code',
      details: -25293,
    );
  }

  @override
  Future<void> write(String value) async {}
  @override
  Future<void> delete() async {}
}
