import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../app_database.dart';

@immutable
abstract class MigrationStep {
  const MigrationStep();

  int get fromVersion;
  int get toVersion;

  Future<void> migrate(Migrator m, AppDatabase db);
}
