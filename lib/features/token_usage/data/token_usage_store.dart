import 'package:sqlite3/sqlite3.dart';

import '../domain/token_usage_models.dart';

/// The import ledger contains hashes, timestamps and token integers only.
/// Keeping the numeric observations allows out-of-order cumulative snapshots
/// to repair their successor's delta without retaining any transcript text.
final class TokenUsageImportEvent {
  const TokenUsageImportEvent({
    required this.source,
    required this.sessionHash,
    required this.identityHash,
    required this.occurredAt,
    required this.totals,
    required this.cumulative,
    this.precedingCounterHash,
  });

  final ConversationTokenUsageSource source;
  final String sessionHash;
  final String identityHash;
  final DateTime occurredAt;
  final TokenUsageTotals totals;
  final bool cumulative;
  final String? precedingCounterHash;
}

final class TokenUsageFileCheckpoint {
  const TokenUsageFileCheckpoint({
    required this.offset,
    required this.headLength,
    required this.headHash,
    required this.tailHash,
    this.sessionHash,
    this.malformedRows = 0,
    this.undatedRows = 0,
    this.lastCounterHash,
  });

  final int offset;
  final int headLength;
  final String headHash;
  final String tailHash;
  final String? sessionHash;
  final int malformedRows;
  final int undatedRows;
  final String? lastCounterHash;
}

