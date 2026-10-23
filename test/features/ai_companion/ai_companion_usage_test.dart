import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/ai_companion/data/ai_companion_client.dart';
import 'package:dingdong/features/ai_companion/data/ai_companion_store.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_usage.dart';
import 'package:dingdong/features/ai_companion/ui/ai_companion_controller.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/token_usage/data/local_token_usage_repository.dart';
import 'package:dingdong/features/token_usage/domain/token_usage_csv_export.dart';
import 'package:dingdong/features/token_usage/domain/token_usage_models.dart';
import 'package:dingdong/features/token_usage/ui/token_usage_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ai_companion_protocol_test.dart' show Transport, settings;

void main() {
  test(
    'usage refresh reads background receipts without model traffic',
    () async {
      final dir = await Directory.systemTemp.createTemp('jvs-a-usage-refresh-');
      final repo = LocalTokenUsageRepository(
        databasePath: '${dir.path}/usage.db',
        homeDirectory: dir,
      );
      var requests = 0;
      final controller = AiCompanionController(
        store: AiCompanionPreferencesStore(
          MemoryPreferencesBackend(),
          secretStore: Secrets(),
        ),
        usageRepository: repo,
        client: AiCompanionClient(
          transport: Transport((a, b, c) {
            requests++;
            return const AiCompanionHttpResponse(200, '{}');
          }),
        ),
      );
      try {
        await controller.load();
        await repo.recordInternalUsage(
          AiCompanionUsageRecord(
            id: 'background-selection',
            occurredAt: DateTime.now(),
            purpose: AiCompanionUsagePurpose.resourceSelection,
            totals: parseAiCompanionUsage({
              'total_tokens': 42,
            }, AiCompanionProtocol.openAI),
          ),
        );
        expect(controller.internalUsage.totals.totalTokens, 0);
        await controller.refreshInternalUsage();
        expect(controller.internalUsage.totals.totalTokens, 42);
        expect(requests, 0);
        expect(controller.isLoading, isFalse);
        expect((await repo.readSnapshot()).days, isEmpty);
      } finally {
        controller.dispose();
        await repo.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'invalidating while a snapshot loads keeps the next view refreshable',
    () async {
      final pending = Completer<TokenUsageSnapshot>();
      final controller = TokenUsageController(
        loadSnapshot: () => pending.future,
      );
      final refresh = controller.refresh();
      controller.invalidate();
      pending.complete(const TokenUsageSnapshot());
      await refresh;
      expect(controller.hasLoaded, isFalse);
      controller.dispose();
    },
  );
  test('internal CSV keeps its source and does not demand transcript logs', () {
    final snapshot = TokenUsageSnapshot(
      refreshedAt: DateTime(2026, 10, 22),
      days: [
        TokenUsageDay(
          day: DateTime(2026, 10, 22),
          source: ConversationTokenUsageSource.dingdong,
          totals: parseAiCompanionUsage({
            'total_tokens': 12,
          }, AiCompanionProtocol.openAI),
          eventCount: 1,
        ),
      ],
      coverage: const [
        TokenUsageSourceCoverage(
          source: ConversationTokenUsageSource.dingdong,
          availability: TokenUsageAvailability.available,
        ),
      ],
    );
    final csv = TokenUsageCsvExport.fromSnapshot(
      snapshot,
      year: 2026,
      source: ConversationTokenUsageSource.dingdong,
    ).contents;
    expect(csv, contains('2026-10-22,dingdong,12'));
    expect(csv, isNot(contains('no_importable_logs')));
    expect(csv, isNot(contains('coverage_unknown')));
  });

  test(
    'controller accounts for all operations and global toggle refreshes without changing ledger',
    () async {
      final dir = await Directory.systemTemp.createTemp('jvs-a-accounting-');
      final repo = LocalTokenUsageRepository(
        databasePath: '${dir.path}/usage.db',
        homeDirectory: dir,
      );
      final store = AiCompanionPreferencesStore(
        MemoryPreferencesBackend(),
        secretStore: Secrets(),
      );
      final global = TokenUsageController.fromRepository(
        repo,
        includeInternal: () async =>
            (await store.loadSettings()).includeInternalInGlobal,
      );
      final controller = AiCompanionController(
        store: store,
        usageRepository: repo,
        onUsageChanged: global.invalidate,
        client: AiCompanionClient(
          transport: Transport(
            (a, b, c) => const AiCompanionHttpResponse(
              200,
              '{"usage":{"prompt_tokens":10,"completion_tokens":2,"total_tokens":12},"choices":[{"message":{"content":"OK"}}]}',
            ),
          ),
        ),
      );
      try {
        await controller.load();
        await controller.saveSettings(settings());
        await controller.testConnection();
        expect(controller.error, isNull);
        expect(controller.internalUsage.totals.totalTokens, 12);
        expect(
          controller.internalUsage.days.fold(0, (n, day) => n + day.eventCount),
          1,
        );
        expect(
          controller.internalUsage.days
              .map((day) => day.internalPurpose)
              .toSet(),
          {'connectionTest'},
        );
        await global.refresh();
        expect(global.snapshot.totals.totalTokens, 0);
        await controller.saveSettings(
          controller.settings.copyWith(includeInternalInGlobal: true),
        );
        expect(global.hasLoaded, isFalse);
        await global.refresh();
        expect(global.snapshot.totals.totalTokens, 12);
        await controller.saveSettings(
          controller.settings.copyWith(includeInternalInGlobal: false),
        );
        await global.refresh();
        expect(global.snapshot.totals.totalTokens, 0);
        expect(controller.internalUsage.totals.totalTokens, 12);
        await repo.close();
        await controller.testConnection();
        expect(controller.error, isNull);
        expect(controller.connectionVerified, isTrue);
        expect(controller.usageStorageAvailable, isFalse);
      } finally {
        controller.dispose();
        global.dispose();
        await repo.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'automatic protocol fallback records only the final successful call',
    () async {
      final events = <AiCompanionUsageRecord>[];
      final client = AiCompanionClient(
        transport: Transport(
          (uri, a, b) => uri.path.endsWith('/messages')
              ? const AiCompanionHttpResponse(
                  200,
                  '{"usage":{"input_tokens":10,"output_tokens":2,"cache_read_input_tokens":0,"cache_creation_input_tokens":0},"content":[{"type":"text","text":"OK"}]}',
                )
              : const AiCompanionHttpResponse(404, ''),
        ),
      );
      await client.testConnection(
        settings(),
        null,
        onUsage: (e) async => events.add(e),
      );
      expect(events, hasLength(1));
      expect(events.single.totals.totalTokens, 12);
    },
  );

  test('global inclusion defaults off and persists explicitly', () {
    expect(const AiCompanionSettings().includeInternalInGlobal, isFalse);
    expect(AiCompanionSettings.fromJson({}).includeInternalInGlobal, isFalse);
    final value = const AiCompanionSettings().copyWith(
      includeInternalInGlobal: true,
    );
    expect(
      AiCompanionSettings.fromJson(value.toJson()).includeInternalInGlobal,
      isTrue,
    );
  });
  test('OpenAI cache is already included in input, reasoning in output', () {
    final t = parseAiCompanionUsage({
      'prompt_tokens': 100,
      'completion_tokens': 20,
      'total_tokens': 120,
      'prompt_tokens_details': {'cached_tokens': 60},
      'completion_tokens_details': {'reasoning_tokens': 5},
    }, AiCompanionProtocol.openAI);
    expect(t.totalTokens, 120);
    expect(t.inputTokens, 100);
    expect(t.cachedInputTokens, 60);
    expect(t.reasoningOutputTokens, 5);
    expect(t.nonCachedTokens, 60);
  });
  test('Anthropic cache read and creation are additional input', () {
    final t = parseAiCompanionUsage({
      'input_tokens': 10,
      'output_tokens': 20,
      'cache_read_input_tokens': 60,
      'cache_creation_input_tokens': 30,
    }, AiCompanionProtocol.anthropic);
    expect(t.totalTokens, 120);
    expect(t.inputTokens, 100);
    expect(t.breakdownComplete, isTrue);
  });
  test(
    'missing and malformed usage stay unknown, exact total survives missing detail',
    () {
      final unknown = parseAiCompanionUsage(null, AiCompanionProtocol.openAI);
      expect(unknown.totalIsExact, isFalse);
      expect(unknown.inputTokens, isNull);
      final partial = parseAiCompanionUsage({
        'total_tokens': 100,
        'prompt_tokens': -1,
        'completion_tokens': 1.5,
      }, AiCompanionProtocol.openAI);
      expect(partial.totalTokens, 100);
      expect(partial.totalIsExact, isTrue);
      expect(partial.breakdownComplete, isFalse);
      expect(partial.outputTokens, isNull);
      final anthropic = parseAiCompanionUsage({
        'input_tokens': 10,
        'output_tokens': 20,
      }, AiCompanionProtocol.anthropic);
      expect(anthropic.totalTokens, 30);
      expect(anthropic.totalIsExact, isFalse);
      expect(anthropic.inputTokens, isNull);
    },
  );
  test(
    'usage is captured once before content rejection; sink failure does not break response',
    () async {
      final events = <AiCompanionUsageRecord>[];
      final client = AiCompanionClient(
        transport: Transport(
          (a, b, c) => AiCompanionHttpResponse(
            200,
            jsonEncode({
              'usage': {'total_tokens': 12},
              'choices': [],
            }),
          ),
        ),
      );
      await expectLater(
        client.testConnection(
          settings(),
          null,
          onUsage: (e) async => events.add(e),
        ),
        throwsA(isA<AiCompanionException>()),
      );
      expect(events.single.purpose, AiCompanionUsagePurpose.connectionTest);
      expect(events.single.totals.totalTokens, 12);
      final ok = AiCompanionClient(
        transport: Transport(
          (a, b, c) => const AiCompanionHttpResponse(
            200,
            '{"choices":[{"message":{"content":"OK"}}]}',
          ),
        ),
      );
      await ok.testConnection(
        settings(),
        null,
        onUsage: (_) async => throw StateError('disk'),
      );
    },
  );
  test(
    'ledger survives reopen, deduplicates, filters dates and opts into global without reimport',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'jvs-a-internal-usage-',
      );
      final db = '${dir.path}/usage.db';
      var repo = LocalTokenUsageRepository(
        databasePath: db,
        homeDirectory: dir,
      );
      final record = AiCompanionUsageRecord(
        id: 'request-1',
        occurredAt: DateTime(2026, 10, 22),
        purpose: AiCompanionUsagePurpose.analysis,
        totals: parseAiCompanionUsage({
          'total_tokens': 123,
        }, AiCompanionProtocol.openAI),
      );
      try {
        await repo.recordInternalUsage(record);
        await repo.recordInternalUsage(record);
        expect((await repo.readSnapshot()).days, isEmpty);
        expect(
          (await repo.readSnapshot(includeInternal: true)).totals.totalTokens,
          123,
        );
        expect((await repo.readSnapshot()).days, isEmpty);
        expect(
          (await repo.readSnapshot(includeInternal: true)).totals.totalTokens,
          123,
        );
        await repo.close();
        repo = LocalTokenUsageRepository(databasePath: db, homeDirectory: dir);
        final snapshot = await repo.readInternalSnapshot();
        expect(snapshot.totals.totalTokens, 123);
        expect(snapshot.days.single.eventCount, 1);
        expect(
          (await repo.readInternalSnapshot(from: DateTime(2026, 10, 23))).days,
          isEmpty,
        );
        await repo.recordInternalUsage(
          AiCompanionUsageRecord(
            id: 'unknown',
            occurredAt: DateTime(2026, 10, 22),
            purpose: AiCompanionUsagePurpose.analysis,
            totals: parseAiCompanionUsage(null, AiCompanionProtocol.openAI),
          ),
        );
        expect(
          (await repo.readInternalSnapshot()).totals.totalIsExact,
          isFalse,
        );
      } finally {
        await repo.close();
        await dir.delete(recursive: true);
      }
    },
  );
}

class Secrets implements AiCompanionSecretStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    value = v;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}
