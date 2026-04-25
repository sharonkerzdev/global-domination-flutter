import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/content/continent_def.dart';
import 'package:global_domination/game/features/continents/next_unlock_teaser.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/influence.dart';

NextUnlockTeaser? nextUnlockInContinent(
  GameState state,
  ContentRegistry content,
  ContinentId continentId,
) {
  for (final def in content.countries.values) {
    if (def.continent != continentId) continue;
    final cs = state.countries[def.id];
    if (cs == null || !cs.unlocked) {
      return NextUnlockTeaser(
        countryId: def.id,
        unlockCost: Influence(def.unlockCost),
        continent: continentId,
      );
    }
  }
  return null;
}

NextUnlockTeaser? nextUnlockOverall(GameState state, ContentRegistry content) {
  final effectivelyUnlocked = <ContinentDef>[];
  for (final c in content.continents.values) {
    if (c.unlockThreshold <= state.totalInfluence.value) {
      effectivelyUnlocked.add(c);
    }
  }
  effectivelyUnlocked.sort((a, b) {
    final byThreshold = a.unlockThreshold.compareTo(b.unlockThreshold);
    if (byThreshold != 0) return byThreshold;
    return a.id.value.compareTo(b.id.value);
  });
  for (final c in effectivelyUnlocked) {
    final teaser = nextUnlockInContinent(state, content, c.id);
    if (teaser != null) return teaser;
  }
  return null;
}
