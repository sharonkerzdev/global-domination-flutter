import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/crash_log_entry.dart';
import '../data/repositories/crash_log_repository.dart';

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
