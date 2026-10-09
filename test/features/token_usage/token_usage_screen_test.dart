import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/features/token_usage/domain/token_usage_csv_export.dart';
import 'package:dingdong/features/token_usage/domain/token_usage_models.dart';
import 'package:dingdong/features/token_usage/ui/token_usage_controller.dart';
import 'package:dingdong/features/token_usage/ui/token_usage_heatmap.dart';
import 'package:dingdong/features/token_usage/ui/token_usage_screen.dart';
import 'package:dingdong/platform/file_selector_token_usage_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('day selection and Agent filter retain authoritative totals', (
    WidgetTester tester,
  ) async {
    final TokenUsageController controller = TokenUsageController.preview(
      usageFixture(),
    );
    addTearDown(controller.dispose);
    await pumpUsage(tester, controller);

    expect(
      find.descendant(
        of: find.byKey(const Key('token-usage-period')),
        matching: find.text('2,400'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('token-usage-day-2026-01-09')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('token-usage-detail-codex')), findsOneWidget);
    expect(
      find.byKey(const Key('token-usage-detail-claude-code')),
      findsOneWidget,
    );
    expect(find.text('Total  1,000'), findsOneWidget);
    expect(find.text('Total  500'), findsOneWidget);

    await tester.tap(find.byKey(const Key('token-usage-source-codex')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('token-usage-detail-claude-code')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('token-usage-period')),
        matching: find.text('1,000'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown breakdown stays unknown and lower bound is marked', (
    WidgetTester tester,
  ) async {
    final TokenUsageController controller = TokenUsageController.preview(
      TokenUsageSnapshot(
        days: <TokenUsageDay>[
          TokenUsageDay(
            day: DateTime(2026, 1, 10),
            source: ConversationTokenUsageSource.pi,
            totals: const TokenUsageTotals(
              totalTokens: 900,
              totalIsExact: false,
            ),
            eventCount: 1,
            partialEventCount: 1,
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    await pumpUsage(tester, controller);
    await tester.ensureVisible(find.byKey(const Key('token-usage-day-detail')));
    await tester.pumpAndSettle();
    expect(find.text('Total  ≥ 900'), findsOneWidget);
    expect(find.text('Not reported'), findsNWidgets(6));
    expect(
      find.text(
        'Some records are incomplete; totals marked ≥ show at least this many tokens.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('daily cells support focus, arrow navigation and semantics', (
    WidgetTester tester,
  ) async {
    final TokenUsageController controller = TokenUsageController.preview(
      usageFixture(),
    );
    addTearDown(controller.dispose);
    await pumpUsage(tester, controller);
    final Finder day = find.byKey(const Key('token-usage-day-2026-01-09'));
    final InkWell cell = tester.widget<InkWell>(
      find.descendant(of: day, matching: find.byType(InkWell)),
    );
    cell.focusNode!.requestFocus();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: day,
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is Semantics && widget.properties.selected == true,
        ),
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('token-usage-selected-date')))
          .data,
      contains('January 10'),
    );
    expect(find.byKey(const Key('token-usage-detail-pi')), findsOneWidget);
  });

  testWidgets('uncertain daily attribution preserves an exact total', (
    WidgetTester tester,
  ) async {
    final TokenUsageController controller = TokenUsageController.preview(
      TokenUsageSnapshot(
        days: <TokenUsageDay>[
          TokenUsageDay(
            day: DateTime(2026, 1, 10),
            source: ConversationTokenUsageSource.codex,
            totals: const TokenUsageTotals(
              totalTokens: 1000,
              dateAttributionExact: false,
            ),
            eventCount: 1,
          ),
        ],
        warnings: const <String>[
          'daily_attribution_gap',
          'incomplete_cumulative_totals',
        ],
      ),
    );
    addTearDown(controller.dispose);
    await pumpUsage(tester, controller);
    final DingDongLocalizations strings = tester
        .element(find.byKey(const Key('token-usage-screen')))
        .l10n;
    expect(find.text('Total  1,000'), findsOneWidget);
    expect(find.textContaining('≥ 1,000'), findsNothing);
    expect(find.text(strings.tokenUsageDateAttributionNote), findsNWidgets(2));
    expect(
      find.text(strings.tokenUsageIncompleteCumulativeNote),
      findsOneWidget,
    );
  });

  testWidgets('interrupted import shows retry notice and keeps readable data', (
    WidgetTester tester,
  ) async {
    final TokenUsageSnapshot fixture = usageFixture();
    final TokenUsageController controller = TokenUsageController.preview(
      TokenUsageSnapshot(
        days: fixture.days,
        coverage: fixture.coverage,
        warnings: const <String>['refresh_interrupted'],
      ),
    );
    addTearDown(controller.dispose);
    await pumpUsage(tester, controller);
    expect(find.byKey(const Key('token-usage-error')), findsOneWidget);
    expect(find.byKey(const Key('token-usage-period')), findsOneWidget);
    expect(
      tester
          .widget<DesktopIconButton>(
            find.byKey(const Key('token-usage-refresh')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('year filter shows historical usage and selects a recorded day', (
    WidgetTester tester,
  ) async {
    final TokenUsageController controller = TokenUsageController.preview(
      usageFixture(),
    );
    addTearDown(controller.dispose);
    await pumpUsage(tester, controller);
    await tester.tap(find.byKey(const Key('token-usage-year-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('token-usage-day-2025-12-20')), findsOneWidget);
    expect(find.text('Total  40'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('token-usage-selected-date')))
          .data,
      contains('December 20'),
    );
    expect(tester.takeException(), isNull);
  });

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('zh'),
    const Locale('es'),
  ]) {
    testWidgets('narrow ${locale.languageCode} view scrolls without overflow', (
      WidgetTester tester,
    ) async {
      final TokenUsageController controller = TokenUsageController.preview(
        usageFixture(),
      );
      addTearDown(controller.dispose);
      await pumpUsage(
        tester,
        controller,
        size: const Size(360, 800),
        locale: locale,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byType(TokenUsageHeatmap),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('token-usage-screen')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('token-usage-heatmap-scroll')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('token-usage-coverage')),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('token-usage-screen')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'empty coverage explains absence instead of claiming zero usage',
    (WidgetTester tester) async {
      final TokenUsageController controller = TokenUsageController.preview(
        const TokenUsageSnapshot(
          coverage: <TokenUsageSourceCoverage>[
            TokenUsageSourceCoverage(
              source: ConversationTokenUsageSource.codex,
              availability: TokenUsageAvailability.missing,
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await pumpUsage(tester, controller);
      expect(find.byKey(const Key('token-usage-empty')), findsOneWidget);
      expectSummaryValues('Not reported');
      await tester.ensureVisible(find.byKey(const Key('token-usage-coverage')));
      await tester.pumpAndSettle();
      expect(find.text('Codex · No local logs found'), findsOneWidget);
      expect(
        find.textContaining(
          'Missing or unsupported logs do not mean zero usage.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('unavailable Agent filters do not invent empty usage', (
    WidgetTester tester,
  ) async {
    final TokenUsageController controller = TokenUsageController.preview(
      const TokenUsageSnapshot(
        coverage: <TokenUsageSourceCoverage>[
          TokenUsageSourceCoverage(
            source: ConversationTokenUsageSource.codex,
            availability: TokenUsageAvailability.available,
            filesScanned: 1,
          ),
          TokenUsageSourceCoverage(
            source: ConversationTokenUsageSource.claudeCode,
            availability: TokenUsageAvailability.missing,
          ),
          TokenUsageSourceCoverage(
            source: ConversationTokenUsageSource.pi,
            availability: TokenUsageAvailability.unreadable,
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    await pumpUsage(tester, controller);
    expectSummaryValues('Not reported');
    await tester.tap(find.byKey(const Key('token-usage-source-claude-code')));
    await tester.pumpAndSettle();
    expectSummaryValues('Not reported');
    await tester.tap(find.byKey(const Key('token-usage-source-pi')));
    await tester.pumpAndSettle();
    expectSummaryValues('Not reported');
    await tester.tap(find.byKey(const Key('token-usage-source-codex')));
    await tester.pumpAndSettle();
    expectSummaryValues('0');
  });

  testWidgets(
    'an existing empty log directory does not claim logs or zero usage',
    (tester) async {
      final controller = TokenUsageController.preview(
        const TokenUsageSnapshot(
          coverage: [
            TokenUsageSourceCoverage(
              source: ConversationTokenUsageSource.codex,
              availability: TokenUsageAvailability.available,
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await pumpUsage(tester, controller);
      expectSummaryValues('Not reported');
      await tester.ensureVisible(find.byKey(const Key('token-usage-coverage')));
      await tester.pumpAndSettle();
      expect(find.text('Codex · No importable logs found'), findsOneWidget);
    },
  );

  testWidgets('an empty selected year and Agent explains the filter', (
    tester,
  ) async {
    final controller = TokenUsageController.preview(usageFixture());
    addTearDown(controller.dispose);
    await pumpUsage(tester, controller);
    await tester.tap(find.byKey(const Key('token-usage-source-pi')));
    await tester.tap(find.byKey(const Key('token-usage-year-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025').last);
    await tester.pumpAndSettle();
    expect(find.text('No records in this selection.'), findsOneWidget);
    expect(
      tester
          .widget<DesktopIconButton>(
            find.byKey(const Key('token-usage-export')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'stop cancels only this refresh and leaves a retryable partial snapshot',
    (tester) async {
      final initial = Completer<TokenUsageSnapshot>();
      var cancels = 0;
      var loads = 0;
      final controller = TokenUsageController(
        loadSnapshot: () =>
            ++loads == 1 ? initial.future : Future.value(usageFixture()),
        cancelRefresh: () => cancels++,
      );
      addTearDown(controller.dispose);
      await pumpUsage(tester, controller, settle: false);
      expect(
        tester
            .widget<DesktopIconButton>(
              find.byKey(const Key('token-usage-stop')),
            )
            .tooltip,
        'Stop this refresh',
      );
      expect(
        tester
            .widget<DesktopIconButton>(
              find.byKey(const Key('token-usage-export')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('token-usage-stop')));
      await tester.pump();
      expect(cancels, 1);
      expect(
        tester
            .widget<DesktopIconButton>(
              find.byKey(const Key('token-usage-stop')),
            )
            .onPressed,
        isNull,
      );
      initial.complete(
        TokenUsageSnapshot(
          days: usageFixture().days,
          coverage: usageFixture().coverage,
          warnings: const ['refresh_cancelled'],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('token-usage-cancelled')), findsOneWidget);
      expect(controller.snapshot.days, hasLength(4));
      expect(find.byKey(const Key('token-usage-stop')), findsNothing);
      await tester.tap(find.byKey(const Key('token-usage-refresh')));
      await tester.pumpAndSettle();
      expect(loads, 2);
      expect(find.byKey(const Key('token-usage-cancelled')), findsNothing);
    },
  );

  testWidgets(
    'CSV export uses current filters and reports saved, cancelled and failed outcomes',
    (tester) async {
      final controller = TokenUsageController.preview(usageFixture());
      addTearDown(controller.dispose);
      final pending = Completer<bool>();
      var calls = 0;
      String? savedContents;
      String? savedName;
      await pumpUsage(
        tester,
        controller,
        saveExport:
            ({
              required contents,
              required suggestedName,
              required confirmButtonText,
              required fileTypeLabel,
            }) async {
              calls++;
              savedContents = contents;
              savedName = suggestedName;
              if (calls == 1) return pending.future;
              if (calls == 2) return false;
              throw StateError('write failed');
            },
      );
      await tester.tap(find.byKey(const Key('token-usage-source-codex')));
      await tester.tap(find.byKey(const Key('token-usage-year-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2025').last);
      await tester.pumpAndSettle();
      final export = find.byKey(const Key('token-usage-export'));
      await tester.tap(export);
      await tester.pump();
      expect(tester.widget<DesktopIconButton>(export).onPressed, isNull);
      expect(savedName, 'dingdong-token-usage-2025-codex.csv');
      expect(
        savedContents,
        contains('2025-12-20,codex,40,30,10,0,0,0,40,exact,exact,true,1,0'),
      );
      expect(savedContents, isNot(contains('2026')));
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Token usage CSV saved.'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(export)).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(export);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(export);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('The CSV could not be saved.'),
        findsOneWidget,
      );
      expect(tester.widget<DesktopIconButton>(export).onPressed, isNotNull);
      expect(calls, 3);
    },
  );

  testWidgets('unavailable storage does not turn missing records into zero', (
    WidgetTester tester,
  ) async {
    final TokenUsageController controller = TokenUsageController.preview(
      const TokenUsageSnapshot(
        storageAvailable: false,
        coverage: <TokenUsageSourceCoverage>[
          TokenUsageSourceCoverage(
            source: ConversationTokenUsageSource.codex,
            availability: TokenUsageAvailability.available,
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    await pumpUsage(tester, controller);
    expectSummaryValues('Not reported');
    expect(find.textContaining('Local storage is unavailable'), findsOneWidget);
  });

  testWidgets('partial-only cumulative logs do not confirm zero daily usage', (
    WidgetTester tester,
  ) async {
    final TokenUsageController controller = TokenUsageController.preview(
      const TokenUsageSnapshot(
        coverage: <TokenUsageSourceCoverage>[
          TokenUsageSourceCoverage(
            source: ConversationTokenUsageSource.codex,
            availability: TokenUsageAvailability.available,
          ),
        ],
        warnings: <String>['incomplete_cumulative_totals'],
      ),
    );
    addTearDown(controller.dispose);
    await pumpUsage(tester, controller);
    expectSummaryValues('Not reported');
    final DingDongLocalizations strings = tester
        .element(find.byKey(const Key('token-usage-screen')))
        .l10n;
    expect(
      find.text(strings.tokenUsageIncompleteCumulativeNote),
      findsOneWidget,
    );
  });

  testWidgets('ambiguous counter order marks estimates without a daily bound', (
    WidgetTester tester,
  ) async {
    final TokenUsageController controller = TokenUsageController.preview(
      TokenUsageSnapshot(
        days: <TokenUsageDay>[
          TokenUsageDay(
            day: DateTime(2026, 1, 10),
            source: ConversationTokenUsageSource.codex,
            totals: const TokenUsageTotals(
              totalTokens: 300,
              totalIsExact: false,
              dateAttributionExact: false,
            ),
            eventCount: 2,
          ),
        ],
        coverage: const <TokenUsageSourceCoverage>[
          TokenUsageSourceCoverage(
            source: ConversationTokenUsageSource.codex,
            availability: TokenUsageAvailability.available,
          ),
        ],
        warnings: const <String>['ambiguous_counter_epoch'],
      ),
    );
    addTearDown(controller.dispose);
    await pumpUsage(tester, controller);
    final DingDongLocalizations strings = tester
        .element(find.byKey(const Key('token-usage-screen')))
        .l10n;
    expect(find.text('Total  ≈ 300'), findsOneWidget);
    expect(find.textContaining('≥ 300'), findsNothing);
    expect(find.text(strings.tokenUsageLowerBoundNote), findsNothing);
    expect(
      find.text(strings.tokenUsageAmbiguousCumulativeNote),
      findsOneWidget,
    );
    final Tooltip tooltip = tester.widget<Tooltip>(
      find.descendant(
        of: find.byKey(const Key('token-usage-day-2026-01-10')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, contains('≈ 300'));
    expect(tooltip.message, isNot(contains('≥')));
  });

  testWidgets('empty history with ambiguous counters remains unknown', (
    WidgetTester tester,
  ) async {
    final TokenUsageController controller = TokenUsageController.preview(
      const TokenUsageSnapshot(
        coverage: <TokenUsageSourceCoverage>[
          TokenUsageSourceCoverage(
            source: ConversationTokenUsageSource.codex,
            availability: TokenUsageAvailability.available,
          ),
        ],
        warnings: <String>['ambiguous_counter_epoch'],
      ),
    );
    addTearDown(controller.dispose);
    await pumpUsage(tester, controller);
    expectSummaryValues('Not reported');
  });

  testWidgets('unfinished local usage tail leaves empty totals unknown', (
    WidgetTester tester,
  ) async {
    final TokenUsageController controller = TokenUsageController.preview(
      const TokenUsageSnapshot(
        coverage: <TokenUsageSourceCoverage>[
          TokenUsageSourceCoverage(
            source: ConversationTokenUsageSource.codex,
            availability: TokenUsageAvailability.available,
            pendingFiles: 1,
          ),
        ],
        warnings: <String>['pending_transcript_tail'],
      ),
    );
    addTearDown(controller.dispose);
    await pumpUsage(tester, controller);
    expectSummaryValues('Not reported');
    final DingDongLocalizations strings = tester
        .element(find.byKey(const Key('token-usage-screen')))
        .l10n;
    expect(find.text(strings.tokenUsagePendingFiles('1')), findsOneWidget);
  });

  testWidgets(
    'skipped usage rows cannot confirm zero but retain known records',
    (WidgetTester tester) async {
      final TokenUsageController controller = TokenUsageController.preview(
        TokenUsageSnapshot(
          days: <TokenUsageDay>[
            TokenUsageDay(
              day: DateTime(2026, 1, 9),
              source: ConversationTokenUsageSource.codex,
              totals: const TokenUsageTotals(totalTokens: 1000),
              eventCount: 1,
            ),
          ],
          coverage: const <TokenUsageSourceCoverage>[
            TokenUsageSourceCoverage(
              source: ConversationTokenUsageSource.codex,
              availability: TokenUsageAvailability.available,
              malformedRows: 2,
              undatedRows: 1,
            ),
          ],
          // Coverage alone must preserve unknown emptiness, even if no warning
          // codes were emitted by an older writer.
        ),
      );
      addTearDown(controller.dispose);
      await pumpUsage(tester, controller);
      expect(
        find.descendant(
          of: find.byKey(const Key('token-usage-today')),
          matching: find.text('Not reported'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('token-usage-period')),
          matching: find.text('1,000'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('token-usage-active-days')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('initial read failure leaves usage unknown and permits retry', (
    WidgetTester tester,
  ) async {
    final TokenUsageController controller = TokenUsageController(
      loadSnapshot: () =>
          Future<TokenUsageSnapshot>.error(StateError('initial read failed')),
    );
    addTearDown(controller.dispose);
    await pumpUsage(tester, controller);
    expectSummaryValues('Not reported');
    expect(controller.hasLoaded, isFalse);
    expect(find.byKey(const Key('token-usage-error')), findsOneWidget);
  });

  testWidgets(
    'loading is visible; failure permits retry and preserves history',
    (WidgetTester tester) async {
      final Completer<TokenUsageSnapshot> initial =
          Completer<TokenUsageSnapshot>();
      int attempts = 0;
      final TokenUsageController controller = TokenUsageController(
        loadSnapshot: () {
          attempts += 1;
          return attempts == 1
              ? initial.future
              : Future<TokenUsageSnapshot>.error(StateError('read failed'));
        },
      );
      addTearDown(controller.dispose);
      await pumpUsage(tester, controller, settle: false);
      expect(find.text('Reading local token history…'), findsOneWidget);
      final DesktopIconButton refresh = tester.widget<DesktopIconButton>(
        find.byKey(const Key('token-usage-refresh')),
      );
      expect(refresh.onPressed, isNull);
      expect(refresh.tooltip, 'Refresh local history');
      expect(refresh.icon, isA<SizedBox>());
      initial.complete(usageFixture());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('token-usage-refresh')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('token-usage-error')), findsOneWidget);
      expect(controller.snapshot.days, hasLength(4));
      expect(controller.isLoading, isFalse);
      expect(
        tester
            .widget<DesktopIconButton>(
              find.byKey(const Key('token-usage-refresh')),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

void expectSummaryValues(String value) {
  for (final String metric in <String>['today', 'period', 'active-days']) {
    expect(
      find.descendant(
        of: find.byKey(Key('token-usage-$metric')),
        matching: find.text(value),
      ),
      findsOneWidget,
    );
  }
}

Future<void> pumpUsage(
  WidgetTester tester,
  TokenUsageController controller, {
  Size size = const Size(1120, 1000),
  Locale locale = const Locale('en'),
  bool dark = false,
  bool settle = true,
  DateTime? now,
  TokenUsageCsvSaver? saveExport,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final ThemeData theme = dark
      ? AppTheme.desktopPanelDark()
      : AppTheme.desktopPanelLight();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: locale,
      supportedLocales: DingDongLocalizations.supportedLocales,
      localizationsDelegates: DingDongLocalizations.localizationsDelegates,
      home: Scaffold(
        body: RepaintBoundary(
          key: const Key('token-usage-golden'),
          child: ColoredBox(
            color: theme.scaffoldBackgroundColor,
            child: TokenUsageScreen(
              controller: controller,
              now: () => now ?? DateTime(2026, 1, 10, 12),
              saveExport: saveExport ?? saveTokenUsageCsv,
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

TokenUsageSnapshot usageFixture() => TokenUsageSnapshot(
  refreshedAt: DateTime(2026, 1, 10, 12),
  days: <TokenUsageDay>[
    TokenUsageDay(
      day: DateTime(2026, 1, 9),
      source: ConversationTokenUsageSource.codex,
      totals: const TokenUsageTotals(
        totalTokens: 1000,
        inputTokens: 800,
        outputTokens: 200,
        cachedInputTokens: 600,
        cacheWriteInputTokens: 0,
        reasoningOutputTokens: 50,
      ),
      eventCount: 4,
    ),
    TokenUsageDay(
      day: DateTime(2026, 1, 9),
      source: ConversationTokenUsageSource.claudeCode,
      totals: const TokenUsageTotals(
        totalTokens: 500,
        inputTokens: 400,
        outputTokens: 100,
        cachedInputTokens: 200,
        cacheWriteInputTokens: 50,
      ),
      eventCount: 2,
    ),
    TokenUsageDay(
      day: DateTime(2026, 1, 10),
      source: ConversationTokenUsageSource.pi,
      totals: const TokenUsageTotals(totalTokens: 900),
      eventCount: 1,
      partialEventCount: 1,
    ),
    TokenUsageDay(
      day: DateTime(2025, 12, 20),
      source: ConversationTokenUsageSource.codex,
      totals: const TokenUsageTotals(
        totalTokens: 40,
        inputTokens: 30,
        outputTokens: 10,
        cachedInputTokens: 0,
        cacheWriteInputTokens: 0,
        reasoningOutputTokens: 0,
      ),
      eventCount: 1,
    ),
  ],
  coverage: const <TokenUsageSourceCoverage>[
    TokenUsageSourceCoverage(
      source: ConversationTokenUsageSource.codex,
      availability: TokenUsageAvailability.available,
      filesScanned: 2,
    ),
    TokenUsageSourceCoverage(
      source: ConversationTokenUsageSource.claudeCode,
      availability: TokenUsageAvailability.available,
      filesScanned: 1,
    ),
    TokenUsageSourceCoverage(
      source: ConversationTokenUsageSource.pi,
      availability: TokenUsageAvailability.available,
      filesScanned: 1,
    ),
  ],
);
