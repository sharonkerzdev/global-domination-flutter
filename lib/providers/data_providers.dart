import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/mappers/game_state_mapper.dart';
import '../data/repositories/crash_log_entry.dart';
import '../data/repositories/crash_log_repository.dart';
import '../data/repositories/save_repository.dart';
import 'game_providers.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
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

final saveRepositoryProvider = Provider<SaveRepository>((ref) {
  final repo = SaveRepository(
    db: ref.watch(appDatabaseProvider),
    mapper: ref.watch(gameStateMapperProvider),
    events: ref.watch(gameWorldEventsProvider),
    readState: () => ref.read(gameWorldProvider),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(() {
    unawaited(repo.dispose());
  });
  return repo;
});
