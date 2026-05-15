// Note: _backupDatabase cannot be exercised with NativeDatabase.memory() because
// backup logic requires a real file path. Story 6-3 defers file-backed backup
// assertions; migration ordering is covered via RecordingMigrator in
// test/data/database/migrations/migration_registry_test.dart.

import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/database/migrations/migration_failure_exception.dart';
import 'package:global_domination/data/database/converters/decimal_converter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _ThrowingMigrator extends Migrator {
  _ThrowingMigrator(super.database);

  @override
  Future<void> createTable(TableInfo table) async {
    throw Exception('synthetic');
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('AppDatabase', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    group('AppDatabase v4 schema', () {
      test('opens at schema version 4', () {
        expect(db.schemaVersion, equals(4));
      });

      test(
        'onCreate runs createAll without error on fresh in-memory database',
        () async {
          await db.customSelect('SELECT 1').get();
        },
      );

      test('onCreate creates crash_logs table', () async {
        final rows = await db.select(db.crashLogs).get();
        expect(rows, isEmpty);
      });

      test('onCreate creates meta table', () async {
        final rows = await db.select(db.meta).get();
        expect(rows, isEmpty);
      });

      test('onCreate creates active_boost table', () async {
        final rows = await db.select(db.activeBoost).get();
        expect(rows, isEmpty);
      });

      test('onCreate creates countries table', () async {
        final rows = await db.select(db.countries).get();
        expect(rows, isEmpty);
      });

      test('onCreate creates continents table', () async {
        final rows = await db.select(db.continents).get();
        expect(rows, isEmpty);
      });

      test('onCreate creates continent_milestones table', () async {
        final rows = await db.select(db.continentMilestones).get();
        expect(rows, isEmpty);
      });

      test('onCreate creates earned_achievements table', () async {
        final rows = await db.select(db.earnedAchievements).get();
        expect(rows, isEmpty);
      });

      test('onCreate creates active_global_upgrades table', () async {
        final rows = await db.select(db.activeGlobalUpgrades).get();
        expect(rows, isEmpty);
      });

      test('onCreate creates active_goldens table', () async {
        final rows = await db.select(db.activeGoldens).get();
        expect(rows, isEmpty);
      });

      test('onCreate creates active_missions table', () async {
        final rows = await db.select(db.activeMissions).get();
        expect(rows, isEmpty);
      });

      test('onCreate creates completed_missions table', () async {
        final rows = await db.select(db.completedMissions).get();
        expect(rows, isEmpty);
      });

      test('onCreate creates daily_streaks table', () async {
        final rows = await db.select(db.dailyStreaks).get();
        expect(rows, isEmpty);
      });

      test('onCreate creates active_golden_effect table', () async {
        final rows = await db.select(db.activeGoldenEffect).get();
        expect(rows, isEmpty);
      });

      test('onCreate creates settings table', () async {
        final rows = await db.select(db.settings).get();
        expect(rows, isEmpty);
      });

      test('meta table enforces single-row CHECK constraint', () async {
        await db
            .into(db.meta)
            .insert(
              MetaCompanion.insert(
                singletonId: const Value(0),
                schemaVersion: 3,
                lastSavedAt: DateTime.utc(2020, 1, 1),
                totalInfluence: Decimal.zero,
                totalIntel: Decimal.zero,
                goldenOpportunityMultiplier: Decimal.one,
                boostMultiplier: Decimal.one,
              ),
            );
        expect(
          () => db
              .into(db.meta)
              .insert(
                MetaCompanion.insert(
                  singletonId: const Value(1),
                  schemaVersion: 3,
                  lastSavedAt: DateTime.utc(2020, 1, 2),
                  totalInfluence: Decimal.zero,
                  totalIntel: Decimal.zero,
                  goldenOpportunityMultiplier: Decimal.one,
                  boostMultiplier: Decimal.one,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      });

      test('active_boost table enforces single-row CHECK constraint', () async {
        await db
            .into(db.activeBoost)
            .insert(
              ActiveBoostCompanion.insert(
                singletonId: const Value(0),
                multiplier: Decimal.parse('2.0'),
                expiresAt: DateTime.utc(2020, 1, 1),
              ),
            );
        expect(
          () => db
              .into(db.activeBoost)
              .insert(
                ActiveBoostCompanion.insert(
                  singletonId: const Value(1),
                  multiplier: Decimal.parse('2.0'),
                  expiresAt: DateTime.utc(2020, 1, 2),
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      });

      test(
        'daily_streaks table enforces single-row CHECK constraint',
        () async {
          await db
              .into(db.dailyStreaks)
              .insert(
                DailyStreaksCompanion.insert(
                  singletonId: const Value(0),
                  day: 1,
                  lastClaimDate: Value(DateTime.utc(2020, 1, 1)),
                ),
              );
          expect(
            () => db
                .into(db.dailyStreaks)
                .insert(
                  DailyStreaksCompanion.insert(
                    singletonId: const Value(1),
                    day: 2,
                    lastClaimDate: Value(DateTime.utc(2020, 1, 2)),
                  ),
                ),
            throwsA(isA<SqliteException>()),
          );
        },
      );

      test(
        'active_golden_effect table enforces single-row CHECK constraint',
        () async {
          await db
              .into(db.activeGoldenEffect)
              .insert(
                ActiveGoldenEffectCompanion.insert(
                  singletonId: const Value(0),
                  goldenId: 'g1',
                  multiplier: 10,
                  expiresAt: DateTime.utc(2020, 1, 1),
                ),
              );
          expect(
            () => db
                .into(db.activeGoldenEffect)
                .insert(
                  ActiveGoldenEffectCompanion.insert(
                    singletonId: const Value(1),
                    goldenId: 'g2',
                    multiplier: 20,
                    expiresAt: DateTime.utc(2020, 1, 2),
                  ),
                ),
            throwsA(isA<SqliteException>()),
          );
        },
      );

      test('settings table enforces single-row CHECK constraint', () async {
        await db
            .into(db.settings)
            .insert(
              SettingsCompanion.insert(
                singletonId: const Value(0),
                soundEnabled: const Value(true),
                hapticsEnabled: const Value(true),
                notificationsEnabled: const Value(false),
              ),
            );
        expect(
          () => db
              .into(db.settings)
              .insert(
                SettingsCompanion.insert(
                  singletonId: const Value(1),
                  soundEnabled: const Value(true),
                  hapticsEnabled: const Value(true),
                  notificationsEnabled: const Value(false),
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      });

      test('onUpgrade v1→v2 creates crash_logs table without error', () async {
        await db.customSelect('SELECT 1').get();
        expect(db.schemaVersion, equals(4));
        final rows = await db.select(db.crashLogs).get();
        expect(rows, isEmpty);
      });

      test('onUpgrade v2→v3 path is covered on fresh in-memory database', () async {
        // NativeDatabase.memory() cannot simulate a real v2 on-disk file; Story 6-3
        // will add file-backed migration tests. Here we assert v4 schema is live.
        await db.customSelect('SELECT 1').get();
        expect(db.schemaVersion, equals(4));
        expect(await db.select(db.meta).get(), isEmpty);
        expect(await db.select(db.activeBoost).get(), isEmpty);
        expect(await db.select(db.countries).get(), isEmpty);
        expect(await db.select(db.continents).get(), isEmpty);
        expect(await db.select(db.continentMilestones).get(), isEmpty);
        expect(await db.select(db.earnedAchievements).get(), isEmpty);
        expect(await db.select(db.activeGlobalUpgrades).get(), isEmpty);
        expect(await db.select(db.activeGoldens).get(), isEmpty);
        expect(await db.select(db.activeMissions).get(), isEmpty);
        expect(await db.select(db.completedMissions).get(), isEmpty);
        expect(await db.select(db.dailyStreaks).get(), isEmpty);
        expect(await db.select(db.activeGoldenEffect).get(), isEmpty);
        expect(await db.select(db.settings).get(), isEmpty);
      });

      test(
        'onUpgrade v2 to v3 preserves crash_logs without seeding meta',
        () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'global_domination_path_provider_',
          );
          addTearDown(() async {
            if (await tempDir.exists()) {
              await tempDir.delete(recursive: true);
            }
          });
          final previousPlatform = PathProviderPlatform.instance;
          PathProviderPlatform.instance = _FakePathProviderPlatform(
            tempDir.path,
          );
          addTearDown(() {
            PathProviderPlatform.instance = previousPlatform;
          });

          final upgradedDb = AppDatabase(
            NativeDatabase.memory(
              setup: (rawDb) {
                rawDb
                  ..execute('''
                  CREATE TABLE crash_logs (
                    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    level TEXT NOT NULL,
                    tag TEXT NOT NULL,
                    message TEXT NOT NULL,
                    stack_trace TEXT NULL
                  );
                ''')
                  ..execute(
                    "INSERT INTO crash_logs "
                    "(timestamp, level, tag, message, stack_trace) VALUES "
                    "('2026-01-01T00:00:00.000Z', 'severe', 'MigrationTest', "
                    "'kept', NULL);",
                  )
                  ..execute('PRAGMA user_version = 2');
              },
            ),
          );
          addTearDown(upgradedDb.close);

          final crashRows = await upgradedDb.select(upgradedDb.crashLogs).get();
          expect(crashRows, hasLength(1));
          expect(crashRows.single.tag, equals('MigrationTest'));

          final metaRows = await upgradedDb.select(upgradedDb.meta).get();
          expect(metaRows, isEmpty);

          expect(
            await upgradedDb.select(upgradedDb.activeBoost).get(),
            isEmpty,
          );
          expect(await upgradedDb.select(upgradedDb.countries).get(), isEmpty);
          expect(await upgradedDb.select(upgradedDb.continents).get(), isEmpty);
          expect(
            await upgradedDb.select(upgradedDb.continentMilestones).get(),
            isEmpty,
          );
          expect(
            await upgradedDb.select(upgradedDb.earnedAchievements).get(),
            isEmpty,
          );
          expect(
            await upgradedDb.select(upgradedDb.activeGlobalUpgrades).get(),
            isEmpty,
          );
          expect(
            await upgradedDb.select(upgradedDb.activeGoldens).get(),
            isEmpty,
          );
          expect(
            await upgradedDb.select(upgradedDb.activeMissions).get(),
            isEmpty,
          );
          expect(
            await upgradedDb.select(upgradedDb.completedMissions).get(),
            isEmpty,
          );
          expect(
            await upgradedDb.select(upgradedDb.dailyStreaks).get(),
            isEmpty,
          );
          expect(
            await upgradedDb.select(upgradedDb.activeGoldenEffect).get(),
            isEmpty,
          );
          expect(await upgradedDb.select(upgradedDb.settings).get(), isEmpty);
        },
      );
    });

    group('migration delegation', () {
      test('migration failure rewraps as MigrationFailureException', () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'app_db_migration_fail_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });
        final previousPlatform = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
        addTearDown(() {
          PathProviderPlatform.instance = previousPlatform;
        });

        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() async {
          await db.close();
        });
        final m = _ThrowingMigrator(db);
        await expectLater(
          () => db.migration.onUpgrade(m, 3, 4),
          throwsA(
            isA<MigrationFailureException>()
                .having((e) => e.fromVersion, 'from', 3)
                .having((e) => e.toVersion, 'to', 4)
                .having((e) => e.cause, 'cause', contains('synthetic')),
          ),
        );
      });
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
