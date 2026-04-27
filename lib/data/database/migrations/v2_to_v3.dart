import 'package:drift/drift.dart';

import '../app_database.dart';
import 'migration_step.dart';

class V2ToV3 extends MigrationStep {
  const V2ToV3();

  @override
  int get fromVersion => 2;

  @override
  int get toVersion => 3;

  @override
  Future<void> migrate(Migrator m, AppDatabase db) async {
    await m.createTable(db.meta);
    await m.createTable(db.activeBoost);
    await m.createTable(db.activeGlobalUpgrades);
    await m.createTable(db.activeGoldenEffect);
    await m.createTable(db.activeGoldens);
    await m.createTable(db.activeMissions);
    await m.createTable(db.completedMissions);
    await m.createTable(db.countries);
    await m.createTable(db.continents);
    await m.createTable(db.continentMilestones);
    await m.createTable(db.dailyStreaks);
    await m.createTable(db.earnedAchievements);
    // Meta singleton row is intentionally NOT seeded — SaveRepository inserts
    // on first persist (Story 6-1 Task 3.4 / Story 6-2).
  }
}
