import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SaveRecoveryActions {
  SaveRecoveryActions._();

  static const _dbFileName = 'global_domination.sqlite';

  static Future<bool> backupExists(int fromVersion) async {
    final dir = await getApplicationDocumentsDirectory();
    final backup = File(p.join(dir.path, 'schema_backup_v$fromVersion.sqlite'));
    return backup.existsSync();
  }

  static Future<void> restoreFromBackup({
    required int fromVersion,
    required int toVersion,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final live = File(p.join(dir.path, _dbFileName));
    final backup = File(p.join(dir.path, 'schema_backup_v$fromVersion.sqlite'));
    if (!await backup.exists()) {
      throw StateError('Backup schema_backup_v$fromVersion.sqlite not found');
    }
    if (await live.exists()) {
      final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
      await live.rename(
        p.join(dir.path, 'app_v${toVersion}_corrupt_$ts.sqlite'),
      );
    }
    await backup.copy(live.path);
  }
}
