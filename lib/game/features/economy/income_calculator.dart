import 'package:decimal/decimal.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/achievement_def.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/influence.dart';

/// Authoritative per-second influence generation for one country.
///
/// Multiplier stack (exact order):
/// 1. `baseInfluence` from [CountryDef]
/// 2. × `(1 + ipLevel × BalanceConfig.ipMultPerLevel)` — Influence Power
/// 3. × `leaderMultiplier(country.leaderTier)`
/// 4. × continent completion bonus — `1 + completionBonus` when the country's
///    continent is marked complete in [GameState.continentCompletions], else `1`
/// 5. × `(1 + Σ achievementMultipliers)` — achievements with
///    `rewardType == 'influenceMultiplier'` sum additively, then +1
/// 6. × product of `influenceAmplifier` for each id in
///    [GameState.activeGlobalUpgradeIds]
/// 7. × [GameState.goldenOpportunityMultiplier]
/// 8. × [GameState.boostMultiplier]
abstract final class IncomeCalculator {
  static Influence compute(
    CountryState country,
    GameState state,
    ContentRegistry content,
  ) {
    if (!country.unlocked) return Influence.zero;

    final def = content.countries[country.id];
    if (def == null || def.baseInfluence == Decimal.zero) {
      return Influence.zero;
    }

    var rate = def.baseInfluence;
    rate *=
        Decimal.one +
        Decimal.fromInt(country.ipLevel) * BalanceConfig.ipMultPerLevel;
    rate *= _leaderMultiplier(country.leaderTier);
    rate *= _continentCompletionBonus(country, state, content);
    rate *= Decimal.one + _sumAchievementMultipliers(state, content);
    rate *= _globalUpgradeAmplifier(state, content);
    rate *= state.goldenOpportunityMultiplier;
    rate *= state.boostMultiplier;

    return Influence(rate);
  }

  static Decimal _leaderMultiplier(LeaderTier tier) =>
      BalanceConfig.leaderMultiplier(tier);

  static Decimal _continentCompletionBonus(
    CountryState country,
    GameState state,
    ContentRegistry content,
  ) {
    final def = content.countries[country.id];
    if (def == null) return Decimal.one;
    final continentId = def.continent;
    if (state.continentCompletions[continentId] != true) return Decimal.one;
    final continentDef = content.continents[continentId];
    if (continentDef == null) return Decimal.one;
    return Decimal.one + continentDef.completionBonus;
  }

  static Decimal _sumAchievementMultipliers(
    GameState state,
    ContentRegistry content,
  ) {
    var sum = Decimal.zero;
    for (final id in state.earnedAchievementIds) {
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

  static Decimal _globalUpgradeAmplifier(
    GameState state,
    ContentRegistry content,
  ) {
    if (state.activeGlobalUpgradeIds.isEmpty) return Decimal.one;
    var product = Decimal.one;
    for (final id in state.activeGlobalUpgradeIds) {
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
