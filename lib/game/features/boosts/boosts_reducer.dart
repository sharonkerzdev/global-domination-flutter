import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/features/boosts/boost_state.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/result.dart';

Result<(GameState, GameEvent?), GameError> applyActivateBoost(
  GameState state,
  ActivateBoost _, {
  required DateTime now,
}) {
  final current = state.activeBoost;
  if (current != null && current.expiresAt.isAfter(now)) {
    return const Result.failure(
      GameError.userLocked(reason: 'boost_already_active'),
    );
  }
  if (state.totalIntel < BalanceConfig.boostCost) {
    return Result.failure(
      GameError.userInsufficientIntel(required: BalanceConfig.boostCost),
    );
  }

  final expiresAt = now.add(
    Duration(seconds: BalanceConfig.boostDurationSeconds),
  );
  final boost = BoostState(
    multiplier: BalanceConfig.boostMultiplier,
    expiresAt: expiresAt,
  );
  final newState = state.copyWith(
    totalIntel: state.totalIntel - BalanceConfig.boostCost,
    activeBoost: boost,
  );
  final event = BoostActivated(
    now,
    multiplier: BalanceConfig.boostMultiplier,
    expiresAt: expiresAt,
    intelSpent: BalanceConfig.boostCost,
  );
  return Result.success((newState, event));
}

(GameState, List<GameEvent>) evaluateBoostExpiry(
  GameState state, {
  required DateTime now,
}) {
  final boost = state.activeBoost;
  if (boost == null) return (state, const <GameEvent>[]);
  if (boost.expiresAt.isAfter(now)) return (state, const <GameEvent>[]);
  return (state.copyWith(activeBoost: null), [BoostExpired(now)]);
}
