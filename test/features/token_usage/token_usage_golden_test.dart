@Tags(<String>['golden'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/token_usage/domain/token_usage_models.dart';
import 'package:dingdong/features/token_usage/ui/token_usage_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'token_usage_screen_test.dart' show pumpUsage;

void main() {
  setUpAll(_loadGoldenFonts);
  for (final bool dark in <bool>[false, true]) {
    testWidgets('local token calendar ${dark ? 'dark' : 'light'}', (
      WidgetTester tester,
    ) async {
      final TokenUsageController controller = TokenUsageController.preview(
        _calendarFixture(),
      );
      addTearDown(controller.dispose);
      await pumpUsage(
        tester,
        controller,
        size: const Size(1140, 1000),
        now: DateTime(2026, 10, 9, 14, 35),
        dark: dark,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const Key('token-usage-golden')),
        matchesGoldenFile('goldens/token_usage_${dark ? 'dark' : 'light'}.png'),
      );
    });
  }
}

/// The Flutter SDK ships these fonts on every desktop test host. Loading the
/// same bundled faces keeps screenshots readable and independent of OS fonts.
Future<void> _loadGoldenFonts() async {
  final Map<String, Object?> config =
      jsonDecode(await File('.dart_tool/package_config.json').readAsString())
          as Map<String, Object?>;
  final Uri sdk = Uri.parse('${config['flutterRoot']}/');
  for (final String family in <String>[
    'Segoe UI',
    '.AppleSystemUIFont',
    'Roboto',
  ]) {
    final FontLoader loader = FontLoader(family);
    for (final String face in <String>[
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
    ]) {
      loader.addFont(
        File.fromUri(
          sdk.resolve('bin/cache/artifacts/material_fonts/$face'),
        ).readAsBytes().then(ByteData.sublistView),
      );
    }
    await loader.load();
  }
  final FontLoader icons = FontLoader('MaterialIcons')
    ..addFont(
      File.fromUri(
        sdk.resolve(
          'bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        ),
      ).readAsBytes().then(ByteData.sublistView),
    );
  await icons.load();
}

/// Synthetic usage only. This calendar never opens the user's Agent logs.
TokenUsageSnapshot _calendarFixture() {
  final List<TokenUsageDay> days = <TokenUsageDay>[];
  for (int i = 0; i <= 280; i += 1) {
    if (i % 7 == 5 || i % 11 == 0) continue;
    final int input = (i * 137 + 2000) % 85000 + 3000;
    final int output = (i * 89 + 600) % 16000 + 400;
    days.add(
      TokenUsageDay(
        day: DateTime(2026, 1, i + 1),
        source: i % 3 == 0
            ? ConversationTokenUsageSource.claudeCode
            : ConversationTokenUsageSource.codex,
        totals: TokenUsageTotals(
          totalTokens: input + output,
          inputTokens: input,
          outputTokens: output,
          cachedInputTokens: input ~/ 2,
          cacheWriteInputTokens: i % 3 == 0 ? input ~/ 8 : 0,
          reasoningOutputTokens: output ~/ 3,
        ),
        eventCount: i % 9 + 1,
      ),
    );
  }
  days.add(
    TokenUsageDay(
      day: DateTime(2026, 10, 9),
      source: ConversationTokenUsageSource.codex,
      totals: const TokenUsageTotals(
        totalTokens: 284350,
        inputTokens: 251800,
        outputTokens: 32550,
        cachedInputTokens: 196200,
        cacheWriteInputTokens: 0,
        reasoningOutputTokens: 12240,
      ),
      eventCount: 18,
    ),
  );
  return TokenUsageSnapshot(
    days: days,
    refreshedAt: DateTime(2026, 10, 9, 14, 35),
    coverage: const <TokenUsageSourceCoverage>[
      TokenUsageSourceCoverage(
        source: ConversationTokenUsageSource.codex,
        availability: TokenUsageAvailability.available,
        filesScanned: 84,
      ),
      TokenUsageSourceCoverage(
        source: ConversationTokenUsageSource.claudeCode,
        availability: TokenUsageAvailability.available,
        filesScanned: 27,
      ),
      TokenUsageSourceCoverage(
        source: ConversationTokenUsageSource.pi,
        availability: TokenUsageAvailability.missing,
      ),
    ],
  );
}
