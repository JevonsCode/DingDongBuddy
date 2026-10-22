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
}
