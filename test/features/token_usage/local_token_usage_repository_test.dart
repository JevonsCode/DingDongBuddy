import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/token_usage/data/local_token_usage_repository.dart';
import 'package:dingdong/features/token_usage/domain/token_usage_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory temporary;
  late Directory codex;
  late Directory archived;
  late Directory claude;
  late Directory pi;
  late String databasePath;
  late LocalTokenUsageRepository repository;
  final repositories = <LocalTokenUsageRepository>[];

  LocalTokenUsageRepository create({
    DateTime Function(DateTime)? toLocal,
    Directory? claudeRoot,
  }) {
    final result = LocalTokenUsageRepository(
      databasePath: databasePath,
      codexSessionsDirectory: codex,
      codexArchivedSessionsDirectory: archived,
      claudeProjectsDirectory: claudeRoot ?? claude,
      piSessionsDirectory: pi,
      clock: () => DateTime.utc(2026, 10, 9),
      toLocal: toLocal ?? (value) => value,
    );
    repositories.add(result);
    return result;
  }

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('dingdong-local-token-');
    codex = await Directory(path.join(temporary.path, 'codex')).create();
    archived = await Directory(path.join(temporary.path, 'archive')).create();
    claude = await Directory(path.join(temporary.path, 'claude')).create();
    pi = await Directory(path.join(temporary.path, 'pi')).create();
    databasePath = path.join(temporary.path, 'usage.sqlite');
    repository = create();
  });

  tearDown(() async {
    for (final value in repositories) {
      await value.close();
    }
    repositories.clear();
    await temporary.delete(recursive: true);
  });

  test(
    'Codex imports dated deltas, deduplicates archives, and survives reopen',
    () async {
      final file = File(path.join(codex.path, 'rollout-one.jsonl'));
      final rows = [
        _codexMeta('session-one'),
        _codex(
          '2026-09-01T10:00:00Z',
          total: 100,
          input: 80,
          output: 20,
          cached: 30,
          reasoning: 5,
        ),
        _codex(
          '2026-09-02T11:00:00Z',
          total: 250,
          input: 200,
          output: 50,
          cached: 70,
          reasoning: 10,
        ),
      ];
      await _write(file, rows);
      expect((await repository.refresh()).importedEvents, 2);
      var snapshot = await repository.readSnapshot();
      expect(snapshot.days.map((day) => day.totals.totalTokens), [100, 150]);
      expect(snapshot.totals.totalTokens, 250);
      expect(snapshot.totals.reasoningOutputTokens, 10);
      expect(snapshot.totals.nonCachedTokens, 180);
      await _write(File(path.join(archived.path, 'renamed-copy.jsonl')), rows);
      expect((await repository.refresh()).importedEvents, 0);
      await repository.close();
      repository = create();
      expect((await repository.refresh()).importedEvents, 0);
      await file.writeAsString(
        '${jsonEncode(_codex('2026-09-02T12:00:00Z', total: 300, input: 240, output: 60, cached: 80, reasoning: 12))}\n',
        mode: FileMode.append,
      );
      expect((await repository.refresh()).importedEvents, 1);
      snapshot = await repository.readSnapshot();
      expect(snapshot.totals.totalTokens, 300);
      expect(snapshot.days.last.totals.totalTokens, 200);
    },
  );

  test(
    'older snapshots imported later repair the successor on its actual day',
    () async {
      await _write(File(path.join(codex.path, 'newer.jsonl')), [
        _codexMeta('same-session'),
        _codex('2026-09-02T10:00:00Z', total: 250, input: 200, output: 50),
      ]);
      await repository.refresh();
      await _write(File(path.join(archived.path, 'older.jsonl')), [
        _codexMeta('same-session'),
        _codex('2026-09-01T10:00:00Z', total: 100, input: 80, output: 20),
      ]);
      await repository.refresh();
      final snapshot = await repository.readSnapshot();
      expect(snapshot.totals.totalTokens, 250);
      expect(snapshot.days.map((day) => day.totals.totalTokens), [100, 150]);
      expect(snapshot.days.map((day) => day.eventCount), [1, 1]);
    },
  );

  test(
    'same-session restart and compaction resets count each counter epoch once',
    () async {
      await _write(File(path.join(codex.path, 'first.jsonl')), [
        _codexMeta('restart'),
        _codex('2026-09-01T10:00:00Z', total: 250, input: 200, output: 50),
      ]);
      await repository.refresh();
      await _write(File(path.join(codex.path, 'second.jsonl')), [
        _codexMeta('restart'),
        _codex('2026-09-02T10:00:00Z', total: 300, input: 240, output: 60),
        _codex('2026-09-02T10:01:00Z', total: 300, input: 240, output: 60),
        _codex('2026-09-03T10:00:00Z', total: 100, input: 80, output: 20),
        _codex('2026-09-04T10:00:00Z', total: 150, input: 120, output: 30),
      ]);
      await repository.refresh();
      final snapshot = await repository.readSnapshot();
      expect(snapshot.totals.totalTokens, 450);
      expect(snapshot.days.map((day) => day.totals.totalTokens), [
        250,
        50,
        100,
        50,
      ]);
      expect((await repository.refresh()).importedEvents, 0);
    },
  );

  test(
    'Claude streaming updates and subagents normalize cache reads and writes',
    () async {
      final main = File(path.join(claude.path, 'main.jsonl'));
      await _write(main, [
        _claude(
          '2026-09-01T10:00:00Z',
          request: 'request-1',
          input: 10,
          output: 5,
          cached: 20,
          write: 30,
        ),
        _claude(
          '2026-09-01T10:00:01Z',
          request: 'request-1',
          input: 10,
          output: 8,
          cached: 20,
          write: 30,
        ),
      ]);
      final subagent = File(
        path.join(claude.path, 'main', 'subagents', 'agent-a.jsonl'),
      );
      await subagent.parent.create(recursive: true);
      await _write(subagent, [
        _claude(
          '2026-09-01T11:00:00Z',
          request: 'request-2',
          agentId: 'agent-a',
          input: 2,
          output: 3,
          cached: 4,
          write: 5,
        ),
      ]);
      await repository.refresh();
      final snapshot = await repository.readSnapshot(
        source: ConversationTokenUsageSource.claudeCode,
      );
      expect(snapshot.totals.totalTokens, 82);
      expect(snapshot.totals.inputTokens, 71);
      expect(snapshot.totals.outputTokens, 11);
      expect(snapshot.totals.cachedInputTokens, 24);
      expect(snapshot.totals.cacheWriteInputTokens, 35);
      expect(snapshot.totals.breakdownComplete, isTrue);
      expect(snapshot.days.single.eventCount, 2);
      await _write(File(path.join(claude.path, 'main-copy.jsonl')), [
        _claude(
          '2026-09-01T10:00:01Z',
          request: 'request-1',
          input: 10,
          output: 8,
          cached: 20,
          write: 30,
        ),
      ]);
      expect((await repository.refresh()).importedEvents, 0);
    },
  );

  test(
    'Pi response, compaction, branch summaries and tool usage deduplicate',
    () async {
      final rows = <Map<String, Object?>>[
        {'type': 'session', 'id': 'pi-session'},
        _pi(
          'message',
          'response',
          '2026-09-01T10:00:00Z',
          input: 10,
          output: 5,
          cached: 20,
          write: 3,
          reasoning: 2,
        ),
        _pi(
          'compaction',
          'compaction',
          '2026-09-02T10:00:00Z',
          input: 2,
          output: 3,
          cached: 0,
          write: 1,
        ),
        _pi(
          'branch_summary',
          'summary',
          '2026-09-02T11:00:00Z',
          input: 4,
          output: 2,
          cached: 1,
          write: 0,
        ),
        _pi(
          'message',
          'tool',
          '2026-09-02T12:00:00Z',
          role: 'toolResult',
          input: 1,
          output: 1,
          cached: 0,
          write: 0,
        ),
      ];
      await _write(File(path.join(pi.path, 'pi.jsonl')), rows);
      await _write(File(path.join(pi.path, 'pi-copy.jsonl')), rows);
      await repository.refresh();
      final snapshot = await repository.readSnapshot(
        source: ConversationTokenUsageSource.pi,
      );
      expect(snapshot.totals.totalTokens, 53);
      expect(snapshot.totals.reasoningOutputTokens, 2);
      expect(snapshot.days.map((day) => day.eventCount), [1, 3]);
    },
  );

  test(
    'partial breakdown keeps unknown components and lower-bound totals',
    () async {
      final exact = _codex(
        '2026-09-01T10:00:00Z',
        total: 100,
        input: 80,
        output: 20,
      );
      final payload = exact['payload']! as Map<String, Object?>;
      final counts =
          (payload['info']! as Map<String, Object?>)['total_token_usage']!
              as Map<String, Object?>;
      counts.remove('cached_input_tokens');
      await _write(File(path.join(codex.path, 'partial.jsonl')), [
        _codexMeta('partial'),
        exact,
      ]);
      await _write(File(path.join(claude.path, 'cache-only.jsonl')), [
        {
          'type': 'assistant',
          'sessionId': 'claude',
          'requestId': 'cache-only',
          'timestamp': '2026-09-01T10:00:00Z',
          'message': {
            'usage': {'cache_read_input_tokens': 50},
          },
        },
      ]);
      await repository.refresh();
      final snapshot = await repository.readSnapshot();
      expect(snapshot.totals.totalTokens, 150);
      expect(snapshot.totals.totalIsExact, isFalse);
      expect(snapshot.totals.inputTokens, isNull);
      expect(snapshot.totals.outputTokens, isNull);
      expect(snapshot.totals.cachedInputTokens, isNull);
      expect(snapshot.days.every((day) => day.partialEventCount == 1), isTrue);
      final codexOnly = await repository.readSnapshot(
        source: ConversationTokenUsageSource.codex,
      );
      expect(codexOnly.totals.totalIsExact, isTrue);
      expect(codexOnly.totals.cachedInputTokens, isNull);
    },
  );

  test(
    'byte checkpoints wait for partial UTF-8 and complete JSONL boundaries',
    () async {
      final file = File(path.join(codex.path, 'partial-tail.jsonl'));
      final first =
          '${jsonEncode(_codexMeta('utf8'))}\n${jsonEncode(_codex('2026-09-01T10:00:00Z', total: 100, input: 80, output: 20))}\n';
      final second = _codex(
        '2026-09-02T10:00:00Z',
        total: 150,
        input: 120,
        output: 30,
      )..['private'] = '秘密🌟';
      final bytes = utf8.encode('${jsonEncode(second)}\n');
      final split = bytes.indexOf(0xf0) + 2;
      await file.writeAsBytes([...utf8.encode(first), ...bytes.take(split)]);
      await repository.refresh();
      expect((await repository.readSnapshot()).totals.totalTokens, 100);
      expect(
        (await repository.readSnapshot()).coverage
            .firstWhere(
              (value) => value.source == ConversationTokenUsageSource.codex,
            )
            .pendingFiles,
        1,
      );
      await repository.close();
      repository = create();
      await file.writeAsBytes(
        bytes.skip(split).toList(),
        mode: FileMode.append,
      );
      await repository.refresh();
      expect((await repository.readSnapshot()).totals.totalTokens, 150);
      expect((await repository.refresh()).importedEvents, 0);
    },
  );

  test(
    'local midnight and inclusive date filters use event time rather than import time',
    () async {
      await repository.close();
      repository = create(
        toLocal: (value) => value.add(const Duration(hours: 8)),
      );
      await _write(File(path.join(codex.path, 'midnight.jsonl')), [
        _codexMeta('midnight'),
        _codex('2026-09-01T15:59:59Z', total: 100, input: 80, output: 20),
        _codex('2026-09-01T16:00:00Z', total: 250, input: 200, output: 50),
      ]);
      await repository.refresh();
      final firstDay = await repository.readSnapshot(
        from: DateTime(2026, 9, 1, 12),
        through: DateTime(2026, 9, 1, 23),
      );
      expect(firstDay.days.single.day, DateTime(2026, 9, 1));
      expect(firstDay.totals.totalTokens, 100);
      expect(
        (await repository.readSnapshot(
          from: DateTime(2026, 9, 2),
          through: DateTime(2026, 9, 2),
        )).totals.totalTokens,
        150,
      );
      expect(
        (await repository.readSnapshot(from: DateTime(2026, 10, 9))).days,
        isEmpty,
      );
    },
  );

  test(
    'truncated and rewritten files replay safely, including new sessions',
    () async {
      final file = File(path.join(codex.path, 'rotated.jsonl'));
      await _write(file, [
        _codexMeta('old'),
        _codex('2026-09-01T10:00:00Z', total: 100, input: 80, output: 20),
      ]);
      await repository.refresh();
      await _write(file, [
        _codexMeta('old'),
        _codex('2026-09-01T10:00:00Z', total: 100, input: 80, output: 20),
      ]);
      expect((await repository.refresh()).importedEvents, 0);
      await _write(file, [
        _codexMeta('new'),
        _codex('2026-09-02T10:00:00Z', total: 120, input: 100, output: 20),
      ]);
      await repository.refresh();
      expect((await repository.readSnapshot()).totals.totalTokens, 220);
      await file.writeAsString('');
      await repository.refresh();
      await _write(file, [
        _codexMeta('new'),
        _codex('2026-09-02T10:00:00Z', total: 120, input: 100, output: 20),
      ]);
      expect((await repository.refresh()).importedEvents, 0);
    },
  );

  test(
    'malformed and undated rows are diagnosed without persisting secrets',
    () async {
      const secret = 'do-not-store-message-or-api-key-123456';
      final file = File(path.join(codex.path, 'private-path-$secret.jsonl'));
      await file.writeAsString(
        'broken-secret-$secret\n${jsonEncode(_codexMeta('session-$secret'))}\n${jsonEncode(_codex('2026-09-01T10:00:00Z', total: 100, input: 80, output: 20)..['message'] = secret)}\n${jsonEncode(_codex('2026-09-01T10:00:00Z', total: 200, input: 160, output: 40)..remove('timestamp'))}\n',
      );
      final report = await repository.refresh();
      expect(report.skippedRows, 2);
      final snapshot = await repository.readSnapshot();
      expect(snapshot.totals.totalTokens, 100);
      expect(
        snapshot.warnings,
        containsAll(['malformed_usage_rows', 'missing_event_dates']),
      );
      expect((await repository.refresh()).skippedRows, 0);
      await repository.close();
      expect(
        latin1.decode(await File(databasePath).readAsBytes()).contains(secret),
        isFalse,
      );
      final database = sqlite3.open(databasePath);
      try {
        expect(
          database.select('SELECT * FROM token_usage_events').single.keys,
          isNot(contains('message')),
        );
        expect(
          database
              .select('SELECT * FROM token_usage_files')
              .single['path_hash'],
          hasLength(64),
        );
      } finally {
        database.close();
      }
    },
  );

  test(
    'oversized and invalid UTF-8 rows stay bounded and do not block subsequent events',
    () async {
      final file = File(path.join(codex.path, 'bad-row.jsonl'));
      await file.writeAsBytes([
        ...List.filled(1024 * 1024 + 20, 65),
        10,
        0xff,
        10,
        ...utf8.encode(
          '${jsonEncode(_codexMeta('after-bad'))}\n${jsonEncode(_codex('2026-09-01T10:00:00Z', total: 100, input: 80, output: 20))}\n',
        ),
      ]);
      expect((await repository.refresh()).skippedRows, 2);
      expect((await repository.readSnapshot()).totals.totalTokens, 100);
    },
  );

  test(
    'two connections can import and read without counting a response twice',
    () async {
      final second = create();
      await Future.wait([repository.readSnapshot(), second.readSnapshot()]);
      await _write(File(path.join(codex.path, 'concurrent.jsonl')), [
        _codexMeta('concurrent'),
        for (var i = 1; i <= 200; i++)
          _codex(
            '2026-09-01T10:${(i ~/ 60).toString().padLeft(2, '0')}:${(i % 60).toString().padLeft(2, '0')}Z',
            total: i * 10,
            input: i * 8,
            output: i * 2,
          ),
      ]);
      final refresh = Future.wait([repository.refresh(), second.refresh()]);
      expect((await second.readSnapshot()).storageAvailable, isTrue);
      await refresh;
      expect((await repository.readSnapshot()).totals.totalTokens, 2000);
      expect((await second.readSnapshot()).totals.totalTokens, 2000);
      expect((await repository.refresh()).importedEvents, 0);
    },
  );

  test(
    'busy interruption reports committed batches and resumes exactly once',
    () async {
      await repository.close();
      late Database blocker;
      var lockScheduled = false;
      repository = create(
        toLocal: (value) {
          if (!lockScheduled) {
            lockScheduled = true;
            // Conversion runs synchronously inside the first import transaction.
            // The microtask acquires the other writer only after that batch commits.
            scheduleMicrotask(() => blocker.execute('BEGIN IMMEDIATE'));
          }
          return value;
        },
      );
      await repository.readSnapshot();
      blocker = sqlite3.open(databasePath);
      var locked = true;
      try {
        final lines = [
          'malformed',
          jsonEncode(_codexMeta('busy-batches')),
          for (var i = 1; i <= 300; i++)
            jsonEncode(
              _codex(
                DateTime.utc(
                  2026,
                  9,
                  1,
                ).add(Duration(seconds: i)).toIso8601String(),
                total: i * 10,
                input: i * 8,
                output: i * 2,
              ),
            ),
        ];
        await File(
          path.join(codex.path, 'busy.jsonl'),
        ).writeAsString('${lines.join('\n')}\n');
        final interrupted = await repository.refresh();
        expect(interrupted.warnings, contains('refresh_interrupted'));
        final committed = blocker
            .select('SELECT COUNT(*) AS n FROM token_usage_events')
            .single['n'];
        expect(committed, 126);
        expect(interrupted.importedEvents, committed);
        expect(interrupted.skippedRows, 1);
        expect(
          blocker
              .select('SELECT byte_offset FROM token_usage_files')
              .single['byte_offset'],
          utf8.encode('${lines.take(128).join('\n')}\n').length,
        );
        blocker.execute('ROLLBACK');
        locked = false;
        final resumed = await repository.refresh();
        expect(resumed.warnings, isNot(contains('refresh_interrupted')));
        expect(interrupted.importedEvents + resumed.importedEvents, 300);
        expect(resumed.skippedRows, 0);
        expect((await repository.readSnapshot()).totals.totalTokens, 3000);
        expect((await repository.refresh()).importedEvents, 0);
      } finally {
        if (locked && lockScheduled) blocker.execute('ROLLBACK');
        blocker.close();
      }
    },
  );

  test(
    'same-timestamp Codex resets keep transcript order across checkpoints and copies',
    () async {
      final file = File(path.join(codex.path, 'same-time.jsonl'));
      final rows = [
        _codexMeta('same-time'),
        _codex('2026-09-01T10:00:00Z', total: 100, input: 80, output: 20),
        _codex('2026-09-02T10:00:00Z', total: 300, input: 240, output: 60),
      ];
      await _write(file, rows);
      await repository.refresh();
      final reset = _codex(
        '2026-09-02T10:00:00Z',
        total: 50,
        input: 40,
        output: 10,
      );
      await file.writeAsString('${jsonEncode(reset)}\n', mode: FileMode.append);
      await repository.close();
      repository = create();
      await repository.refresh();
      expect((await repository.readSnapshot()).totals.totalTokens, 350);
      await _write(File(path.join(archived.path, 'copy.jsonl')), [
        ...rows,
        reset,
      ]);
      await repository.refresh();
      expect((await repository.readSnapshot()).totals.totalTokens, 350);
    },
  );

  for (final reversed in [false, true]) {
    test(
      'Claude cross-midnight stream uses final observation date independent of reverse=$reversed',
      () async {
        final rows = [
          _claude(
            '2026-09-01T23:59:59Z',
            request: 'midnight-response',
            input: 10,
            output: 1,
            cached: 0,
            write: 0,
          ),
          _claude(
            '2026-09-02T00:00:01Z',
            request: 'midnight-response',
            input: 10,
            output: 100,
            cached: 0,
            write: 0,
          ),
        ];
        await _write(
          File(path.join(claude.path, 'midnight.jsonl')),
          reversed ? rows.reversed.toList() : rows,
        );
        await repository.refresh();
        final snapshot = await repository.readSnapshot();
        expect(snapshot.days.single.day, DateTime(2026, 9, 2));
        expect(snapshot.days.single.totals.totalTokens, 110);
        expect(snapshot.days.single.eventCount, 1);
      },
    );
  }

  test(
    'partial Codex counters never become subtraction baselines or fake daily lower bounds',
    () async {
      final partial = _codex(
        '2026-09-01T10:00:00Z',
        total: 50,
        input: 50,
        output: 0,
      );
      final counts =
          ((partial['payload']! as Map<String, Object?>)['info']!
                  as Map<String, Object?>)['total_token_usage']!
              as Map<String, Object?>;
      counts.remove('total_tokens');
      counts.remove('output_tokens');
      await _write(File(path.join(codex.path, 'partial-counter.jsonl')), [
        _codexMeta('partial-counter'),
        partial,
        _codex('2026-09-02T10:00:00Z', total: 100, input: 90, output: 10),
      ]);
      await repository.refresh();
      final snapshot = await repository.readSnapshot();
      expect(snapshot.totals.totalTokens, 100);
      expect(snapshot.days.single.day, DateTime(2026, 9, 2));
      expect(snapshot.totals.totalIsExact, isTrue);
      expect(snapshot.totals.dateAttributionExact, isFalse);
      expect(
        snapshot.warnings,
        containsAll(['daily_attribution_gap', 'incomplete_cumulative_totals']),
      );
    },
  );

  test(
    'partial counters between exact snapshots do not inflate the cumulative total',
    () async {
      final partial = _codex(
        '2026-09-02T10:00:00Z',
        total: 120,
        input: 120,
        output: 0,
      );
      final counts =
          ((partial['payload']! as Map<String, Object?>)['info']!
                  as Map<String, Object?>)['total_token_usage']!
              as Map<String, Object?>;
      counts.remove('total_tokens');
      counts.remove('output_tokens');
      await _write(File(path.join(codex.path, 'between.jsonl')), [
        _codexMeta('between'),
        _codex('2026-09-01T10:00:00Z', total: 100, input: 80, output: 20),
        partial,
        _codex('2026-09-03T10:00:00Z', total: 150, input: 120, output: 30),
      ]);
      await repository.refresh();
      final snapshot = await repository.readSnapshot();
      expect(snapshot.totals.totalTokens, 150);
      expect(snapshot.days.map((day) => day.totals.totalTokens), [100, 50]);
      expect(snapshot.days.first.totals.dateAttributionExact, isTrue);
      expect(snapshot.days.last.totals.dateAttributionExact, isFalse);
    },
  );

  test(
    'complete final JSON without newline imports and enriched counters repair breakdown',
    () async {
      final file = File(path.join(codex.path, 'no-newline.jsonl'));
      final partial = _codex(
        '2026-09-01T10:00:00Z',
        total: 100,
        input: 80,
        output: 20,
      );
      final counts =
          ((partial['payload']! as Map<String, Object?>)['info']!
                  as Map<String, Object?>)['total_token_usage']!
              as Map<String, Object?>;
      counts.remove('cached_input_tokens');
      await file.writeAsString(
        '${jsonEncode(_codexMeta('enriched'))}\n${jsonEncode(partial)}',
      );
      await repository.refresh();
      expect((await repository.readSnapshot()).totals.totalTokens, 100);
      expect(
        (await repository.readSnapshot()).totals.breakdownComplete,
        isFalse,
      );
      await file.writeAsString(
        '\n${jsonEncode(_codex('2026-09-01T10:00:00Z', total: 100, input: 80, output: 20, cached: 30))}\n',
        mode: FileMode.append,
      );
      await repository.refresh();
      final snapshot = await repository.readSnapshot();
      expect(snapshot.totals.totalTokens, 100);
      expect(snapshot.totals.cachedInputTokens, 30);
      expect(snapshot.totals.breakdownComplete, isTrue);
      expect(snapshot.days.single.eventCount, 1);
    },
  );

  test(
    'aggregated inconsistencies cannot cancel out into a complete breakdown',
    () async {
      final first = _claude(
        '2026-09-01T10:00:00Z',
        request: 'first',
        input: 80,
        output: 10,
        cached: 0,
        write: 0,
      );
      final second = _claude(
        '2026-09-01T11:00:00Z',
        request: 'second',
        input: 80,
        output: 30,
        cached: 0,
        write: 0,
      );
      for (final row in [first, second]) {
        ((row['message']! as Map<String, Object?>)['usage']!
                as Map<String, Object?>)['total_tokens'] =
            100;
      }
      await _write(File(path.join(claude.path, 'inconsistent.jsonl')), [
        first,
        second,
      ]);
      await repository.refresh();
      final snapshot = await repository.readSnapshot();
      expect(snapshot.totals.totalTokens, 200);
      expect(snapshot.totals.inputTokens! + snapshot.totals.outputTokens!, 200);
      expect(snapshot.totals.breakdownComplete, isFalse);
      expect(snapshot.days.single.partialEventCount, 2);
    },
  );

  test(
    'repeated counters after a same-timestamp reset are explicitly incomplete, not falsely exact',
    () async {
      final rows = [
        _codexMeta('ambiguous'),
        _codex('2026-09-01T10:00:00Z', total: 100, input: 80, output: 20),
        _codex('2026-09-02T10:00:00Z', total: 300, input: 240, output: 60),
        _codex('2026-09-02T10:00:00Z', total: 50, input: 40, output: 10),
        _codex('2026-09-02T10:00:00Z', total: 300, input: 240, output: 60),
      ];
      await _write(File(path.join(codex.path, 'ambiguous.jsonl')), rows);
      await repository.refresh();
      final snapshot = await repository.readSnapshot();
      expect(snapshot.totals.totalTokens, 350);
      expect(snapshot.totals.totalIsExact, isFalse);
      expect(snapshot.totals.dateAttributionExact, isFalse);
      expect(snapshot.warnings, contains('ambiguous_counter_epoch'));
      await _write(
        File(path.join(archived.path, 'ambiguous-copy.jsonl')),
        rows,
      );
      await repository.refresh();
      expect((await repository.readSnapshot()).totals.totalTokens, 350);
      expect((await repository.readSnapshot()).totals.totalIsExact, isFalse);
    },
  );

  test(
    'missing roots differ from unreadable roots, without inventing Agent zeros',
    () async {
      await pi.delete();
      final badRoot = File(path.join(temporary.path, 'not-a-directory'));
      await badRoot.writeAsString('');
      await repository.close();
      repository = create(claudeRoot: Directory(badRoot.path));
      await repository.refresh();
      final snapshot = await repository.readSnapshot();
      expect(snapshot.days, isEmpty);
      expect(
        snapshot.coverage
            .firstWhere(
              (value) => value.source == ConversationTokenUsageSource.pi,
            )
            .availability,
        TokenUsageAvailability.missing,
      );
      expect(
        snapshot.coverage
            .firstWhere(
              (value) =>
                  value.source == ConversationTokenUsageSource.claudeCode,
            )
            .availability,
        TokenUsageAvailability.unreadable,
      );
      expect(ConversationTokenUsageSource.parse('unsupported-agent'), isNull);
    },
  );

  test(
    'custom Agent environment roots import all sources including archived Codex',
    () async {
      await repository.close();
      final customCodex = Directory(path.join(temporary.path, 'custom-codex'));
      final customClaude = Directory(
        path.join(temporary.path, 'custom-claude'),
      );
      final customPi = Directory(path.join(temporary.path, 'custom-pi'));
      final codexFile = File(
        path.join(customCodex.path, 'archived_sessions', 'custom.jsonl'),
      );
      final claudeFile = File(
        path.join(customClaude.path, 'projects', 'custom.jsonl'),
      );
      final piFile = File(path.join(customPi.path, 'sessions', 'custom.jsonl'));
      for (final file in [codexFile, claudeFile, piFile]) {
        await file.parent.create(recursive: true);
      }
      await _write(codexFile, [
        _codexMeta('custom'),
        _codex('2026-09-01T10:00:00Z', total: 50, input: 40, output: 10),
      ]);
      await _write(claudeFile, [
        _claude(
          '2026-09-01T10:00:00Z',
          request: 'custom',
          input: 10,
          output: 5,
          cached: 3,
          write: 2,
        ),
      ]);
      await _write(piFile, [
        {'type': 'session', 'id': 'custom-pi'},
        _pi(
          'message',
          'custom',
          '2026-09-01T10:00:00Z',
          input: 10,
          output: 5,
          cached: 10,
          write: 5,
        ),
      ]);
      repository = LocalTokenUsageRepository(
        databasePath: databasePath,
        environment: {
          'CODEX_HOME': customCodex.path,
          'CLAUDE_CONFIG_DIR': customClaude.path,
          'PI_CODING_AGENT_DIR': customPi.path,
          'HOME': temporary.path,
        },
        toLocal: (value) => value,
      );
      repositories.add(repository);
      await repository.refresh();
      final snapshot = await repository.readSnapshot();
      expect(
        snapshot.days.map((day) => day.source).toSet(),
        ConversationTokenUsageSource.values.toSet(),
      );
      expect(snapshot.totals.totalTokens, 100);
    },
  );

  test(
    'injected home wins over host Agent environment while explicit source root wins home',
    () async {
      await repository.close();
      final defaultCodex = File(
        path.join(temporary.path, '.codex', 'sessions', 'home.jsonl'),
      );
      await defaultCodex.parent.create(recursive: true);
      await _write(defaultCodex, [
        _codexMeta('home'),
        _codex('2026-09-01T10:00:00Z', total: 50, input: 40, output: 10),
      ]);
      await _write(File(path.join(claude.path, 'explicit.jsonl')), [
        _claude(
          '2026-09-01T10:00:00Z',
          request: 'explicit',
          input: 10,
          output: 5,
          cached: 3,
          write: 2,
        ),
      ]);
      repository = LocalTokenUsageRepository(
        databasePath: databasePath,
        homeDirectory: temporary,
        environment: {
          'CODEX_HOME': 'unread-agent-home',
          'CLAUDE_CONFIG_DIR': 'unread-agent-home',
        },
        claudeProjectsDirectory: claude,
        toLocal: (value) => value,
      );
      repositories.add(repository);
      await repository.refresh();
      expect((await repository.readSnapshot()).totals.totalTokens, 70);
      expect(
        (await repository.readSnapshot()).coverage
            .firstWhere(
              (row) => row.source == ConversationTokenUsageSource.codex,
            )
            .availability,
        TokenUsageAvailability.available,
      );
    },
  );

  test(
    'unavailable DB and cancelled refresh fail gracefully and close is terminal',
    () async {
      final unavailable = LocalTokenUsageRepository(
        databasePath: temporary.path,
        homeDirectory: temporary,
      );
      repositories.add(unavailable);
      expect((await unavailable.refresh()).storageAvailable, isFalse);
      expect((await unavailable.readSnapshot()).storageAvailable, isFalse);
      await repository.readSnapshot();
      final refresh = repository.refresh();
      repository.cancelRefresh();
      expect((await refresh).cancelled, isTrue);
      expect(
        (await repository.readSnapshot()).warnings,
        contains('refresh_cancelled'),
      );
      expect(
        (await repository.refresh()).warnings,
        isNot(contains('refresh_cancelled')),
      );
      await repository.close();
      expect((await repository.refresh()).cancelled, isTrue);
      expect(
        (await repository.readSnapshot()).warnings,
        contains('repository_closed'),
      );
    },
  );
}

