import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/database/migrations/database_corruption_exception.dart';
import 'package:global_domination/data/database/migrations/migration_failure_exception.dart';
import 'package:global_domination/data/mappers/game_state_mapper.dart';
import 'package:global_domination/data/repositories/app_settings.dart';
import 'package:global_domination/data/repositories/crash_log_entry.dart';
import 'package:global_domination/data/repositories/crash_log_repository.dart';
import 'package:global_domination/data/repositories/settings_repository.dart';
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
    final corruption = DatabaseCorruptionException.tryFrom(e, s);
    if (corruption != null) {
      CrashReporter.instance.reportZonedError(corruption, s);
      try {
        await closeDb();
      } catch (_) {
        // Preserve the corruption error as the user-visible boot error.
      }
      Error.throwWithStackTrace(corruption, s);
    }
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

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});

final appSettingsProvider = StreamProvider<AppSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).watchSettings();
});

final soundEnabledProvider = Provider<bool>((ref) {
  return ref
      .watch(appSettingsProvider)
      .maybeWhen(
        data: (s) => s.soundEnabled,
        orElse: () => AppSettings.defaults.soundEnabled,
      );
});

final hapticsEnabledProvider = Provider<bool>((ref) {
  return ref
      .watch(appSettingsProvider)
      .maybeWhen(
        data: (s) => s.hapticsEnabled,
        orElse: () => AppSettings.defaults.hapticsEnabled,
      );
});

final notificationsEnabledProvider = Provider<bool>((ref) {
  return ref
      .watch(appSettingsProvider)
      .maybeWhen(
        data: (s) => s.notificationsEnabled,
        orElse: () => AppSettings.defaults.notificationsEnabled,
      );
});

final crashLogsProvider = FutureProvider<List<CrashLogEntry>>((ref) {
  return ref.watch(crashLogRepositoryProvider).readAllNewestFirst();
});

final gameStateMapperProvider = Provider<GameStateMapper>(
  (_) => const GameStateMapper(),
);
