import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/data/database/migrations/backup_retention_policy.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('backup_retention_test_');
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  test('retains 3 most recent of 5 backups by mtime', () async {
    final t0 = DateTime.utc(2020, 1, 1);
    for (var i = 1; i <= 5; i++) {
      final f = File('${dir.path}/schema_backup_v$i.sqlite');
      await f.writeAsString('v$i');
      f.setLastModifiedSync(t0.add(Duration(seconds: i)));
    }
    await BackupRetentionPolicy.prune(dir, retainMostRecent: 3);
    final names = dir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toSet();
    expect(names.contains('schema_backup_v1.sqlite'), isFalse);
    expect(names.contains('schema_backup_v2.sqlite'), isFalse);
    expect(names.contains('schema_backup_v3.sqlite'), isTrue);
    expect(names.contains('schema_backup_v4.sqlite'), isTrue);
    expect(names.contains('schema_backup_v5.sqlite'), isTrue);
  });

  test('ignores non-matching files', () async {
    await File('${dir.path}/global_domination.sqlite').writeAsString('x');
    await File('${dir.path}/app_v2_corrupt_1234.sqlite').writeAsString('y');
    final backup = File('${dir.path}/schema_backup_v1.sqlite');
    await backup.writeAsString('b');
    backup.setLastModifiedSync(DateTime.utc(2025, 1, 1));
    await BackupRetentionPolicy.prune(dir, retainMostRecent: 3);
    expect(File('${dir.path}/global_domination.sqlite').existsSync(), isTrue);
    expect(File('${dir.path}/app_v2_corrupt_1234.sqlite').existsSync(), isTrue);
    expect(backup.existsSync(), isTrue);
  });

  test('is no-op on empty directory', () async {
    await expectLater(BackupRetentionPolicy.prune(dir), completes);
  });

  test('is no-op on non-existent directory', () async {
    final missing = Directory('${dir.path}/gone');
    dir.deleteSync(recursive: true);
    await expectLater(BackupRetentionPolicy.prune(missing), completes);
  });

  test('with retainMostRecent=0 deletes all matching', () async {
    for (var i = 1; i <= 3; i++) {
      await File('${dir.path}/schema_backup_v$i.sqlite').writeAsString('$i');
    }
    await BackupRetentionPolicy.prune(dir, retainMostRecent: 0);
    final backups = dir.listSync().whereType<File>().where(
      (f) => f.path.contains('schema_backup_v'),
    );
    expect(backups, isEmpty);
  });

  test(
    'sort is stable across equal mtimes — one survivor after prune 1',
    () async {
      final same = DateTime.utc(2024, 6, 1);
      final a = File('${dir.path}/schema_backup_v1.sqlite');
      final b = File('${dir.path}/schema_backup_v2.sqlite');
      await a.writeAsString('a');
      await b.writeAsString('b');
      a.setLastModifiedSync(same);
      b.setLastModifiedSync(same);
      await BackupRetentionPolicy.prune(dir, retainMostRecent: 1);
      final remaining = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('schema_backup_v'))
          .length;
      expect(remaining, 1);
    },
  );
}
