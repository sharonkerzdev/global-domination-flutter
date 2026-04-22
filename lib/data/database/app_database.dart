import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

import '../repositories/crash_log_entry.dart';
import 'converters/crash_log_level_converter.dart';
import 'tables/crash_logs_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [CrashLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        await _backupDatabase(from);
        if (from == 1) {
          await m.createTable(crashLogs);
        }
      },
    );
  }

  static Future<void> _backupDatabase(int fromVersion) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dbFolder.path, 'global_domination.sqlite'));
    if (await dbFile.exists()) {
      final backupPath = p.join(
        dbFolder.path,
        'schema_backup_v$fromVersion.sqlite',
      );
      await dbFile.copy(backupPath);
    }
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'global_domination.sqlite'));
      sqlite3.tempDirectory = (await getTemporaryDirectory()).path;
      return NativeDatabase.createInBackground(file);
    });
  }
}
