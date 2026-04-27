import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/achievements/achievement_condition.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';

/// Pure: [now] is only used for event timestamps.
(GameState, List<GameEvent>) evaluateAchievements(
  GameState state,
  ContentRegistry content,
  DateTime now,
) {
  final events = <GameEvent>[];
  final newlyEarned = <String>{};
  for (final def in content.achievements) {
    if (state.earnedAchievementIds.contains(def.id)) continue;
    if (!evaluateAchievementCondition(def, state, content)) continue;
    newlyEarned.add(def.id);
    events.add(
      AchievementEarned(
        now,
        achievementId: def.id,
        rewardType: def.rewardType,
        rewardValue: def.rewardValue,
      ),
    );
  }
  if (events.isEmpty) return (state, const <GameEvent>[]);
  return (
    state.copyWith(
      earnedAchievementIds: {...state.earnedAchievementIds, ...newlyEarned},
    ),
    events,
  );
}
