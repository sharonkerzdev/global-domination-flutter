import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'crash_log_entry.dart';

class CrashLogRepository {
  CrashLogRepository(this._db);

  final AppDatabase _db;

  static const int _ringSize = 100;

  Future<void> append(CrashLogEntry entry) async {
    await _db.transaction(() async {
      await _db
          .into(_db.crashLogs)
          .insert(
            CrashLogsCompanion.insert(
              timestamp: entry.timestamp,
              level: entry.level,
              tag: entry.tag,
              message: entry.message,
              stackTrace: Value(entry.stackTrace),
            ),
          );

      final keepIds =
          await (_db.select(_db.crashLogs)
                ..orderBy([
                  (t) => OrderingTerm.desc(t.timestamp),
                  (t) => OrderingTerm.desc(t.id),
                ])
                ..limit(_ringSize))
              .map((row) => row.id)
              .get();

      if (keepIds.isNotEmpty) {
        await (_db.delete(
          _db.crashLogs,
        )..where((t) => t.id.isNotIn(keepIds))).go();
      }
    });
  }

  Future<List<CrashLogEntry>> readAllNewestFirst() async {
    final rows =
        await (_db.select(_db.crashLogs)..orderBy([
              (t) => OrderingTerm.desc(t.timestamp),
              (t) => OrderingTerm.desc(t.id),
            ]))
            .get();
    return rows.map(_rowToEntry).toList();
  }

  Future<void> clearAll() async {
    await _db.delete(_db.crashLogs).go();
  }

  CrashLogEntry _rowToEntry(CrashLogRow row) {
    return CrashLogEntry(
      timestamp: row.timestamp,
      level: row.level,
      tag: row.tag,
      message: row.message,
      stackTrace: row.stackTrace,
    );
  }
}