Future<void> _write(File file, List<Map<String, Object?>> rows) =>
    file.writeAsString('${rows.map(jsonEncode).join('\n')}\n');

Map<String, Object?> _codexMeta(String id) => {
  'type': 'session_meta',
  'payload': {'id': id},
};

Map<String, Object?> _codex(
  String at, {
  required int total,
  required int input,
  required int output,
  int cached = 0,
  int reasoning = 0,
}) => {
  'type': 'event_msg',
  'timestamp': at,
  'payload': {
    'type': 'token_count',
    'info': {
      'total_token_usage': {
        'total_tokens': total,
        'input_tokens': input,
        'output_tokens': output,
        'cached_input_tokens': cached,
        'reasoning_output_tokens': reasoning,
      },
    },
  },
};

Map<String, Object?> _claude(
  String at, {
  required String request,
  required int input,
  required int output,
  required int cached,
  required int write,
  String? agentId,
}) => {
  'type': 'assistant',
  'timestamp': at,
  'sessionId': 'claude-session',
  'requestId': request,
  'agentId': ?agentId,
  'message': {
    'id': 'message-$request',
    'usage': {
      'input_tokens': input,
      'output_tokens': output,
      'cache_read_input_tokens': cached,
      'cache_creation_input_tokens': write,
    },
  },
};

Map<String, Object?> _pi(
  String type,
  String id,
  String at, {
  required int input,
  required int output,
  required int cached,
  required int write,
  int reasoning = 0,
  String role = 'assistant',
}) {
  final usage = {
    'input': input,
    'output': output,
    'cacheRead': cached,
    'cacheWrite': write,
    'reasoning': reasoning,
    'totalTokens': input + output + cached + write,
  };
  return {
    'type': type,
    'id': id,
    'timestamp': at,
    if (type == 'message')
      'message': {'role': role, 'usage': usage}
    else
      'usage': usage,
  };
}
