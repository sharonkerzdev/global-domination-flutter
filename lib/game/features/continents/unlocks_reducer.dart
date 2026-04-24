import 'package:decimal/decimal.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/result.dart';

/// Spends [CountryDef.unlockCost] from content — do not derive costs from formulas here.
Result<(GameState, GameEvent?), GameError> applyUnlockCountry(
  GameState state,
  ContentRegistry content,
  UnlockCountry cmd, {
  required DateTime now,
}) {
  final country = state.countries[cmd.countryId];
  if (country == null) {
    return Result.failure(GameError.internalMissingCountry(id: cmd.countryId));
  }
  final def = content.countries[cmd.countryId];
  if (def == null) {
    return Result.failure(GameError.internalMissingCountry(id: cmd.countryId));
  }
  if (country.unlocked) {
    return const Result.failure(
      GameError.userLocked(reason: 'already_unlocked'),
    );
  }

  final continentDef = content.continents[def.continent];
  if (continentDef == null) {
    return Result.failure(GameError.internalMissingCountry(id: cmd.countryId));
  }
  if (state.totalInfluence < Influence(continentDef.unlockThreshold)) {
    return const Result.failure(
      GameError.userLocked(reason: 'continent_locked'),
    );
  }

  if (def.unlockCost < Decimal.zero) {
    return Result.failure(
      GameError.internalInvariantBroken(
        message: 'country ${cmd.countryId.value} has negative unlockCost',
      ),
    );
  }

  final cost = Influence(def.unlockCost);
  if (state.totalInfluence < cost) {
    return Result.failure(GameError.userInsufficientFunds(required: cost));
  }

  final newCountry = country.copyWith(
    unlocked: true,
    ipLevel: 1,
    leaderTier: LeaderTier.none,
    bankedInfluence: Influence.zero,
    lastCollectedAt: null,
  );
  final newState = state.copyWith(
    countries: {...state.countries, cmd.countryId: newCountry},
    totalInfluence: state.totalInfluence - cost,
  );
  final event = CountryUnlocked(
    now,
    countryId: cmd.countryId,
    continent: def.continent,
    cost: cost,
  );
  return Result.success((newState, event));
}
