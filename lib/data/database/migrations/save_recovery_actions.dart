import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SchemaBackup {
  const SchemaBackup({
    required this.version,
    required this.file,
    required this.modifiedAt,
  });

  final int version;
  final File file;
  final DateTime modifiedAt;
}

class SaveRecoveryActions {
  SaveRecoveryActions._();

  static const _dbFileName = 'global_domination.sqlite';
  static final _schemaBackupRe = RegExp(r'^schema_backup_v(\d+)\.sqlite$');

  static int _utcMillis([DateTime Function()? now]) {
    final n = now?.call() ?? DateTime.now();
    return n.toUtc().millisecondsSinceEpoch;
  }

  static Future<Directory> _docs() => getApplicationDocumentsDirectory();

  static Future<bool> backupExists(int fromVersion) async {
    final dir = await _docs();
    final backup = File(p.join(dir.path, 'schema_backup_v$fromVersion.sqlite'));
    return backup.existsSync();
  }

  /// All `schema_backup_v{n}.sqlite` files in the app documents directory, sorted
  /// for diagnostics (newest mtime first, then higher version on tie).
  static Future<List<SchemaBackup>> discoverBackups() async {
    final dir = await _docs();
    final all = <SchemaBackup>[];
    for (final e in dir.listSync(followLinks: false)) {
      if (e is! File) continue;
      final name = p.basename(e.path);
      final m = _schemaBackupRe.firstMatch(name);
      if (m == null) continue;
      final v = int.parse(m.group(1)!);
      all.add(
        SchemaBackup(version: v, file: e, modifiedAt: e.lastModifiedSync()),
      );
    }
    all.sort((a, b) {
      final c = b.modifiedAt.compareTo(a.modifiedAt);
      if (c != 0) return c;
      return b.version.compareTo(a.version);
    });
    return all;
  }

  /// Picks the most recently modified `schema_backup_v{n}.sqlite` in the
  /// app documents directory. On mtime tie, the higher [n] wins.
  static Future<SchemaBackup?> latestBackup({DateTime Function()? now}) async {
    final dir = await _docs();
    SchemaBackup? best;
    for (final e in dir.listSync(followLinks: false)) {
      if (e is! File) continue;
      final name = p.basename(e.path);
      final m = _schemaBackupRe.firstMatch(name);
      if (m == null) continue;
      final v = int.parse(m.group(1)!);
      final mod = e.lastModifiedSync();
      if (best == null) {
        best = SchemaBackup(version: v, file: e, modifiedAt: mod);
        continue;
      }
      if (mod.isAfter(best.modifiedAt)) {
        best = SchemaBackup(version: v, file: e, modifiedAt: mod);
      } else if (mod == best.modifiedAt && v > best.version) {
        best = SchemaBackup(version: v, file: e, modifiedAt: mod);
      }
    }
    return best;
  }

  static Future<void> restoreFromBackup({
    required int fromVersion,
    required int toVersion,
    DateTime Function()? now,
  }) async {
    final dir = await _docs();
    final live = File(p.join(dir.path, _dbFileName));
    final backup = File(p.join(dir.path, 'schema_backup_v$fromVersion.sqlite'));
    if (!await backup.exists()) {
      throw StateError('Backup schema_backup_v$fromVersion.sqlite not found');
    }
    final ts = _utcMillis(now);
    await _quarantineCorruptLive(
      directory: dir,
      currentSchemaVersion: toVersion,
      timestampMillis: ts,
    );
    await backup.copy(live.path);
  }

  static Future<void> restoreLatestBackup({
    required int currentSchemaVersion,
    DateTime Function()? now,
  }) async {
    final pick = await latestBackup(now: now);
    if (pick == null) {
      throw StateError('No schema_backup_v*.sqlite found');
    }
    final dir = await _docs();
    if (!await pick.file.exists()) {
      throw StateError('Selected backup no longer exists');
    }
    final ts = _utcMillis(now);
    await _quarantineCorruptLive(
      directory: dir,
      currentSchemaVersion: currentSchemaVersion,
      timestampMillis: ts,
    );
    await pick.file.copy(p.join(dir.path, _dbFileName));
  }

  static Future<void> startFresh({
    required int currentSchemaVersion,
    DateTime Function()? now,
  }) async {
    final dir = await _docs();
    final ts = _utcMillis(now);
    await _quarantineCorruptLive(
      directory: dir,
      currentSchemaVersion: currentSchemaVersion,
      timestampMillis: ts,
    );
  }

  static Future<void> _quarantineCorruptLive({
    required Directory directory,
    required int currentSchemaVersion,
    required int timestampMillis,
  }) async {
    final basePath = p.join(directory.path, _dbFileName);
    final main = File(basePath);
    final wal = File('$basePath-wal');
    final shm = File('$basePath-shm');
    final targetMain = p.join(
      directory.path,
      'app_v${currentSchemaVersion}_corrupt_$timestampMillis.sqlite',
    );
    if (await main.exists()) {
      await main.rename(targetMain);
    }
    if (await wal.exists()) {
      await wal.rename('$targetMain-wal');
    }
    if (await shm.exists()) {
      await shm.rename('$targetMain-shm');
    }
  }
}
