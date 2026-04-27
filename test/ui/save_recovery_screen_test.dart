import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/database/migrations/database_corruption_exception.dart';
import 'package:global_domination/data/database/migrations/migration_failure_exception.dart';
import 'package:global_domination/data/database/migrations/save_recovery_actions.dart';
import 'package:global_domination/ui/save_recovery_screen.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  late Directory docsTemp;
  late PathProviderPlatform previousPath;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    docsTemp = Directory.systemTemp.createTempSync('save_recovery_ui_docs_');
    previousPath = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(docsTemp.path);
  });

  tearDown(() {
    PathProviderPlatform.instance = previousPath;
    if (docsTemp.existsSync()) {
      docsTemp.deleteSync(recursive: true);
    }
  });

  Future<void> pumpRecovery(
    WidgetTester tester,
    Object error, {
    StackTrace? stackTrace,
    SaveRecoveryBackupExists? backupExists,
    SaveRecoveryRestoreFromBackup? restoreFromBackup,
    SaveRecoveryLatestBackup? latestBackup,
    SaveRecoveryRestoreLatestBackup? restoreLatestBackup,
    SaveRecoveryStartFresh? startFresh,
    SaveRecoveryCopyDiagnostics? copyDiagnostics,
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: SaveRecoveryScreen(
          error: error,
          stackTrace: stackTrace,
          backupExists: backupExists ?? (_) async => false,
          restoreFromBackup: restoreFromBackup,
          latestBackup: latestBackup,
          restoreLatestBackup: restoreLatestBackup,
          startFresh: startFresh,
          copyDiagnostics: copyDiagnostics,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final corruptSqlite = SqliteException(
    extendedResultCode: SqlError.SQLITE_CORRUPT,
    message: 'bad',
    operation: 'opening',
  );

  final corruptionErr = DatabaseCorruptionException(
    cause: corruptSqlite,
    originalStackTrace: StackTrace.current,
    sqliteResultCode: SqlError.SQLITE_CORRUPT,
    sqliteExtendedResultCode: SqlError.SQLITE_CORRUPT,
    sqliteOperation: 'opening',
  );

  testWidgets('migration: hides restore when backup missing', (tester) async {
    await pumpRecovery(
      tester,
      const MigrationFailureException(
        fromVersion: 2,
        toVersion: 3,
        cause: 'synthetic',
      ),
    );

    expect(find.text('Save Recovery'), findsOneWidget);
    expect(find.textContaining('synthetic'), findsOneWidget);
    expect(find.byKey(const ValueKey('saveRecoveryRestore')), findsNothing);
    expect(find.text('Start Fresh'), findsOneWidget);
    expect(find.text('Contact Support'), findsOneWidget);
  });

  testWidgets('migration: shows exact-version restore when backup exists', (
    tester,
  ) async {
    await pumpRecovery(
      tester,
      const MigrationFailureException(
        fromVersion: 2,
        toVersion: 3,
        cause: 'synthetic',
      ),
      backupExists: (_) async => true,
    );

    expect(find.byKey(const ValueKey('saveRecoveryRestore')), findsOneWidget);
    expect(find.textContaining('Restore from backup v2'), findsOneWidget);
  });

  testWidgets('corruption: shows latest restore when backup exists', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('recovery_show_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final sf = File('${dir.path}/schema_backup_v3.sqlite')
      ..writeAsStringSync('x');
    final fake = SchemaBackup(
      version: 3,
      file: sf,
      modifiedAt: DateTime.utc(2024),
    );
    await pumpRecovery(tester, corruptionErr, latestBackup: () async => fake);

    expect(
      find.byKey(const ValueKey('saveRecoveryRestoreLatest')),
      findsOneWidget,
    );
    expect(find.text('Schema backup v3'), findsOneWidget);
    expect(find.text('Contact Support'), findsOneWidget);
  });

  testWidgets('corruption: hides restore when no backup', (tester) async {
    await pumpRecovery(tester, corruptionErr, latestBackup: () async => null);

    expect(
      find.byKey(const ValueKey('saveRecoveryRestoreLatest')),
      findsNothing,
    );
    expect(find.text('Start Fresh'), findsOneWidget);
  });

  testWidgets('restore latest calls injected callback', (tester) async {
    var calls = 0;
    final dir = Directory.systemTemp.createTempSync('recovery_latest_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final f = File('${dir.path}/schema_backup_v2.sqlite')
      ..writeAsStringSync('b');
    final fake = SchemaBackup(
      version: 2,
      file: f,
      modifiedAt: DateTime.utc(2022),
    );
    await pumpRecovery(
      tester,
      corruptionErr,
      latestBackup: () async => fake,
      restoreLatestBackup: () async {
        calls++;
      },
    );

    await tester.tap(find.byKey(const ValueKey('saveRecoveryRestoreLatest')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(calls, 1);
  });

  testWidgets('migration restore calls injected action with versions', (
    tester,
  ) async {
    var restoredFrom = 0;
    var restoredTo = 0;

    await pumpRecovery(
      tester,
      const MigrationFailureException(
        fromVersion: 2,
        toVersion: 3,
        cause: 'synthetic',
      ),
      backupExists: (_) async => true,
      restoreFromBackup:
          ({required int fromVersion, required int toVersion}) async {
            restoredFrom = fromVersion;
            restoredTo = toVersion;
          },
    );
    await tester.tap(find.byKey(const ValueKey('saveRecoveryRestore')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(restoredFrom, 2);
    expect(restoredTo, 3);
  });

  testWidgets('start fresh: first dialog cancel does not run action', (
    tester,
  ) async {
    var freshCalls = 0;
    await pumpRecovery(
      tester,
      corruptionErr,
      latestBackup: () async => null,
      startFresh: () async {
        freshCalls++;
      },
    );

    await tester.tap(find.text('Start Fresh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(freshCalls, 0);
  });

  testWidgets('start fresh: second dialog cancel does not run action', (
    tester,
  ) async {
    var freshCalls = 0;
    await pumpRecovery(
      tester,
      corruptionErr,
      latestBackup: () async => null,
      startFresh: () async {
        freshCalls++;
      },
    );

    await tester.tap(find.text('Start Fresh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(freshCalls, 0);
  });

  testWidgets('start fresh: confirms twice then runs action', (tester) async {
    var freshCalls = 0;
    await pumpRecovery(
      tester,
      corruptionErr,
      latestBackup: () async => null,
      startFresh: () async {
        freshCalls++;
      },
    );

    await tester.tap(find.text('Start Fresh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Start fresh'),
      ),
    );
    await tester.pumpAndSettle();
    expect(freshCalls, 1);
  });

  testWidgets('contact support copies diagnostics for corruption', (
    tester,
  ) async {
    String? copied;
    await pumpRecovery(
      tester,
      corruptionErr,
      latestBackup: () async => null,
      copyDiagnostics: (payload) {
        copied = payload;
        return Future<void>.value();
      },
    );

    await tester.tap(find.byKey(const ValueKey('saveRecoveryContact')));
    await tester.pumpAndSettle();

    expect(copied, isNotNull);
    expect(copied, contains('App schema version'));
    expect(copied, contains('${AppDatabase.currentSchemaVersion}'));
    expect(copied, contains('opening'));
    expect(find.text('Diagnostics copied'), findsOneWidget);
  });

  testWidgets('migration uses real start fresh flow', (tester) async {
    var freshCalls = 0;
    await pumpRecovery(
      tester,
      const MigrationFailureException(fromVersion: 2, toVersion: 3, cause: 'm'),
      backupExists: (_) async => true,
      startFresh: () async {
        freshCalls++;
      },
    );

    await tester.tap(find.text('Start Fresh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Start fresh'),
      ),
    );
    await tester.pumpAndSettle();
    expect(freshCalls, 1);
  });

  testWidgets('unrecognized error: support only, no destructive actions', (
    tester,
  ) async {
    await pumpRecovery(tester, Exception('boot failure'));

    expect(find.text('Contact Support'), findsOneWidget);
    expect(find.text('Start Fresh'), findsNothing);
    expect(find.byKey(const ValueKey('saveRecoveryRestore')), findsNothing);
  });

  testWidgets('narrow viewport and text scale: no overflow exceptions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: SaveRecoveryScreen(
            error: Exception(List.filled(40, 'long message ').join()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(tester.takeException(), isNull);
  });
}
