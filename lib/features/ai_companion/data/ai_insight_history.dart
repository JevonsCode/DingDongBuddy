import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../domain/ai_companion_models.dart';
import '../domain/ai_companion_privacy.dart';

final class AiInsightEntry {
  const AiInsightEntry(this.report, {required this.automatic});
  final AiCompanionReport report;
  final bool automatic;
}

/// Separate local database: paged reads never load the full history. No source
/// clipboard text, resource bodies, prompts or credentials are stored here.
final class AiInsightHistory {
  AiInsightHistory(this.path);
  final String path;

  T _withDatabase<T>(T Function(Database) action) {
    File(path).parent.createSync(recursive: true);
    final db = sqlite3.open(path);
    try {
      db.execute('PRAGMA busy_timeout = 3000');
      db.execute(
        'CREATE TABLE IF NOT EXISTS insights ('
        'id INTEGER PRIMARY KEY, report TEXT NOT NULL, automatic INTEGER NOT NULL)',
      );
      db.execute(
        'CREATE TABLE IF NOT EXISTS analysis_state ('
        'id INTEGER PRIMARY KEY CHECK(id=1), fingerprint TEXT NOT NULL)',
      );
      return action(db);
    } finally {
      db.close();
    }
  }

  void save(
    AiCompanionReport report, {
    required bool automatic,
    String? fingerprint,
  }) {
    _withDatabase((db) {
      db.execute('BEGIN IMMEDIATE');
      try {
        db.execute(
          'INSERT INTO insights VALUES (?, ?, ?) '
          'ON CONFLICT(id) DO UPDATE SET report=excluded.report',
          [
            report.createdAt.microsecondsSinceEpoch,
            jsonEncode(report.toJson()),
            automatic ? 1 : 0,
          ],
        );
        if (fingerprint != null) {
          db.execute('INSERT OR REPLACE INTO analysis_state VALUES (1, ?)', [
            fingerprint,
          ]);
        }
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    });
  }

  String? get fingerprint => _withDatabase(
    (db) =>
        db
                .select('SELECT fingerprint FROM analysis_state WHERE id=1')
                .firstOrNull?['fingerprint']
            as String?,
  );

  int get count => _withDatabase(
    (db) => db.select('SELECT COUNT(*) AS n FROM insights').first['n'] as int,
  );

  List<AiInsightEntry> page({int offset = 0, int limit = 20}) => _withDatabase((
    db,
  ) {
    return db
        .select(
          'SELECT report, automatic FROM insights ORDER BY id DESC LIMIT ? OFFSET ?',
          [limit.clamp(1, 100), offset < 0 ? 0 : offset],
        )
        .map((row) {
          try {
            final report = AiCompanionReport.fromJson(
              jsonDecode(row['report'] as String) as Map<String, Object?>,
            );
            if (report == null) return null;
            final summary = report.cloudSummary;
            if (summary != null &&
                (summary.length > 8000 ||
                    !const AiCompanionPrivacy().isSafeText(summary))) {
              return null;
            }
            return AiInsightEntry(report, automatic: row['automatic'] == 1);
          } on FormatException {
            return null;
          }
        })
        .whereType<AiInsightEntry>()
        .toList(growable: false);
  });
}
