import 'dart:async';

export 'database_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/data/repositories/save_repository.dart';
import 'package:global_domination/services/audio_service.dart';
import 'package:global_domination/services/haptics_service.dart';

import 'database_providers.dart';
import 'game_providers.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  final svc = AudioService(
    events: ref.watch(gameWorldEventsProvider),
    readEnabled: () => ref.read(soundEnabledProvider),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(() {
    unawaited(svc.dispose());
  });
  return svc;
});

final hapticsServiceProvider = Provider<HapticsService>((ref) {
  final svc = HapticsService(
    events: ref.watch(gameWorldEventsProvider),
    readEnabled: () => ref.read(hapticsEnabledProvider),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(() {
    unawaited(svc.detach());
  });
  return svc;
});

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
