import 'package:sqlite3/sqlite3.dart';

/// Local accounting only: never stores prompts, answers, or credentials.
final class JevStore {
  JevStore(this.db) {
    db.execute('PRAGMA busy_timeout = 5000');
    db.execute('''CREATE TABLE IF NOT EXISTS jev_plugin (
      id INTEGER PRIMARY KEY CHECK(id=1), installed INTEGER NOT NULL DEFAULT 0,
      enabled INTEGER NOT NULL DEFAULT 0)''');
    db.execute('INSERT OR IGNORE INTO jev_plugin(id) VALUES(1)');
    db.execute('''CREATE TABLE IF NOT EXISTS jev_usage (
      id INTEGER PRIMARY KEY, created_at TEXT NOT NULL, source TEXT NOT NULL,
      conversation_id TEXT NOT NULL, outcome TEXT NOT NULL,
      input_tokens INTEGER, output_tokens INTEGER, estimated_usd REAL)''');
  }
  final Database db;
  bool get installed =>
      db.select('SELECT installed FROM jev_plugin')[0]['installed'] == 1;
  bool get enabled =>
      installed &&
      db.select('SELECT enabled FROM jev_plugin')[0]['enabled'] == 1;
  void install() => db.execute('UPDATE jev_plugin SET installed=1 WHERE id=1');
  void setEnabled(bool value) =>
      db.execute('UPDATE jev_plugin SET enabled=? WHERE id=1', [value ? 1 : 0]);
  void uninstall() =>
      db.execute('UPDATE jev_plugin SET installed=0, enabled=0 WHERE id=1');
  int begin(DateTime at, String source, String conversation) {
    db.execute(
      'INSERT INTO jev_usage(created_at, source, conversation_id, outcome) VALUES(?,?,?,?)',
      [at.toUtc().toIso8601String(), source, conversation, 'unknown'],
    );
    return db.lastInsertRowId;
  }

  void finish(int id, String outcome, {int? input, int? output}) {
    db.execute(
      'UPDATE jev_usage SET outcome=?, input_tokens=?, output_tokens=?, estimated_usd=? WHERE id=?',
      [
        outcome,
        input,
        output,
        input == null ? null : input * 0.042 / 1000000,
        id,
      ],
    );
  }

  Map<String, Object?> usage({
    DateTime? since,
    String? source,
    String? conversation,
  }) {
    final conditions = <String>[];
    final args = <Object?>[];
    if (since != null) {
      conditions.add('created_at>=?');
      args.add(since.toUtc().toIso8601String());
    }
    if (source != null) {
      conditions.add('source=?');
      args.add(source.trim().toLowerCase());
    }
    if (conversation != null) {
      conditions.add('conversation_id=?');
      args.add(conversation);
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final row = db.select('''SELECT COUNT(*) AS requests,
      COALESCE(SUM(input_tokens),0) AS input_tokens,
      COALESCE(SUM(output_tokens),0) AS output_tokens,
      COALESCE(SUM(estimated_usd),0) AS estimated_usd,
      COALESCE(SUM(CASE WHEN input_tokens IS NULL OR output_tokens IS NULL THEN 1 ELSE 0 END),0) AS unknown_usage_requests,
      COALESCE(SUM(CASE WHEN outcome='success' THEN 1 ELSE 0 END),0) AS successes
      FROM jev_usage $where''', args).single;
    return {
      ...row,
      'provider': 'Jev',
      'scope': 'this_device_plugin_only',
      'total_tokens':
          (row['input_tokens'] as int) + (row['output_tokens'] as int),
      'price_checked': '2026-09-21',
      'is_bill': false,
    };
  }
}
