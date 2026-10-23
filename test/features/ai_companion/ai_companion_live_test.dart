import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/ai_companion/data/ai_companion_client.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_models.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_usage.dart';
import 'package:flutter_test/flutter_test.dart';

// Opt-in integration check. Uses only a fixed probe, never local user content.
// Requires an existing service; not part of normal offline test runs.
void main() {
  test(
    'configured service completes an actual model request through auto protocol',
    () async {
      final client = AiCompanionClient(timeout: const Duration(seconds: 60));
      addTearDown(client.dispose);
      AiCompanionUsageRecord? receipt;
      await client.testConnection(
        AiCompanionSettings(
          providerEndpoint: Platform.environment['DINGDONG_AI_LIVE_ENDPOINT']!,
          model: Platform.environment['DINGDONG_AI_LIVE_MODEL']!,
        ),
        Platform.environment['DINGDONG_AI_LIVE_KEY'],
        onUsage: (record) async {
          receipt = record;
        },
      );
      expect(receipt, isNotNull);
      expect(receipt!.totals.totalTokens, greaterThan(0));
      final target = Platform.environment['DINGDONG_AI_LIVE_USAGE_FILE'];
      if (target != null) {
        final t = receipt!.totals;
        await File(target).writeAsString(
          jsonEncode({
            'total': t.totalTokens,
            'input': t.inputTokens,
            'output': t.outputTokens,
            'cacheRead': t.cachedInputTokens,
            'cacheWrite': t.cacheWriteInputTokens,
            'totalIsExact': t.totalIsExact,
          }),
        );
      }
    },
    skip: !Platform.environment.containsKey('DINGDONG_AI_LIVE_ENDPOINT'),
  );
  test(
    'configured service selects resource IDs rather than human advice',
    () async {
      final client = AiCompanionClient();
      addTearDown(client.dispose);
      final selected = await client.selectResources(
        AiCompanionSettings(
          autoResourceSelection: true,
          providerEndpoint: Platform.environment['DINGDONG_AI_LIVE_ENDPOINT']!,
          model: Platform.environment['DINGDONG_AI_LIVE_MODEL']!,
          protocol:
              AiCompanionProtocol.values
                  .where(
                    (p) =>
                        p.name ==
                        Platform.environment['DINGDONG_AI_LIVE_PROTOCOL'],
                  )
                  .firstOrNull ??
              AiCompanionProtocol.auto,
        ),
        Platform.environment['DINGDONG_AI_LIVE_KEY'],
        {
          'task':
              'Review a SQL migration. Use SQL review rules, the SQL review skill and database schema metadata. No UI work.',
          'taskContext': '',
          'resources': [
            {
              'id': 'r0',
              'type': 'prompt',
              'title': 'SQL review rules',
              'description': 'Read-only checks for SQL migration safety',
            },
            {
              'id': 'r1',
              'type': 'skill',
              'title': 'SQL review',
              'description': 'Review SQL migrations',
            },
            {
              'id': 'r2',
              'type': 'mcp',
              'title': 'Database schema',
              'description': 'Read database schema metadata',
            },
            {
              'id': 'r3',
              'type': 'skill',
              'title': 'UI design',
              'description': 'Design visual interfaces',
            },
          ],
        },
      );
      expect(selected, {'r0', 'r1', 'r2'});
    },
    skip: !Platform.environment.containsKey('DINGDONG_AI_LIVE_ENDPOINT'),
  );
}
