import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/providers/app_providers.dart';

final clockProvider = Provider<Clock>((_) => const SystemClock());

final rngProvider = Provider<Rng>((_) => SystemRng());

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

  /// Exposes the event stream without leaking [GameWorld] internals.
  Stream<GameEvent> get events => _world.events;

  @override
  void dispose() {
    _subscription.cancel();
    _world.dispose();
    super.dispose();
  }
}

final gameWorldProvider = StateNotifierProvider<GameWorldNotifier, GameState>((
  ref,
) {
  final content = ref.watch(contentRegistryProvider).value;
  final clock = ref.watch(clockProvider);
  final rng = ref.watch(rngProvider);
  final world = content == null
      ? GameWorld(
          content: const ContentRegistry(
            countries: {},
            continents: {},
            leaders: [],
            achievements: [],
            missions: [],
            globalUpgrades: [],
            dailyRewards: [],
          ),
          clock: clock,
          rng: rng,
          initialState: GameState(),
        )
      : GameWorld(content: content, clock: clock, rng: rng);
  return GameWorldNotifier(world);
});

final gameWorldEventsProvider = Provider<Stream<GameEvent>>(
  (ref) => ref.watch(gameWorldProvider.notifier).events,
);
