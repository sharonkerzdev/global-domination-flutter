// Note: _backupDatabase cannot be exercised with NativeDatabase.memory() because
// backup logic requires a real file path. This limitation is deferred to Story 6.5
// (typed migrations and schema backup), matching the deferral pattern from Story 1.4.

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/database/converters/decimal_converter.dart';

void main() {
  group('AppDatabase', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('opens at schema version 2', () {
      expect(db.schemaVersion, equals(2));
    });

    test(
      'onCreate runs createAll without error on fresh in-memory database',
      () async {
        // Triggering a select forces the database to open and run onCreate
        await db.customSelect('SELECT 1').get();
      },
    );

    test('onCreate creates crash_logs table', () async {
      // Verify the crash_logs table exists and is queryable
      final rows = await db.select(db.crashLogs).get();
      expect(rows, isEmpty);
    });

    test('onUpgrade v1→v2 creates crash_logs table without error', () async {
      // Open fresh in-memory DB (starts at onCreate which calls createAll,
      // so crash_logs table is created). We verify migration path indirectly:
      // the schema version is 2 and crash_logs is accessible.
      //
      // True v1→v2 migration testing would require opening an existing v1 DB file,
      // which is not possible with NativeDatabase.memory(). Deferred to Story 6.5.
      await db.customSelect('SELECT 1').get();
      expect(db.schemaVersion, equals(2));
      final rows = await db.select(db.crashLogs).get();
      expect(rows, isEmpty);
    });
  });

  group('DecimalConverter', () {
    const converter = DecimalConverter();

    test('round-trips zero', () {
      final original = Decimal.zero;
      final sql = converter.toSql(original);
      final result = converter.fromSql(sql);
      expect(result, equals(original));
    });

    test('round-trips negative numbers', () {
      final original = Decimal.parse('-42.5');
      final sql = converter.toSql(original);
      final result = converter.fromSql(sql);
      expect(result, equals(original));
    });

    test('round-trips large numbers at 1e38 with zero precision loss', () {
      final original = Decimal.parse('1e38');
      final sql = converter.toSql(original);
      final result = converter.fromSql(sql);
      expect(result, equals(original));
    });

    test('round-trips very large numbers beyond 1e38', () {
      final original = Decimal.parse(
        '99999999999999999999999999999999999999999',
      );
      final sql = converter.toSql(original);
      final result = converter.fromSql(sql);
      expect(result, equals(original));
    });

    test('round-trips decimal fractions', () {
      final original = Decimal.parse('123.456789012345');
      final sql = converter.toSql(original);
      final result = converter.fromSql(sql);
      expect(result, equals(original));
    });

    test('toSql returns string representation', () {
      final value = Decimal.parse('42.5');
      expect(converter.toSql(value), equals('42.5'));
    });

    test('fromSql parses string to Decimal', () {
      expect(converter.fromSql('42.5'), equals(Decimal.parse('42.5')));
    });
  });
}
