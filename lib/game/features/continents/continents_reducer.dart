import 'package:decimal/decimal.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/result.dart';

/// Unlocks continents whose [ContinentDef.unlockThreshold] is met by
/// [GameState.totalInfluence]. Pure: [now] is injected for events only.
Result<(GameState, List<GameEvent>), GameError> evaluateContinentUnlocks(
  GameState state,
  ContentRegistry content, {
  required DateTime now,
}) {
  for (final c in content.continents.values) {
    if (c.unlockThreshold < Decimal.zero) {
      return Result.failure(
        GameError.internalInvariantBroken(
          message: 'continent ${c.id.value} has negative unlockThreshold',
        ),
      );
    }
  }

  final total = state.totalInfluence.value;
  final candidates = content.continents.values
      .where(
        (c) =>
            c.unlockThreshold <= total &&
            state.unlockedContinents[c.id] != true,
      )
      .toList();

  if (candidates.isEmpty) {
    return Result.success((state, const <GameEvent>[]));
  }

  candidates.sort((a, b) {
    final byTh = a.unlockThreshold.compareTo(b.unlockThreshold);
    if (byTh != 0) return byTh;
    return a.id.value.compareTo(b.id.value);
  });

  final newMap = <ContinentId, bool>{
    ...state.unlockedContinents,
    for (final c in candidates) c.id: true,
  };
  final events = candidates
      .map((c) => ContinentUnlocked(now, continentId: c.id))
      .toList(growable: false);

  return Result.success((
    state.copyWith(unlockedContinents: Map.unmodifiable(newMap)),
    events,
  ));
}
