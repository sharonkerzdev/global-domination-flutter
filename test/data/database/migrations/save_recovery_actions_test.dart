import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}
