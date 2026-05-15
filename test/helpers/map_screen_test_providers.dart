import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/content/continent_def.dart';
import 'package:global_domination/game/content/country_def.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/ui/features/map/country_path.dart';

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

Override mapWidgetTestGameWorldOverride([GameState? initial]) =>
    gameWorldProvider.overrideWith(
      (ref) => MapWidgetTestGameWorldNotifier(initial),
    );

ContentRegistry mapWidgetTestContentForCountries(List<CountryPath> countries) {
  final continents = <ContinentId, ContinentDef>{};
  final countryDefs = <CountryId, CountryDef>{};
  for (final country in countries) {
    continents.putIfAbsent(
      country.continent,
      () => ContinentDef(
        id: country.continent,
        name: country.continent.value,
        unlockThreshold: Decimal.zero,
        completionBonus: Decimal.zero,
        milestoneRewards: const [],
      ),
    );
    countryDefs[country.id] = CountryDef(
      id: country.id,
      continent: country.continent,
      baseInfluence: Decimal.one,
      unlockCost: Decimal.zero,
      tier: 1,
      generationSeconds: 1,
    );
  }
  return ContentRegistry(
    countries: Map.unmodifiable(countryDefs),
    continents: Map.unmodifiable(continents),
    leaders: const [],
    achievements: const [],
    missions: const [],
    globalUpgrades: const [],
    dailyRewards: const [],
  );
}

Override mapWidgetTestContentOverride(List<CountryPath> countries) {
  return contentRegistryProvider.overrideWith(
    (ref) async => mapWidgetTestContentForCountries(countries),
  );
}
