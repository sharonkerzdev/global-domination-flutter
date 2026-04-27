import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/game/features/economy/offline_catchup.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/database_providers.dart';

final clockProvider = Provider<Clock>((_) => const SystemClock());

final rngProvider = Provider<Rng>((_) => SystemRng());

/// Persisted rows mapped to simulation state plus the meta clock source for
/// offline catch-up ([lastSavedAt]).
class PersistedGameSnapshot {
  const PersistedGameSnapshot({required this.state, required this.lastSavedAt});

  final GameState state;
  final DateTime? lastSavedAt;
}

final persistedGameSnapshotProvider = FutureProvider<PersistedGameSnapshot>((
  ref,
) async {
  final content = await ref.watch(contentRegistryProvider.future);
  final database = ref.watch(appDatabaseProvider);
  final mapper = ref.watch(gameStateMapperProvider);
  final rows = await database.loadAll();
  final state = mapper.fromRows(rows, content);
  final lastSavedAt = rows.meta?.lastSavedAt.toUtc();
  return PersistedGameSnapshot(state: state, lastSavedAt: lastSavedAt);
});

final gameWorldProvider = StateNotifierProvider<GameWorldNotifier, GameState>((
  ref,
) {
  final content = ref.watch(contentRegistryProvider).requireValue;
  final snapshot = ref.watch(persistedGameSnapshotProvider).requireValue;
  final clock = ref.watch(clockProvider);
  final rng = ref.watch(rngProvider);
  final world = GameWorld(
    content: content,
    clock: clock,
    rng: rng,
    initialState: snapshot.state,
  );
  return GameWorldNotifier(world);
});

class GameWorldNotifier extends StateNotifier<GameState> {
  GameWorldNotifier(GameWorld world) : _world = world, super(world.state) {
    _subscription = world.events.listen((_) {
      state = _world.state;
    });
  }

  final GameWorld _world;
  late final StreamSubscription<GameEvent> _subscription;

  void apply(GameCommand cmd) {
    _world.applyCommand(cmd);
    state = _world.state;
  }

  void tick(Duration dt) {
    _world.tick(dt);
  }

  OfflineCatchupResult applyOfflineCatchup({required DateTime lastSavedAt}) {
    final result = _world.applyOfflineCatchup(lastSavedAt: lastSavedAt);
    state = _world.state;
    return result;
  }

  /// Exposes the event stream without leaking [GameWorld] internals.
  Stream<GameEvent> get events => _world.events;

  @override
  void dispose() {
    _subscription.cancel();
    _world.dispose();
    super.dispose();
  }
}

final gameWorldEventsProvider = Provider<Stream<GameEvent>>(
  (ref) => ref.watch(gameWorldProvider.notifier).events,
);
