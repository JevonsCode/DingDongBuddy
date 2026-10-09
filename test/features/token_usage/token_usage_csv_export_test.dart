import 'package:dingdong/features/token_usage/domain/token_usage_csv_export.dart';
import 'package:dingdong/features/token_usage/domain/token_usage_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'CSV scopes by year and source with plain integers and unknown fields',
    () {
      final snapshot = TokenUsageSnapshot(
        refreshedAt: DateTime(2026, 1, 3),
        coverage: const [
          TokenUsageSourceCoverage(
            source: ConversationTokenUsageSource.codex,
            availability: TokenUsageAvailability.available,
            filesScanned: 1,
          ),
        ],
        days: [
          TokenUsageDay(
            day: DateTime(2025, 12, 31),
            source: ConversationTokenUsageSource.codex,
            totals: const TokenUsageTotals(totalTokens: 99),
          ),
          TokenUsageDay(
            day: DateTime(2026, 1, 2),
            source: ConversationTokenUsageSource.pi,
            totals: const TokenUsageTotals(totalTokens: 999),
          ),
          TokenUsageDay(
            day: DateTime(2026, 1, 1),
            source: ConversationTokenUsageSource.codex,
            totals: const TokenUsageTotals(
              totalTokens: 12345,
              inputTokens: 12000,
              outputTokens: 345,
              cachedInputTokens: 0,
              cacheWriteInputTokens: 0,
            ),
            eventCount: 3,
          ),
        ],
      );
      final export = TokenUsageCsvExport.fromSnapshot(
        snapshot,
        year: 2026,
        source: ConversationTokenUsageSource.codex,
      );
      expect(export.suggestedName, 'dingdong-token-usage-2026-codex.csv');
      final lines = export.contents.trimRight().split('\r\n');
      expect(lines, hasLength(2));
      expect(lines.first.split(','), hasLength(16));
      // A displayed 12,345 must stay in one numeric CSV cell; unknown reasoning
      // stays empty while an explicitly reported zero remains zero.
      expect(lines.last.split(','), [
        '2026-01-01',
        'codex',
        '12345',
        '12000',
        '345',
        '0',
        '0',
        '',
        '12345',
        'exact',
        'exact',
        'true',
        '3',
        '0',
        'complete_scan',
        '',
      ]);
      expect(export.contents, isNot(contains('12,345')));
      expect(lines.first, isNot(contains('path')));
      expect(lines.first, isNot(contains('session')));
    },
  );

  test(
    'CSV keeps lower bounds distinct from uncertain dates and estimates',
    () {
      TokenUsageDay row(int day, TokenUsageTotals totals) => TokenUsageDay(
        day: DateTime(2026, 1, day),
        source: ConversationTokenUsageSource.codex,
        totals: totals,
        partialEventCount: 1,
      );
      final export = TokenUsageCsvExport.fromSnapshot(
        TokenUsageSnapshot(
          days: [
            row(
              3,
              const TokenUsageTotals(
                totalTokens: 300,
                totalIsExact: false,
                dateAttributionExact: false,
              ),
            ),
            row(
              1,
              const TokenUsageTotals(totalTokens: 100, totalIsExact: false),
            ),
            row(
              2,
              const TokenUsageTotals(
                totalTokens: 200,
                dateAttributionExact: false,
              ),
            ),
          ],
        ),
        year: 2026,
      );
      final records = export.contents
          .trimRight()
          .split('\r\n')
          .skip(1)
          .map((line) => line.split(','))
          .toList();
      expect(records.map((row) => row[0]), [
        '2026-01-01',
        '2026-01-02',
        '2026-01-03',
      ]);
      expect(records.map((row) => row[9]), [
        'lower_bound',
        'exact',
        'estimate',
      ]);
      expect(records.map((row) => row[10]), [
        'exact',
        'uncertain',
        'uncertain',
      ]);
      expect(records.every((row) => row[3].isEmpty && row[8].isEmpty), isTrue);
      expect(export.suggestedName, 'dingdong-token-usage-2026-all.csv');
    },
  );

  test('empty filter exports no synthetic zero row', () {
    final export = TokenUsageCsvExport.fromSnapshot(
      const TokenUsageSnapshot(),
      year: 2026,
    );
    expect(export.days, isEmpty);
    expect(export.contents.trimRight().split('\r\n'), hasLength(1));
  });

  test(
    'CSV quotes diagnostic lists and never exports arbitrary warning text',
    () {
      final export = TokenUsageCsvExport.fromSnapshot(
        TokenUsageSnapshot(
          refreshedAt: DateTime(2026, 1, 3),
          warnings: const [
            'refresh_interrupted',
            'C:/private/transcript.jsonl',
            'secret,"message"',
          ],
          coverage: const [
            TokenUsageSourceCoverage(
              source: ConversationTokenUsageSource.codex,
              availability: TokenUsageAvailability.available,
              filesScanned: 1,
              malformedRows: 2,
            ),
          ],
          days: [
            TokenUsageDay(
              day: DateTime(2026, 1, 1),
              source: ConversationTokenUsageSource.codex,
              totals: const TokenUsageTotals(totalTokens: 100),
            ),
          ],
        ),
        year: 2026,
        source: ConversationTokenUsageSource.codex,
      );
      expect(
        export.contents,
        contains(
          ',partial_or_unavailable,"malformed_usage_rows,refresh_interrupted"\r\n',
        ),
      );
      expect(export.contents, isNot(contains('private')));
      expect(export.contents, isNot(contains('secret')));
    },
  );
}
