import 'package:decimal/decimal.dart';
import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/economy/income_calculator.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/result.dart';

Result<(GameState, GameEvent?), GameError> applyPurchaseUpgrade(
  GameState state,
  ContentRegistry content,
  PurchaseUpgrade cmd, {
  required DateTime now,
}) {
  if (cmd.bulk < 1) {
    return Result.failure(
      GameError.userInvalidTarget(detail: 'bulk must be at least 1'),
    );
  }

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
  if (country.ipLevel >= BalanceConfig.maxIpLevel) {
    return const Result.failure(GameError.userLocked(reason: 'max_level'));
  }

  final def = content.countries[cmd.countryId];
  if (def == null) {
    return Result.failure(GameError.internalMissingCountry(id: cmd.countryId));
  }
  if (def.baseInfluence <= Decimal.zero) {
    return Result.failure(
      GameError.internalInvariantBroken(
        message:
            'country ${cmd.countryId.value} has non-positive baseInfluence',
      ),
    );
  }

  final room = BalanceConfig.maxIpLevel - country.ipLevel;
  final buy = cmd.bulk < room ? cmd.bulk : room;
  if (buy < 1) {
    return const Result.failure(GameError.userLocked(reason: 'max_level'));
  }

  final cost = IncomeCalculator.upgradeCost(def, country.ipLevel, buy);
  if (state.totalInfluence < cost) {
    return Result.failure(GameError.userInsufficientFunds(required: cost));
  }

  final newIp = country.ipLevel + buy;
  final newCountry = country.copyWith(ipLevel: newIp);
  final newState = state.copyWith(
    countries: {...state.countries, cmd.countryId: newCountry},
    totalInfluence: state.totalInfluence - cost,
  );
  final event = UpgradePurchased(
    now,
    countryId: cmd.countryId,
    levelsAdded: buy,
    bulkRequested: cmd.bulk,
    totalCost: cost,
  );
  return Result.success((newState, event));
}
