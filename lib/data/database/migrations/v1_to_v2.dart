import 'package:drift/drift.dart';

import '../app_database.dart';
import 'migration_step.dart';

class V1ToV2 extends MigrationStep {
  const V1ToV2();

  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 2;

  @override
  Future<void> migrate(Migrator m, AppDatabase db) async {
    await m.createTable(db.crashLogs);
  }
}
