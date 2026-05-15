import 'package:decimal/decimal.dart';

import 'package:global_domination/game/content/achievement_def.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';

/// Shared pieces of the income multiplier stack used by [IncomeCalculator] and
/// Stats breakdown so continent / achievement / global-upgrade math stays single-sourced.
abstract final class MultiplierStackHelpers {
  /// Product over completed continents of `(1 + completionBonus)`; [Decimal.one] if none.
  static Decimal continentCompletionProduct(
    GameState state,
    ContentRegistry content,
  ) {
    return continentCompletionProductForMap(
      state.continentCompletions,
      content,
    );
  }

  /// Same as [continentCompletionProduct] but accepts only the completion map.
  static Decimal continentCompletionProductForMap(
    Map<ContinentId, bool> continentCompletions,
    ContentRegistry content,
  ) {
    var product = Decimal.one;
    for (final e in continentCompletions.entries) {
      if (e.value != true) continue;
      final continentDef = content.continents[e.key];
      if (continentDef == null) continue;
      product *= Decimal.one + continentDef.completionBonus;
    }
    return product;
  }

  /// Sum of [AchievementDef.rewardValue] for earned ids whose definition exists
  /// and [rewardType] is [influenceMultiplier].
  static Decimal sumInfluenceAchievementRewards(
    GameState state,
    ContentRegistry content,
  ) {
    return sumInfluenceAchievementRewardsForIds(
      state.earnedAchievementIds,
      content,
    );
  }

  /// Same as [sumInfluenceAchievementRewards] for an arbitrary earned-id set.
  static Decimal sumInfluenceAchievementRewardsForIds(
    Set<String> earnedAchievementIds,
    ContentRegistry content,
  ) {
    var sum = Decimal.zero;
    for (final id in earnedAchievementIds) {
      AchievementDef? match;
      for (final a in content.achievements) {
        if (a.id == id) {
          match = a;
          break;
        }
      }
      if (match == null) continue;
      if (match.rewardType == 'influenceMultiplier') {
        sum += match.rewardValue;
      }
    }
    return sum;
  }

  /// Income stack slot: `1 + Σ` influence-multiplier achievement rewards.
  static Decimal achievementInfluenceFactor(
    GameState state,
    ContentRegistry content,
  ) {
    return Decimal.one + sumInfluenceAchievementRewards(state, content);
  }

  static Decimal achievementInfluenceFactorForIds(
    Set<String> earnedAchievementIds,
    ContentRegistry content,
  ) {
    return Decimal.one +
        sumInfluenceAchievementRewardsForIds(earnedAchievementIds, content);
  }

  /// Product of [GlobalUpgradeDef.influenceAmplifier] for active ids that exist in content.
  static Decimal globalUpgradeProduct(
    GameState state,
    ContentRegistry content,
  ) {
    return globalUpgradeProductForIds(state.activeGlobalUpgradeIds, content);
  }

  static Decimal globalUpgradeProductForIds(
    Set<String> activeGlobalUpgradeIds,
    ContentRegistry content,
  ) {
    if (activeGlobalUpgradeIds.isEmpty) return Decimal.one;
    var product = Decimal.one;
    for (final id in activeGlobalUpgradeIds) {
      for (final u in content.globalUpgrades) {
        if (u.id == id) {
          product *= u.influenceAmplifier;
          break;
        }
      }
    }
    return product;
  }
}
