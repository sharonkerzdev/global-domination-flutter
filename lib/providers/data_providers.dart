import 'dart:async';

export 'database_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/data/repositories/save_repository.dart';

import 'database_providers.dart';
import 'game_providers.dart';

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
