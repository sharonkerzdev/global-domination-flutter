import 'package:decimal/decimal.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/features/goldens/active_golden.dart';
import 'package:global_domination/game/features/goldens/active_golden_effect.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/result.dart';

Result<(GameState, GameEvent?), GameError> applyClaimGolden(
  GameState state,
  ClaimGolden cmd, {
  required DateTime now,
}) {
  final target = state.activeGoldens[cmd.goldenId];
  if (target == null) {
    return Result.failure(
      const GameError.userInvalidTarget(detail: 'golden_not_found'),
    );
  }
  if (target.expiresAt.compareTo(now) <= 0) {
    return const Result.failure(GameError.userLocked(reason: 'golden_expired'));
  }
  if (state.countries[target.countryId]?.unlocked != true) {
    return const Result.failure(GameError.userLocked(reason: 'country_locked'));
  }

  final nextMap = Map<String, ActiveGolden>.from(state.activeGoldens)
    ..remove(cmd.goldenId);
  final nextEffect = ActiveGoldenEffect(
    goldenId: cmd.goldenId,
    multiplier: target.multiplier,
    expiresAt: now.add(
      const Duration(seconds: BalanceConfig.goldenEffectDurationSeconds),
    ),
  );
  final nextMultiplier = Decimal.fromInt(target.multiplier);
  final newState = state.copyWith(
    activeGoldens: nextMap,
    activeGoldenEffect: nextEffect,
    goldenOpportunityMultiplier: nextMultiplier,
  );
  final event = GoldenClaimed(
    now,
    goldenId: cmd.goldenId,
    countryId: target.countryId,
    multiplier: target.multiplier,
    durationSeconds: BalanceConfig.goldenEffectDurationSeconds,
  );
  return Result.success((newState, event));
}
