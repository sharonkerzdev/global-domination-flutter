import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/daily_rewards/daily_streak.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';
import 'package:global_domination/game/values/result.dart';

/// True when the player has not yet claimed a reward for the local calendar day of [now].
bool dailyRewardAvailable(GameState state, DateTime now) {
  final last = state.dailyStreak.lastClaimDate;
  if (last == null) return true;
  final lastLocal = last.toLocal();
  final nowLocal = now.toLocal();
  return _localDayDelta(lastLocal, nowLocal) >= 1;
}

int _localDayDelta(DateTime aLocal, DateTime bLocal) {
  final a = DateTime.utc(aLocal.year, aLocal.month, aLocal.day);
  final b = DateTime.utc(bLocal.year, bLocal.month, bLocal.day);
  return b.difference(a).inDays;
}

Result<(GameState, GameEvent?), GameError> applyClaimDailyReward(
  GameState state,
  ContentRegistry content,
  ClaimDailyReward cmd, {
  required DateTime now,
}) {
  if (!dailyRewardAvailable(state, now)) {
    return const Result.failure(
      GameError.userLocked(reason: 'daily_reward_already_claimed'),
    );
  }
  if (content.dailyRewards.length != 7) {
    return const Result.failure(
      GameError.internalInvariantBroken(
        message: 'daily_rewards_content_must_have_7_entries',
      ),
    );
  }

  final last = state.dailyStreak.lastClaimDate;
  final int newDay;
  if (last == null) {
    newDay = 1;
  } else {
    final gap = _localDayDelta(last.toLocal(), now.toLocal());
    assert(gap > 0, 'gap==0 should have been rejected by dailyRewardAvailable');
    if (gap == 1) {
      newDay = state.dailyStreak.day == 7 ? 1 : state.dailyStreak.day + 1;
    } else {
      newDay = 1;
    }
  }

  final def = content.dailyRewards[newDay - 1];
  if (def.day != newDay) {
    return Result.failure(
      GameError.internalInvariantBroken(
        message: 'daily_rewards_day_${def.day}_does_not_match_$newDay',
      ),
    );
  }

  final influenceReward = Influence(def.influenceReward);
  final intelReward = Intel(def.intelReward);
  final newState = state.copyWith(
    totalInfluence: state.totalInfluence + influenceReward,
    totalIntel: state.totalIntel + intelReward,
    dailyStreak: DailyStreak(day: newDay, lastClaimDate: now),
  );
  final event = DailyRewardClaimed(
    now,
    day: newDay,
    influenceReward: influenceReward,
    intelReward: intelReward,
  );
  return Result.success((newState, event));
}
