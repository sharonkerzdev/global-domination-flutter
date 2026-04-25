import 'package:decimal/decimal.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/achievement_def.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/content/country_def.dart';
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
/// 4. × product over all complete continents of `(1 + ContinentDef.completionBonus)`
///    — global factor, NOT per-country
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
    rate *= _continentCompletionBonus(state, content);
    rate *= Decimal.one + _sumAchievementMultipliers(state, content);
    rate *= _globalUpgradeAmplifier(state, content);
    rate *= state.goldenOpportunityMultiplier;
    rate *= state.boostMultiplier;

    return Influence(rate);
  }

  static Decimal _leaderMultiplier(LeaderTier tier) =>
      BalanceConfig.leaderMultiplier(tier);

  static Decimal _continentCompletionBonus(
    GameState state,
    ContentRegistry content,
  ) {
    var product = Decimal.one;
    for (final e in state.continentCompletions.entries) {
      if (e.value != true) continue;
      final continentDef = content.continents[e.key];
      if (continentDef == null) continue;
      product *= Decimal.one + continentDef.completionBonus;
    }
    return product;
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

  /// Geometric cost for `bulk` consecutive IP levels starting at [currentLevel].
  ///
  /// `B = def.baseInfluence × BalanceConfig.ipUpgradeBaseInfluenceScale`,
  /// `r = BalanceConfig.ipUpgradeCostMultiplier`, per-level at level L is `B×r^L`
  /// (sum matches `B × r^L × (r^k - 1) / (r - 1)`). Implemented as a [Decimal] sum
  /// to avoid [Rational] from division.
  static Influence leaderHireCost(CountryDef def) {
    return Influence(
      def.baseInfluence * BalanceConfig.leaderHireBaseInfluenceScale,
    );
  }

  /// [fromTier] must be [LeaderTier.tier1] (→ tier2) or [LeaderTier.tier2] (→ tier3).
  static Influence leaderUpgradeCost(CountryDef def, LeaderTier fromTier) {
    final scale = switch (fromTier) {
      LeaderTier.tier1 => BalanceConfig.leaderUpgradeT1T2BaseInfluenceScale,
      LeaderTier.tier2 => BalanceConfig.leaderUpgradeT2T3BaseInfluenceScale,
      _ => throw ArgumentError.value(
        fromTier,
        'fromTier',
        'only tier1 and tier2 can upgrade',
      ),
    };
    return Influence(def.baseInfluence * scale);
  }

  static Influence upgradeCost(CountryDef def, int currentLevel, int bulk) {
    assert(currentLevel >= 0, 'currentLevel must be non-negative');
    assert(bulk >= 1, 'bulk must be at least 1');
    final b = def.baseInfluence * BalanceConfig.ipUpgradeBaseInfluenceScale;
    final r = BalanceConfig.ipUpgradeCostMultiplier;
    var total = Decimal.zero;
    for (var i = 0; i < bulk; i++) {
      final level = currentLevel + i;
      total += b * _powDecimal(r, level);
    }
    return Influence(total);
  }

  static Decimal _powDecimal(Decimal base, int exp) {
    if (exp < 0) {
      throw ArgumentError.value(exp, 'exp', 'must be non-negative');
    }
    if (exp == 0) return Decimal.one;
    var out = Decimal.one;
    for (var i = 0; i < exp; i++) {
      out *= base;
    }
    return out;
  }
}
