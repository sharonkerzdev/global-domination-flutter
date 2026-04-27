import 'package:decimal/decimal.dart';

import 'package:global_domination/game/content/achievement_def.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';

/// Pure: reads only [def], [state], and [content].
bool evaluateAchievementCondition(
  AchievementDef def,
  GameState state,
  ContentRegistry content,
) {
  final params = def.conditionParams;
  switch (def.conditionType) {
    case 'totalInfluenceAtLeast':
      final raw = params['value'];
      if (raw is! String) {
        throw StateError(
          'totalInfluenceAtLeast expects string value in conditionParams',
        );
      }
      return state.totalInfluence.value >= Decimal.parse(raw);
    case 'countriesUnlockedAtLeast':
      final count = params['count'];
      if (count is! int) {
        throw StateError(
          'countriesUnlockedAtLeast expects int count in conditionParams',
        );
      }
      final unlocked = state.countries.values.where((c) => c.unlocked).length;
      return unlocked >= count;
    case 'continentCompleted':
      final id = params['continentId'];
      if (id is! String) {
        throw StateError(
          'continentCompleted expects string continentId in conditionParams',
        );
      }
      final cid = ContinentId(id);
      if (!content.continents.containsKey(cid)) return false;
      return state.continentCompletions[cid] == true;
    case 'leadersHiredAtLeast':
      final count = params['count'];
      if (count is! int) {
        throw StateError(
          'leadersHiredAtLeast expects int count in conditionParams',
        );
      }
      final hired = state.countries.values
          .where((c) => c.leaderTier != LeaderTier.none)
          .length;
      return hired >= count;
    case 'maxIpLevelAtLeast':
      final level = params['level'];
      if (level is! int) {
        throw StateError(
          'maxIpLevelAtLeast expects int level in conditionParams',
        );
      }
      var maxIp = 0;
      for (final c in state.countries.values) {
        if (c.ipLevel > maxIp) maxIp = c.ipLevel;
      }
      return maxIp >= level;
    default:
      throw StateError(
        'Unknown achievementConditionType: ${def.conditionType}',
      );
  }
}
