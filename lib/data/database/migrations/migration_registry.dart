import 'package:drift/drift.dart';

import '../app_database.dart';
import 'migration_step.dart';
import 'v1_to_v2.dart';
import 'v2_to_v3.dart';
import 'v3_to_v4.dart';

class MigrationRegistry {
  MigrationRegistry._();

  static const List<MigrationStep> _steps = [V1ToV2(), V2ToV3(), V3ToV4()];

  static Future<void> run(
    Migrator m,
    AppDatabase db, {
    required int from,
    required int to,
  }) async {
    var cursor = from;
    while (cursor < to) {
      final step = _steps.firstWhere(
        (s) => s.fromVersion == cursor,
        orElse: () => throw StateError(
          'Missing migration step from v$cursor to v${cursor + 1}',
        ),
      );
      await step.migrate(m, db);
      cursor = step.toVersion;
    }
  }
}
