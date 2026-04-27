import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

import '../mappers/game_state_rows.dart';
import '../repositories/crash_log_entry.dart';
import 'converters/crash_log_level_converter.dart';
import 'converters/decimal_converter.dart';
import 'tables/active_boost_table.dart';
import 'tables/active_global_upgrades_table.dart';
import 'tables/active_golden_effect_table.dart';
import 'tables/active_goldens_table.dart';
import 'tables/active_missions_table.dart';
import 'tables/completed_missions_table.dart';
import 'tables/continent_milestones_table.dart';
import 'tables/continents_table.dart';
import 'tables/countries_table.dart';
import 'tables/crash_logs_table.dart';
import 'tables/daily_streaks_table.dart';
import 'tables/earned_achievements_table.dart';
import 'tables/meta_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    ActiveBoost,
    ActiveGlobalUpgrades,
    ActiveGoldenEffect,
    ActiveGoldens,
    ActiveMissions,
    CompletedMissions,
    Continents,
    ContinentMilestones,
    Countries,
    CrashLogs,
    DailyStreaks,
    EarnedAchievements,
    Meta,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        // No meta seed: first launch has no meta row until Story 6-2 persists (mapper → initialSeed).
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        await _backupDatabase(from);
        if (from == 1) {
          await m.createTable(crashLogs);
        }
        if (from <= 2 && to >= 3) {
          await m.createTable(meta);
          await m.createTable(activeBoost);
          await m.createTable(activeGlobalUpgrades);
          await m.createTable(activeGoldenEffect);
          await m.createTable(activeGoldens);
          await m.createTable(activeMissions);
          await m.createTable(completedMissions);
          await m.createTable(countries);
          await m.createTable(continents);
          await m.createTable(continentMilestones);
          await m.createTable(dailyStreaks);
          await m.createTable(earnedAchievements);
          await into(meta).insert(
            MetaCompanion.insert(
              singletonId: const Value(0),
              schemaVersion: 3,
              lastSavedAt: DateTime.now().toUtc(),
              totalInfluence: Decimal.zero,
              totalIntel: Decimal.zero,
              goldenOpportunityMultiplier: Decimal.one,
              boostMultiplier: Decimal.one,
            ),
          );
        }
      },
    );
  }

  Future<GameStateRows> loadAll() async {
    return transaction(() async {
      final metaRow = await (select(meta)..limit(1)).getSingleOrNull();
      final activeBoostRow = await (select(
        activeBoost,
      )..limit(1)).getSingleOrNull();
      final countryRows = await select(countries).get();
      final continentRows = await select(continents).get();
      final milestoneRows = await select(continentMilestones).get();
      final achievementRows = await select(earnedAchievements).get();
      final upgradeRows = await select(activeGlobalUpgrades).get();
      final goldenRows = await select(activeGoldens).get();
      final missionRows = await select(activeMissions).get();
      final completedMissionRows = await select(completedMissions).get();
      final dailyStreakRow = await (select(
        dailyStreaks,
      )..limit(1)).getSingleOrNull();
      final goldenEffectRow = await (select(
        activeGoldenEffect,
      )..limit(1)).getSingleOrNull();
      return GameStateRows(
        meta: metaRow,
        activeBoost: activeBoostRow,
        countries: countryRows,
        continents: continentRows,
        continentMilestones: milestoneRows,
        earnedAchievements: achievementRows,
        activeGlobalUpgrades: upgradeRows,
        activeGoldens: goldenRows,
        activeMissions: missionRows,
        completedMissions: completedMissionRows,
        dailyStreak: dailyStreakRow,
        activeGoldenEffect: goldenEffectRow,
      );
    });
  }

  static Future<void> _backupDatabase(int fromVersion) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dbFolder.path, 'global_domination.sqlite'));
    if (await dbFile.exists()) {
      final backupPath = p.join(
        dbFolder.path,
        'schema_backup_v$fromVersion.sqlite',
      );
      await dbFile.copy(backupPath);
    }
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'global_domination.sqlite'));
      sqlite3.tempDirectory = (await getTemporaryDirectory()).path;
      return NativeDatabase.createInBackground(file);
    });
  }
}
