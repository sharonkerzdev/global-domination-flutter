import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/database/migrations/save_recovery_actions.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  late Directory tempDir;
  late PathProviderPlatform previous;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('save_recovery_actions_');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() {
    PathProviderPlatform.instance = previous;
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('backupExists returns true when file present', () async {
    await File('${tempDir.path}/schema_backup_v2.sqlite').writeAsString('x');
    expect(await SaveRecoveryActions.backupExists(2), isTrue);
  });

  test('backupExists returns false when file missing', () async {
    expect(await SaveRecoveryActions.backupExists(2), isFalse);
  });

  test('restoreFromBackup renames live db and copies backup', () async {
    await File(
      '${tempDir.path}/global_domination.sqlite',
    ).writeAsString('live');
    await File(
      '${tempDir.path}/schema_backup_v2.sqlite',
    ).writeAsString('backup-body');
    await SaveRecoveryActions.restoreFromBackup(fromVersion: 2, toVersion: 3);
    final live = File('${tempDir.path}/global_domination.sqlite');
    expect(await live.readAsString(), 'backup-body');
    final corrupt = tempDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('app_v3_corrupt_'))
        .single;
    expect(await corrupt.readAsString(), 'live');
    expect(
      File('${tempDir.path}/schema_backup_v2.sqlite').existsSync(),
      isTrue,
    );
  });

  test('restoreFromBackup quarantines WAL and SHM sidecars', () async {
    await File(
      '${tempDir.path}/global_domination.sqlite',
    ).writeAsString('live');
    await File(
      '${tempDir.path}/global_domination.sqlite-wal',
    ).writeAsString('wal');
    await File(
      '${tempDir.path}/global_domination.sqlite-shm',
    ).writeAsString('shm');
    await File(
      '${tempDir.path}/schema_backup_v2.sqlite',
    ).writeAsString('backup-body');
    await SaveRecoveryActions.restoreFromBackup(fromVersion: 2, toVersion: 3);
    expect(
      File('${tempDir.path}/global_domination.sqlite-wal').existsSync(),
      isFalse,
    );
    expect(
      File('${tempDir.path}/global_domination.sqlite-shm').existsSync(),
      isFalse,
    );
    final names = tempDir
        .listSync()
        .whereType<File>()
        .map((f) => f.path.split(Platform.pathSeparator).last)
        .toList();
    expect(
      names.any(
        (n) => n.startsWith('app_v3_corrupt_') && n.endsWith('.sqlite'),
      ),
      isTrue,
    );
    expect(
      names.any((n) => n.contains('corrupt') && n.endsWith('.sqlite-wal')),
      isTrue,
    );
    expect(
      names.any((n) => n.contains('corrupt') && n.endsWith('.sqlite-shm')),
      isTrue,
    );
    expect(
      await File('${tempDir.path}/global_domination.sqlite').readAsString(),
      'backup-body',
    );
  });

  test('restoreFromBackup throws StateError when backup missing', () async {
    expect(
      () =>
          SaveRecoveryActions.restoreFromBackup(fromVersion: 9, toVersion: 10),
      throwsA(isA<StateError>()),
    );
  });

  test('restoreFromBackup when live missing copies backup only', () async {
    await File('${tempDir.path}/schema_backup_v2.sqlite').writeAsString('only');
    await SaveRecoveryActions.restoreFromBackup(fromVersion: 2, toVersion: 3);
    final live = File('${tempDir.path}/global_domination.sqlite');
    expect(await live.readAsString(), 'only');
    final corruptCount = tempDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('corrupt'))
        .length;
    expect(corruptCount, 0);
  });

  test('latestBackup returns null when no backups', () async {
    await File('${tempDir.path}/global_domination.sqlite').writeAsString('x');
    expect(await SaveRecoveryActions.latestBackup(), isNull);
  });

  test('latestBackup ignores non-schema_backup filenames', () async {
    await File('${tempDir.path}/schema_backup_v2.sqlite').writeAsString('ok');
    await File('${tempDir.path}/global_domination.sqlite').writeAsString('x');
    await File('${tempDir.path}/app_v3_corrupt_1.sqlite').writeAsString('q');
    final pick = await SaveRecoveryActions.latestBackup();
    expect(pick?.version, 2);
  });

  test('latestBackup picks newest mtime', () async {
    final older = DateTime.utc(2020, 1, 1);
    final newer = DateTime.utc(2024, 6, 1);
    await File('${tempDir.path}/schema_backup_v2.sqlite').writeAsString('a');
    File('${tempDir.path}/schema_backup_v2.sqlite').setLastModifiedSync(older);
    await File('${tempDir.path}/schema_backup_v9.sqlite').writeAsString('b');
    File('${tempDir.path}/schema_backup_v9.sqlite').setLastModifiedSync(newer);
    final pick = await SaveRecoveryActions.latestBackup();
    expect(pick?.version, 9);
  });

  test('latestBackup tie-break uses higher version', () async {
    final same = DateTime.utc(2023, 5, 5);
    await File('${tempDir.path}/schema_backup_v2.sqlite').writeAsString('a');
    File('${tempDir.path}/schema_backup_v2.sqlite').setLastModifiedSync(same);
    await File('${tempDir.path}/schema_backup_v5.sqlite').writeAsString('b');
    File('${tempDir.path}/schema_backup_v5.sqlite').setLastModifiedSync(same);
    final pick = await SaveRecoveryActions.latestBackup();
    expect(pick?.version, 5);
  });

  test('restoreLatestBackup quarantines and copies backup', () async {
    await File('${tempDir.path}/global_domination.sqlite').writeAsString('bad');
    await File('${tempDir.path}/schema_backup_v3.sqlite').writeAsString('good');
    await SaveRecoveryActions.restoreLatestBackup(
      currentSchemaVersion: AppDatabase.currentSchemaVersion,
    );
    expect(
      await File('${tempDir.path}/global_domination.sqlite').readAsString(),
      'good',
    );
    expect(
      File('${tempDir.path}/schema_backup_v3.sqlite').existsSync(),
      isTrue,
    );
    expect(
      tempDir.listSync().whereType<File>().any(
        (f) => f.path.contains('corrupt'),
      ),
      isTrue,
    );
  });

  test(
    'startFresh quarantines live db and sidecars without deleting backups',
    () async {
      await File(
        '${tempDir.path}/global_domination.sqlite',
      ).writeAsString('bad');
      await File(
        '${tempDir.path}/global_domination.sqlite-wal',
      ).writeAsString('w');
      await File(
        '${tempDir.path}/schema_backup_v2.sqlite',
      ).writeAsString('keep');
      await SaveRecoveryActions.startFresh(
        currentSchemaVersion: AppDatabase.currentSchemaVersion,
        now: () => DateTime.utc(2030, 1, 1),
      );
      expect(
        File('${tempDir.path}/global_domination.sqlite').existsSync(),
        isFalse,
      );
      expect(
        File('${tempDir.path}/schema_backup_v2.sqlite').existsSync(),
        isTrue,
      );
      expect(
        tempDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.contains('corrupt'))
            .length,
        greaterThanOrEqualTo(1),
      );
    },
  );

  test('startFresh when live db missing succeeds', () async {
    await SaveRecoveryActions.startFresh(
      currentSchemaVersion: AppDatabase.currentSchemaVersion,
    );
    expect(
      File('${tempDir.path}/global_domination.sqlite').existsSync(),
      isFalse,
    );
  });

  test(
    'restoreLatestBackup uses injectable clock for quarantine stem',
    () async {
      await File('${tempDir.path}/global_domination.sqlite').writeAsString('x');
      await File('${tempDir.path}/schema_backup_v2.sqlite').writeAsString('y');
      final t = DateTime.utc(2040, 2, 2, 12);
      await SaveRecoveryActions.restoreLatestBackup(
        currentSchemaVersion: 3,
        now: () => t,
      );
      final epoch = t.toUtc().millisecondsSinceEpoch;
      expect(
        File('${tempDir.path}/app_v3_corrupt_$epoch.sqlite').existsSync(),
        isTrue,
      );
    },
  );
}