final class TokenUsageStore {
  TokenUsageStore(this.database, {DateTime Function(DateTime)? toLocal})
    : _toLocal = toLocal ?? ((value) => value.toLocal()) {
    // A short bounded lock wait lets another app window refresh without
    // freezing notification delivery for seconds. Busy failures are retried
    // by the next refresh, and committed checkpoints stay valid.
    database.execute('PRAGMA busy_timeout=100');
    database.execute('PRAGMA journal_mode=WAL');
    database.execute('PRAGMA synchronous=NORMAL');
    database.execute('''CREATE TABLE IF NOT EXISTS token_usage_events (
      source TEXT NOT NULL, session_hash TEXT NOT NULL, event_hash TEXT NOT NULL,
      occurred_at INTEGER NOT NULL, cumulative INTEGER NOT NULL,
      raw_total INTEGER NOT NULL, raw_input INTEGER, raw_output INTEGER,
      raw_cached INTEGER, raw_write INTEGER, raw_reasoning INTEGER,
      raw_exact INTEGER NOT NULL,
      day TEXT NOT NULL, delta_total INTEGER NOT NULL DEFAULT 0,
      delta_input INTEGER, delta_output INTEGER, delta_cached INTEGER,
      delta_write INTEGER, delta_reasoning INTEGER, delta_exact INTEGER NOT NULL,
      delta_attribution INTEGER NOT NULL DEFAULT 1,
      preceding_counter TEXT, counter_order INTEGER NOT NULL DEFAULT 0,
      ambiguous_epoch INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(source,event_hash))''');
    database.execute('''CREATE TABLE IF NOT EXISTS token_usage_days (
      day TEXT NOT NULL, source TEXT NOT NULL, total INTEGER NOT NULL,
      input INTEGER NOT NULL, output INTEGER NOT NULL, cached INTEGER NOT NULL,
      cache_write INTEGER NOT NULL, reasoning INTEGER NOT NULL,
      unknown_input INTEGER NOT NULL, unknown_output INTEGER NOT NULL,
      unknown_cached INTEGER NOT NULL, unknown_write INTEGER NOT NULL,
      unknown_reasoning INTEGER NOT NULL, inexact INTEGER NOT NULL,
      events INTEGER NOT NULL, partial INTEGER NOT NULL,
      attribution_gaps INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(day,source))''');
    database.execute('''CREATE TABLE IF NOT EXISTS token_usage_files (
      path_hash TEXT PRIMARY KEY, source TEXT NOT NULL, byte_offset INTEGER NOT NULL,
      head_length INTEGER NOT NULL, head_hash TEXT NOT NULL, tail_hash TEXT NOT NULL,
      session_hash TEXT, malformed_rows INTEGER NOT NULL, undated_rows INTEGER NOT NULL,
      last_counter TEXT)''');
    database.execute('''CREATE TABLE IF NOT EXISTS token_usage_coverage (
      source TEXT PRIMARY KEY, availability TEXT NOT NULL, files_scanned INTEGER NOT NULL,
      malformed_rows INTEGER NOT NULL, undated_rows INTEGER NOT NULL,
      pending_files INTEGER NOT NULL)''');
    database.execute('''CREATE TABLE IF NOT EXISTS token_usage_meta (
      key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
    _ensureColumn(
      'token_usage_events',
      'delta_attribution',
      'INTEGER NOT NULL DEFAULT 1',
    );
    _ensureColumn(
      'token_usage_days',
      'attribution_gaps',
      'INTEGER NOT NULL DEFAULT 0',
    );
    _ensureColumn('token_usage_events', 'preceding_counter', 'TEXT');
    _ensureColumn(
      'token_usage_events',
      'counter_order',
      'INTEGER NOT NULL DEFAULT 0',
    );
    _ensureColumn(
      'token_usage_events',
      'ambiguous_epoch',
      'INTEGER NOT NULL DEFAULT 0',
    );
    _ensureColumn('token_usage_files', 'last_counter', 'TEXT');
    database.execute(
      '''CREATE INDEX IF NOT EXISTS token_usage_counter_sequence
      ON token_usage_events(source,session_hash,cumulative,occurred_at,counter_order,event_hash)''',
    );
    database.execute('DROP INDEX IF EXISTS token_usage_session_order');
    database.execute('DROP INDEX IF EXISTS token_usage_counter_order');
  }

  final Database database;
  final DateTime Function(DateTime) _toLocal;

  void _ensureColumn(String table, String column, String definition) {
    if (!database
        .select('PRAGMA table_info($table)')
        .any((row) => row['name'] == column)) {
      database.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  TokenUsageFileCheckpoint? checkpoint(String pathHash) {
    final rows = database.select(
      'SELECT * FROM token_usage_files WHERE path_hash=?',
      [pathHash],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return TokenUsageFileCheckpoint(
      offset: row['byte_offset'] as int,
      headLength: row['head_length'] as int,
      headHash: row['head_hash'] as String,
      tailHash: row['tail_hash'] as String,
      sessionHash: row['session_hash'] as String?,
      malformedRows: row['malformed_rows'] as int,
      undatedRows: row['undated_rows'] as int,
      lastCounterHash: row['last_counter'] as String?,
    );
  }

  /// No awaits occur inside a transaction: readers on other connections can
  /// continue against WAL, while writers hold the lock only for a small batch.
  int importBatch({
    required List<TokenUsageImportEvent> events,
    required String pathHash,
    required ConversationTokenUsageSource source,
    required TokenUsageFileCheckpoint checkpoint,
  }) {
    var imported = 0;
    database.execute('BEGIN IMMEDIATE');
    try {
      for (final event in events) {
        if (_record(event)) imported++;
      }
      database.execute(
        '''INSERT INTO token_usage_files VALUES(?,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(path_hash) DO UPDATE SET
        source=excluded.source,byte_offset=excluded.byte_offset,
        head_length=excluded.head_length,head_hash=excluded.head_hash,
        tail_hash=excluded.tail_hash,session_hash=excluded.session_hash,
        malformed_rows=excluded.malformed_rows,undated_rows=excluded.undated_rows,last_counter=excluded.last_counter''',
        [
          pathHash,
          source.apiValue,
          checkpoint.offset,
          checkpoint.headLength,
          checkpoint.headHash,
          checkpoint.tailHash,
          checkpoint.sessionHash,
          checkpoint.malformedRows,
          checkpoint.undatedRows,
          checkpoint.lastCounterHash,
        ],
      );
      database.execute('COMMIT');
      return imported;
    } on Object {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  bool _record(TokenUsageImportEvent event) {
    final source = event.source.apiValue;
    final existingRows = database.select(
      'SELECT * FROM token_usage_events WHERE source=? AND event_hash=?',
      [source, event.identityHash],
    );
    var totals = event.totals;
    if (existingRows.isNotEmpty) {
      final existing = existingRows.single;
      totals = _merge(_totals(existing, 'raw_'), totals);
      final latestAt =
          event.occurredAt.toUtc().microsecondsSinceEpoch >
              (existing['occurred_at'] as int)
          ? event.occurredAt.toUtc().microsecondsSinceEpoch
          : existing['occurred_at'] as int;
      final latestDay = dayKey(
        _toLocal(DateTime.fromMicrosecondsSinceEpoch(latestAt, isUtc: true)),
      );
      final newPredecessor =
          existing['preceding_counter'] == null &&
          event.precedingCounterHash != null;
      final ambiguous =
          event.cumulative &&
          existing['preceding_counter'] != null &&
          event.precedingCounterHash != null &&
          existing['preceding_counter'] != event.precedingCounterHash;
      final newlyAmbiguous = ambiguous && existing['ambiguous_epoch'] != 1;
      if (_same(_totals(existing, 'raw_'), totals) &&
          latestAt == existing['occurred_at'] &&
          !newPredecessor &&
          !newlyAmbiguous) {
        return false;
      }
      if (!event.cumulative) {
        _changeDay(
          existing['day'] as String,
          source,
          _totals(existing, 'delta_'),
          -1,
        );
      }
      database.execute(
        '''UPDATE token_usage_events SET
        raw_total=?,raw_input=?,raw_output=?,raw_cached=?,raw_write=?,raw_reasoning=?,raw_exact=?,
        occurred_at=?,day=?,preceding_counter=COALESCE(preceding_counter,?),ambiguous_epoch=MAX(ambiguous_epoch,?)
        WHERE source=? AND event_hash=?''',
        [
          ..._values(totals),
          latestAt,
          latestDay,
          event.precedingCounterHash,
          ambiguous ? 1 : 0,
          source,
          event.identityHash,
        ],
      );
    } else {
      final local = _toLocal(event.occurredAt);
      database.execute(
        '''INSERT INTO token_usage_events (
        source,session_hash,event_hash,occurred_at,cumulative,
        raw_total,raw_input,raw_output,raw_cached,raw_write,raw_reasoning,raw_exact,
        day,delta_exact,preceding_counter) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,1,?)''',
        [
          source,
          event.sessionHash,
          event.identityHash,
          event.occurredAt.toUtc().microsecondsSinceEpoch,
          event.cumulative ? 1 : 0,
          ..._values(totals),
          dayKey(local),
          event.precedingCounterHash,
        ],
      );
    }
    final row = database.select(
      'SELECT * FROM token_usage_events WHERE source=? AND event_hash=?',
      [source, event.identityHash],
    ).single;
    if (event.cumulative) {
      _rebuildCumulativeAt(row);
      return true;
    }
    final delta = totals;
    _setDelta(row, delta);
    _changeDay(row['day'] as String, source, delta, 1);
    return true;
  }

  void _rebuildCumulativeAt(Row row) {
    // Millisecond timestamps can repeat around a reset. Predecessor hashes
    // preserve transcript observation order, including across checkpoints.
    // Repair copied/out-of-order chains in SQLite rather than sorting counters.
    database.execute(
      '''WITH RECURSIVE ordered(event_hash,ordinal,depth) AS (
      SELECT e.event_hash,0,0 FROM token_usage_events e
      LEFT JOIN token_usage_events p ON p.source=e.source AND p.event_hash=e.preceding_counter
      WHERE e.source=? AND e.session_hash=? AND e.occurred_at=? AND e.cumulative=1
        AND (p.event_hash IS NULL OR p.occurred_at<>e.occurred_at)
      UNION ALL
      SELECT child.event_hash,ordered.ordinal+1,ordered.depth+1
      FROM ordered JOIN token_usage_events child ON child.preceding_counter=ordered.event_hash
      WHERE child.source=? AND child.session_hash=? AND child.occurred_at=?
        AND child.cumulative=1 AND ordered.depth<256)
      UPDATE token_usage_events SET counter_order=COALESCE(
        (SELECT MAX(ordinal) FROM ordered WHERE ordered.event_hash=token_usage_events.event_hash),0)
      WHERE source=? AND session_hash=? AND occurred_at=? AND cumulative=1''',
      [
        row['source'],
        row['session_hash'],
        row['occurred_at'],
        row['source'],
        row['session_hash'],
        row['occurred_at'],
        row['source'],
        row['session_hash'],
        row['occurred_at'],
      ],
    );
    void recalculate(Row observation) {
      _changeDay(
        observation['day'] as String,
        observation['source'] as String,
        _totals(observation, 'delta_'),
        -1,
      );
      final delta = _cumulativeDelta(observation);
      _setDelta(observation, delta);
      _changeDay(
        observation['day'] as String,
        observation['source'] as String,
        delta,
        1,
      );
    }

    var offset = 0;
    while (true) {
      final tied = database.select(
        '''SELECT * FROM token_usage_events
        WHERE source=? AND session_hash=? AND occurred_at=? AND cumulative=1
        ORDER BY counter_order,event_hash LIMIT 128 OFFSET ?''',
        [row['source'], row['session_hash'], row['occurred_at'], offset],
      );
      if (tied.isEmpty) break;
      for (final observation in tied) {
        recalculate(observation);
      }
      offset += tied.length;
    }
    final next = database.select(
      '''SELECT * FROM token_usage_events
      WHERE source=? AND session_hash=? AND occurred_at>? AND cumulative=1 AND raw_exact=1
      ORDER BY occurred_at,counter_order,event_hash LIMIT 1''',
      [row['source'], row['session_hash'], row['occurred_at']],
    );
    if (next.isNotEmpty) recalculate(next.single);
  }

  Row? _neighbor(Row row, {required bool previous}) {
    final op = previous ? '<' : '>';
    final order = previous ? 'DESC' : 'ASC';
    final rows = database.select(
      '''SELECT * FROM token_usage_events
      WHERE source=? AND session_hash=? AND cumulative=1 AND raw_exact=1 AND
      (occurred_at $op ? OR (occurred_at=? AND
        (counter_order $op ? OR (counter_order=? AND event_hash $op ?))))
      ORDER BY occurred_at $order,counter_order $order,event_hash $order LIMIT 1''',
      [
        row['source'],
        row['session_hash'],
        row['occurred_at'],
        row['occurred_at'],
        row['counter_order'],
        row['counter_order'],
        row['event_hash'],
      ],
    );
    return rows.isEmpty ? null : rows.single;
  }

  TokenUsageTotals _cumulativeDelta(Row row) {
    // An incomplete cumulative total is not a valid subtraction baseline:
    // subtracting a lower bound from an exact counter would create an upper
    // bound and mislabel it as measured daily usage.
    if (row['raw_exact'] != 1) return TokenUsageTotals.zero;
    final previous = _neighbor(row, previous: true);
    final delta = _delta(_totals(row, 'raw_'), previous);
    final partial = database
        .select(
          '''SELECT 1 FROM token_usage_events
      WHERE source=? AND session_hash=? AND cumulative=1 AND raw_exact=0
      AND occurred_at<=? ${previous == null ? '' : 'AND occurred_at>?'} LIMIT 1''',
          [
            row['source'],
            row['session_hash'],
            row['occurred_at'],
            if (previous != null) previous['occurred_at'],
          ],
        )
        .isNotEmpty;
    final ambiguous = database
        .select(
          '''SELECT 1 FROM token_usage_events
      WHERE source=? AND session_hash=? AND cumulative=1 AND ambiguous_epoch=1
      AND occurred_at<=? ${previous == null ? '' : 'AND occurred_at>=?'} LIMIT 1''',
          [
            row['source'],
            row['session_hash'],
            row['occurred_at'],
            if (previous != null) previous['occurred_at'],
          ],
        )
        .isNotEmpty;
    if (!partial && !ambiguous) return delta;
    return TokenUsageTotals(
      totalTokens: delta.totalTokens,
      inputTokens: delta.inputTokens,
      outputTokens: delta.outputTokens,
      cachedInputTokens: delta.cachedInputTokens,
      cacheWriteInputTokens: delta.cacheWriteInputTokens,
      reasoningOutputTokens: delta.reasoningOutputTokens,
      totalIsExact: delta.totalIsExact && !ambiguous,
      dateAttributionExact: false,
    );
  }

  TokenUsageTotals _delta(TokenUsageTotals current, Row? previous) {
    if (previous == null) return current;
    final before = _totals(previous, 'raw_');
    // Codex resets cumulative counters after some compactions/restarts.
    // The first lower observation starts a fresh counter epoch.
    if (current.totalTokens < before.totalTokens) return current;
    int? difference(int? value, int? old) =>
        value == null || old == null || value < old ? null : value - old;
    return TokenUsageTotals(
      totalTokens: current.totalTokens - before.totalTokens,
      inputTokens: difference(current.inputTokens, before.inputTokens),
      outputTokens: difference(current.outputTokens, before.outputTokens),
      cachedInputTokens: difference(
        current.cachedInputTokens,
        before.cachedInputTokens,
      ),
      cacheWriteInputTokens: difference(
        current.cacheWriteInputTokens,
        before.cacheWriteInputTokens,
      ),
      reasoningOutputTokens: difference(
        current.reasoningOutputTokens,
        before.reasoningOutputTokens,
      ),
      totalIsExact: current.totalIsExact && before.totalIsExact,
    );
  }

  void _setDelta(Row row, TokenUsageTotals totals) {
    database.execute(
      '''UPDATE token_usage_events SET
      delta_total=?,delta_input=?,delta_output=?,delta_cached=?,delta_write=?,delta_reasoning=?,delta_exact=?,delta_attribution=?
      WHERE source=? AND event_hash=?''',
      [
        ..._values(totals),
        totals.dateAttributionExact ? 1 : 0,
        row['source'],
        row['event_hash'],
      ],
    );
  }

  void _changeDay(
    String day,
    String source,
    TokenUsageTotals totals,
    int sign,
  ) {
    if (totals.totalTokens <= 0) return;
    final values = <int>[
      totals.totalTokens,
      totals.inputTokens ?? 0,
      totals.outputTokens ?? 0,
      totals.cachedInputTokens ?? 0,
      totals.cacheWriteInputTokens ?? 0,
      totals.reasoningOutputTokens ?? 0,
      totals.inputTokens == null ? 1 : 0,
      totals.outputTokens == null ? 1 : 0,
      totals.cachedInputTokens == null ? 1 : 0,
      totals.cacheWriteInputTokens == null ? 1 : 0,
      totals.reasoningOutputTokens == null ? 1 : 0,
      totals.totalIsExact ? 0 : 1,
      1,
      totals.breakdownComplete ? 0 : 1,
      totals.dateAttributionExact ? 0 : 1,
    ].map((value) => value * sign).toList();
    database.execute(
      '''INSERT INTO token_usage_days VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
      ON CONFLICT(day,source) DO UPDATE SET total=total+excluded.total,
      input=input+excluded.input,output=output+excluded.output,cached=cached+excluded.cached,
      cache_write=cache_write+excluded.cache_write,reasoning=reasoning+excluded.reasoning,
      unknown_input=unknown_input+excluded.unknown_input,
      unknown_output=unknown_output+excluded.unknown_output,
      unknown_cached=unknown_cached+excluded.unknown_cached,
      unknown_write=unknown_write+excluded.unknown_write,
      unknown_reasoning=unknown_reasoning+excluded.unknown_reasoning,
      inexact=inexact+excluded.inexact,events=events+excluded.events,partial=partial+excluded.partial,
      attribution_gaps=attribution_gaps+excluded.attribution_gaps''',
      [day, source, ...values],
    );
    database.execute(
      'DELETE FROM token_usage_days WHERE day=? AND source=? AND events=0',
      [day, source],
    );
  }

  void recordCoverage(
    List<TokenUsageSourceCoverage> coverage,
    DateTime refreshedAt,
  ) {
    database.execute('BEGIN IMMEDIATE');
    try {
      for (final value in coverage) {
        database.execute(
          '''INSERT INTO token_usage_coverage VALUES(?,?,?,?,?,?)
          ON CONFLICT(source) DO UPDATE SET availability=excluded.availability,
          files_scanned=excluded.files_scanned,malformed_rows=excluded.malformed_rows,
          undated_rows=excluded.undated_rows,pending_files=excluded.pending_files''',
          [
            value.source.apiValue,
            value.availability.name,
            value.filesScanned,
            value.malformedRows,
            value.undatedRows,
            value.pendingFiles,
          ],
        );
      }
      database.execute('INSERT OR REPLACE INTO token_usage_meta VALUES(?,?)', [
        'refreshed_at',
        refreshedAt.toUtc().toIso8601String(),
      ]);
      database.execute('COMMIT');
    } on Object {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  TokenUsageSnapshot snapshot({
    DateTime? from,
    DateTime? through,
    ConversationTokenUsageSource? source,
  }) {
    final conditions = <String>[];
    final args = <Object?>[];
    if (from != null) {
      conditions.add('day>=?');
      args.add(dayKey(from));
    }
    if (through != null) {
      conditions.add('day<=?');
      args.add(dayKey(through));
    }
    if (source != null) {
      conditions.add('source=?');
      args.add(source.apiValue);
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = database.select(
      'SELECT * FROM token_usage_days $where ORDER BY day,source',
      args,
    );
    final days = <TokenUsageDay>[
      for (final row in rows)
        TokenUsageDay(
          day: DateTime.parse(row['day'] as String),
          source: ConversationTokenUsageSource.parse(row['source'])!,
          totals: TokenUsageTotals(
            totalTokens: row['total'] as int,
            inputTokens: row['unknown_input'] == 0 ? row['input'] as int : null,
            outputTokens: row['unknown_output'] == 0
                ? row['output'] as int
                : null,
            cachedInputTokens: row['unknown_cached'] == 0
                ? row['cached'] as int
                : null,
            cacheWriteInputTokens: row['unknown_write'] == 0
                ? row['cache_write'] as int
                : null,
            reasoningOutputTokens: row['unknown_reasoning'] == 0
                ? row['reasoning'] as int
                : null,
            totalIsExact: row['inexact'] == 0,
            breakdownComplete: row['partial'] == 0,
            dateAttributionExact: row['attribution_gaps'] == 0,
          ),
          eventCount: row['events'] as int,
          partialEventCount: row['partial'] as int,
        ),
    ];
    final coverage = <TokenUsageSourceCoverage>[
      for (final row in database.select(
        'SELECT * FROM token_usage_coverage ORDER BY source',
      ))
        if (source == null || row['source'] == source.apiValue)
          TokenUsageSourceCoverage(
            source: ConversationTokenUsageSource.parse(row['source'])!,
            availability: TokenUsageAvailability.values.byName(
              row['availability'] as String,
            ),
            filesScanned: row['files_scanned'] as int,
            malformedRows: row['malformed_rows'] as int,
            undatedRows: row['undated_rows'] as int,
            pendingFiles: row['pending_files'] as int,
          ),
    ];
    final meta = database.select(
      'SELECT value FROM token_usage_meta WHERE key=?',
      ['refreshed_at'],
    );
    return TokenUsageSnapshot(
      days: List.unmodifiable(days),
      coverage: List.unmodifiable(coverage),
      refreshedAt: meta.isEmpty
          ? null
          : DateTime.tryParse(meta.single['value'] as String)?.toLocal(),
      warnings: [
        if (days.any((day) => !day.totals.dateAttributionExact))
          'daily_attribution_gap',
        if (database
            .select(
              '''SELECT 1 FROM token_usage_events WHERE cumulative=1 AND raw_exact=0
          ${source == null ? '' : 'AND source=?'} LIMIT 1''',
              [if (source != null) source.apiValue],
            )
            .isNotEmpty)
          'incomplete_cumulative_totals',
        if (database
            .select(
              '''SELECT 1 FROM token_usage_events WHERE ambiguous_epoch=1
          ${source == null ? '' : 'AND source=?'} LIMIT 1''',
              [if (source != null) source.apiValue],
            )
            .isNotEmpty)
          'ambiguous_counter_epoch',
      ],
    );
  }

  static String dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static List<Object?> _values(TokenUsageTotals value) => [
    value.totalTokens,
    value.inputTokens,
    value.outputTokens,
    value.cachedInputTokens,
    value.cacheWriteInputTokens,
    value.reasoningOutputTokens,
    value.totalIsExact ? 1 : 0,
  ];

  static TokenUsageTotals _totals(Row row, String prefix) => TokenUsageTotals(
    totalTokens: row['${prefix}total'] as int,
    inputTokens: row['${prefix}input'] as int?,
    outputTokens: row['${prefix}output'] as int?,
    cachedInputTokens: row['${prefix}cached'] as int?,
    cacheWriteInputTokens: row['${prefix}write'] as int?,
    reasoningOutputTokens: row['${prefix}reasoning'] as int?,
    totalIsExact: row['${prefix}exact'] == 1,
    dateAttributionExact: prefix != 'delta_' || row['delta_attribution'] == 1,
  );

  static TokenUsageTotals _merge(TokenUsageTotals a, TokenUsageTotals b) {
    int? maximum(int? x, int? y) => x == null
        ? y
        : y == null
        ? x
        : x > y
        ? x
        : y;
    final total = a.totalTokens > b.totalTokens ? a.totalTokens : b.totalTokens;
    return TokenUsageTotals(
      totalTokens: total,
      inputTokens: maximum(a.inputTokens, b.inputTokens),
      outputTokens: maximum(a.outputTokens, b.outputTokens),
      cachedInputTokens: maximum(a.cachedInputTokens, b.cachedInputTokens),
      cacheWriteInputTokens: maximum(
        a.cacheWriteInputTokens,
        b.cacheWriteInputTokens,
      ),
      reasoningOutputTokens: maximum(
        a.reasoningOutputTokens,
        b.reasoningOutputTokens,
      ),
      totalIsExact:
          (a.totalTokens == total && a.totalIsExact) ||
          (b.totalTokens == total && b.totalIsExact),
    );
  }

  static bool _same(TokenUsageTotals a, TokenUsageTotals b) =>
      a.totalTokens == b.totalTokens &&
      a.inputTokens == b.inputTokens &&
      a.outputTokens == b.outputTokens &&
      a.cachedInputTokens == b.cachedInputTokens &&
      a.cacheWriteInputTokens == b.cacheWriteInputTokens &&
      a.reasoningOutputTokens == b.reasoningOutputTokens &&
      a.totalIsExact == b.totalIsExact;
}
