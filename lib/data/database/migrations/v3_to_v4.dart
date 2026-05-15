import 'package:drift/drift.dart';

import '../app_database.dart';
import 'migration_step.dart';

class V3ToV4 extends MigrationStep {
  const V3ToV4();

  @override
  int get fromVersion => 3;

  @override
  int get toVersion => 4;

  @override
  Future<void> migrate(Migrator m, AppDatabase db) async {
    await m.createTable(db.settings);
  }
}
