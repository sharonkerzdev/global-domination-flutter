import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/database/migrations/migration_failure_exception.dart';
import 'package:global_domination/data/mappers/game_state_mapper.dart';
import 'package:global_domination/data/repositories/crash_log_entry.dart';
import 'package:global_domination/data/repositories/crash_log_repository.dart';
import 'package:global_domination/services/crash_reporter.dart';

typedef AppDatabaseFactory = AppDatabase Function();

final appDatabaseFactoryProvider = Provider<AppDatabaseFactory>(
  (_) => AppDatabase.new,
);

final databaseBootstrapProvider = FutureProvider<AppDatabase>((ref) async {
  final db = ref.watch(appDatabaseFactoryProvider)();
  Future<void>? closeFuture;
  Future<void> closeDb() {
    closeFuture ??= db.close();
    return closeFuture!;
  }

  ref.onDispose(() async {
    await closeDb();
  });
  try {
    await db.customSelect('SELECT 1').get();
  } on MigrationFailureException catch (e, s) {
    CrashReporter.instance.reportZonedError(e, s);
    try {
      await closeDb();
    } catch (_) {
      // Preserve the migration failure as the user-visible boot error.
    }
    Error.throwWithStackTrace(e, s);
  } catch (e, s) {
    try {
      await closeDb();
    } catch (_) {
      // Preserve the original boot failure.
    }
    Error.throwWithStackTrace(e, s);
  }
  return db;
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return ref.watch(databaseBootstrapProvider).requireValue;
});

final crashLogRepositoryProvider = Provider<CrashLogRepository>((ref) {
  return CrashLogRepository(ref.watch(appDatabaseProvider));
});

final crashLogsProvider = FutureProvider<List<CrashLogEntry>>((ref) {
  return ref.watch(crashLogRepositoryProvider).readAllNewestFirst();
});

final gameStateMapperProvider = Provider<GameStateMapper>(
  (_) => const GameStateMapper(),
);
