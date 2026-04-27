import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/database/migrations/migration_registry.dart';
import 'package:global_domination/data/database/migrations/v1_to_v2.dart';
import 'package:global_domination/data/database/migrations/v2_to_v3.dart';

class _RecordingMigrator extends Migrator {
  _RecordingMigrator(super.database);

  final List<String> tablesCreated = [];

  @override
  Future<void> createTable(TableInfo table) async {
    tablesCreated.add(table.actualTableName);
  }
}

void main() {
  group('MigrationStep versions', () {
    test('V1ToV2 has fromVersion=1, toVersion=2', () {
      const step = V1ToV2();
      expect(step.fromVersion, 1);
      expect(step.toVersion, 2);
    });

    test('V2ToV3 has fromVersion=2, toVersion=3', () {
      const step = V2ToV3();
      expect(step.fromVersion, 2);
      expect(step.toVersion, 3);
    });
  });

  group('MigrationRegistry.run', () {
    test('executes steps in order for v1→v3', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
      });
      final m = _RecordingMigrator(db);
      await MigrationRegistry.run(m, db, from: 1, to: 3);
      expect(m.tablesCreated, [
        'crash_logs',
        'meta',
        'active_boost',
        'active_global_upgrades',
        'active_golden_effect',
        'active_goldens',
        'active_missions',
        'completed_missions',
        'countries',
        'continents',
        'continent_milestones',
        'daily_streaks',
        'earned_achievements',
      ]);
    });

    test('is no-op for from==to', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
      });
      final m = _RecordingMigrator(db);
      await MigrationRegistry.run(m, db, from: 3, to: 3);
      expect(m.tablesCreated, isEmpty);
    });

    test('throws StateError on missing step', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
      });
      final m = _RecordingMigrator(db);
      expect(
        () => MigrationRegistry.run(m, db, from: 4, to: 5),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'toString',
            contains('Missing migration step from v4 to v5'),
          ),
        ),
      );
    });
  });
}
