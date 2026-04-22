import 'package:decimal/decimal.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/economy/income_calculator.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/result.dart';

Result<(GameState, GameEvent?), GameError> applyHireLeader(
  GameState state,
  ContentRegistry content,
  HireLeader cmd, {
  required DateTime now,
}) {
  final country = state.countries[cmd.countryId];
  if (country == null) {
    return Result.failure(GameError.internalMissingCountry(id: cmd.countryId));
  }
  if (!country.unlocked) {
    return Result.failure(
      GameError.userLocked(reason: 'country ${cmd.countryId.value} is locked'),
    );
  }
  if (country.ipLevel < 0) {
    return Result.failure(
      GameError.internalInvariantBroken(
        message: 'country ${cmd.countryId.value} has negative ipLevel',
      ),
    );
  }
  if (country.ipLevel < BalanceConfig.leaderHireMinIpLevel) {
    return const Result.failure(
      GameError.userLocked(reason: 'ip_below_10'),
    );
  }
  if (country.leaderTier != LeaderTier.none) {
    return const Result.failure(
      GameError.userLocked(reason: 'leader_already_hired'),
    );
  }

  final def = content.countries[cmd.countryId];
  if (def == null) {
    return Result.failure(GameError.internalMissingCountry(id: cmd.countryId));
  }
  if (def.baseInfluence <= Decimal.zero) {
    return Result.failure(
      GameError.internalInvariantBroken(
        message: 'country ${cmd.countryId.value} has non-positive baseInfluence',
      ),
    );
  }

  final cost = IncomeCalculator.leaderHireCost(def);
  if (state.totalInfluence < cost) {
    return Result.failure(GameError.userInsufficientFunds(required: cost));
  }

  final newCountry = country.copyWith(leaderTier: LeaderTier.tier1);
  final newState = state.copyWith(
    countries: {...state.countries, cmd.countryId: newCountry},
    totalInfluence: state.totalInfluence - cost,
  );
  final event = LeaderHired(
    now,
    countryId: cmd.countryId,
    cost: cost,
    newTier: LeaderTier.tier1,
  );
  return Result.success((newState, event));
}

Result<(GameState, GameEvent?), GameError> applyUpgradeLeader(
  GameState state,
  ContentRegistry content,
  UpgradeLeader cmd, {
  required DateTime now,
}) {
  final country = state.countries[cmd.countryId];
  if (country == null) {
    return Result.failure(GameError.internalMissingCountry(id: cmd.countryId));
  }
  if (!country.unlocked) {
    return Result.failure(
      GameError.userLocked(reason: 'country ${cmd.countryId.value} is locked'),
    );
  }
  if (country.ipLevel < 0) {
    return Result.failure(
      GameError.internalInvariantBroken(
        message: 'country ${cmd.countryId.value} has negative ipLevel',
      ),
    );
  }

  final def = content.countries[cmd.countryId];
  if (def == null) {
    return Result.failure(GameError.internalMissingCountry(id: cmd.countryId));
  }
  if (def.baseInfluence <= Decimal.zero) {
    return Result.failure(
      GameError.internalInvariantBroken(
        message: 'country ${cmd.countryId.value} has non-positive baseInfluence',
      ),
    );
  }

  if (country.leaderTier == LeaderTier.none) {
    return const Result.failure(
      GameError.userLocked(reason: 'no_leader_hired'),
    );
  }
  if (country.leaderTier == LeaderTier.tier3) {
    return const Result.failure(
      GameError.userLocked(reason: 'leader_max_tier'),
    );
  }

  final from = country.leaderTier;
  final newTier = from == LeaderTier.tier1 ? LeaderTier.tier2 : LeaderTier.tier3;
  final cost = IncomeCalculator.leaderUpgradeCost(def, from);
  if (state.totalInfluence < cost) {
    return Result.failure(GameError.userInsufficientFunds(required: cost));
  }

  final newCountry = country.copyWith(leaderTier: newTier);
  final newState = state.copyWith(
    countries: {...state.countries, cmd.countryId: newCountry},
    totalInfluence: state.totalInfluence - cost,
  );
  final event = LeaderUpgraded(
    now,
    countryId: cmd.countryId,
    cost: cost,
    newTier: newTier,
  );
  return Result.success((newState, event));
}
