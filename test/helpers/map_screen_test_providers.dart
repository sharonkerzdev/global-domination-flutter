import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/providers/game_providers.dart';

/// Empty catalog so [MapScreen] widget tests do not depend on asset JSON or DB
/// snapshot wiring.
final mapWidgetTestEmptyContent = const ContentRegistry(
  countries: {},
  continents: {},
  leaders: [],
  achievements: [],
  missions: [],
  globalUpgrades: [],
  dailyRewards: [],
);

/// Minimal notifier for isolating MapScreen UI tests from persistence boot.
class MapWidgetTestGameWorldNotifier extends GameWorldNotifier {
  MapWidgetTestGameWorldNotifier([GameState? initial])
    : super(
        GameWorld(
          content: mapWidgetTestEmptyContent,
          clock: const SystemClock(),
          rng: SeededRng(0),
          initialState: initial ?? GameState(),
        ),
      );

  @override
  void apply(GameCommand cmd) {}

  @override
  void tick(Duration dt) {}
}

Override mapWidgetTestGameWorldOverride() =>
    gameWorldProvider.overrideWith((ref) => MapWidgetTestGameWorldNotifier());
