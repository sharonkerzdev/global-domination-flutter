import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/repositories/crash_log_entry.dart';
import 'package:global_domination/data/repositories/crash_log_repository.dart';

void main() {
  group('CrashLogRepository', () {
    late AppDatabase db;
    late CrashLogRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = CrashLogRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    CrashLogEntry makeEntry({
      DateTime? timestamp,
      CrashLogLevel level = CrashLogLevel.severe,
      String tag = 'Tag',
      String message = 'msg',
      String? stackTrace,
    }) {
      return CrashLogEntry(
        timestamp: timestamp ?? DateTime.now(),
        level: level,
        tag: tag,
        message: message,
        stackTrace: stackTrace,
      );
    }

    test('append inserts a row and readAllNewestFirst returns it', () async {
      final entry = makeEntry(message: 'hello');
      await repo.append(entry);
      final rows = await repo.readAllNewestFirst();
      expect(rows, hasLength(1));
      expect(rows.first.message, 'hello');
      expect(rows.first.level, CrashLogLevel.severe);
    });

    test('readAllNewestFirst returns entries newest first', () async {
      final t1 = DateTime(2026, 1, 1, 10, 0, 0);
      final t2 = DateTime(2026, 1, 1, 11, 0, 0);
      final t3 = DateTime(2026, 1, 1, 12, 0, 0);

      await repo.append(makeEntry(timestamp: t1, message: 'oldest'));
      await repo.append(makeEntry(timestamp: t3, message: 'newest'));
      await repo.append(makeEntry(timestamp: t2, message: 'middle'));

      final rows = await repo.readAllNewestFirst();
      expect(rows, hasLength(3));
      expect(rows[0].message, 'newest');
      expect(rows[1].message, 'middle');
      expect(rows[2].message, 'oldest');
    });

    test(
      'insert 150 entries → readAllNewestFirst returns exactly 100, oldest 50 evicted',
      () async {
        final base = DateTime(2026, 1, 1);
        for (int i = 0; i < 150; i++) {
          await repo.append(
            makeEntry(
              timestamp: base.add(Duration(seconds: i)),
              message: 'entry $i',
            ),
          );
        }

        final rows = await repo.readAllNewestFirst();
        expect(rows, hasLength(100));
        // Most recent entries (i=149 down to i=50) survive; i=0..49 evicted
        expect(rows.first.message, 'entry 149');
        expect(rows.last.message, 'entry 50');
      },
    );

    test('tiebreak by id DESC for identical timestamps', () async {
      final sameTime = DateTime(2026, 1, 1, 10, 0, 0);
      await repo.append(
        makeEntry(timestamp: sameTime, message: 'first insert'),
      );
      await repo.append(
        makeEntry(timestamp: sameTime, message: 'second insert'),
      );

      final rows = await repo.readAllNewestFirst();
      expect(rows, hasLength(2));
      // Higher ID (later insert) should appear first
      expect(rows[0].message, 'second insert');
      expect(rows[1].message, 'first insert');
    });

    test('clearAll empties the table', () async {
      await repo.append(makeEntry(message: 'a'));
      await repo.append(makeEntry(message: 'b'));
      await repo.clearAll();
      final rows = await repo.readAllNewestFirst();
      expect(rows, isEmpty);
    });

    test('ring buffer eviction is atomic under concurrent appends', () async {
      final base = DateTime(2026, 1, 1);
      // Fire 110 concurrent appends, each with a distinct timestamp. All must
      // complete (no silent failures under contention), and the final state
      // must be exactly 100 rows containing entries 10..109 (oldest 10 evicted).
      await Future.wait([
        for (int i = 0; i < 110; i++)
          repo.append(
            makeEntry(
              timestamp: base.add(Duration(seconds: i)),
              message: 'entry $i',
            ),
          ),
      ]);

      final rows = await repo.readAllNewestFirst();
      expect(rows, hasLength(100));
      final messages = rows.map((r) => r.message).toSet();
      for (int i = 10; i < 110; i++) {
        expect(messages, contains('entry $i'));
      }
      for (int i = 0; i < 10; i++) {
        expect(messages, isNot(contains('entry $i')));
      }
    });

    test('append round-trips nullable stackTrace', () async {
      await repo.append(makeEntry(stackTrace: null));
      final rows = await repo.readAllNewestFirst();
      expect(rows.first.stackTrace, isNull);
    });

    test('append round-trips non-null stackTrace', () async {
      await repo.append(makeEntry(stackTrace: '#0 main'));
      final rows = await repo.readAllNewestFirst();
      expect(rows.first.stackTrace, '#0 main');
    });

    test('append round-trips all CrashLogLevel values', () async {
      for (final level in CrashLogLevel.values) {
        await repo.append(makeEntry(level: level, message: level.name));
      }
      final rows = await repo.readAllNewestFirst();
      final levels = rows.map((r) => r.level).toSet();
      expect(levels, containsAll(CrashLogLevel.values));
    });
  });
}
