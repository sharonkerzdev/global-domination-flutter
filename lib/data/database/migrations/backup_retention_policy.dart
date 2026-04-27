import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

class BackupRetentionPolicy {
  BackupRetentionPolicy._();

  static final _log = Logger('BackupRetentionPolicy');
  static final _backupPattern = RegExp(r'^schema_backup_v\d+\.sqlite$');

  static Future<void> prune(Directory dir, {int retainMostRecent = 3}) async {
    if (!await dir.exists()) return;
    try {
      final entries = await dir.list().toList();
      final backups = entries
          .whereType<File>()
          .where((f) => _backupPattern.hasMatch(p.basename(f.path)))
          .toList();
      backups.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
      final toDelete = backups.skip(retainMostRecent).toList();
      for (final f in toDelete) {
        await f.delete();
        _log.fine('pruned ${f.path}');
      }
    } catch (e, s) {
      _log.warning('prune failed', e, s);
    }
  }
}
