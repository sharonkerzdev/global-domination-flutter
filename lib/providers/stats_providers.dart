import 'package:collection/collection.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/features/economy/multiplier_stack_helpers.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/game_providers.dart';

/// Formats a [Decimal] multiplier for Stats rows: trims trailing zeros, no double conversion.
String formatStatMultiplier(Decimal d) {
  var s = d.toString();
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return '$s×';
}

@immutable
class StatsProgressSummary {
  const StatsProgressSummary({
    required this.ownedCountries,
    required this.totalCountries,
    required this.completedContinents,
    required this.totalContinents,
    required this.earnedAchievements,
    required this.totalAchievements,
  });

  final int ownedCountries;
  final int totalCountries;
  final int completedContinents;
  final int totalContinents;
  final int earnedAchievements;
  final int totalAchievements;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StatsProgressSummary &&
          ownedCountries == other.ownedCountries &&
          totalCountries == other.totalCountries &&
          completedContinents == other.completedContinents &&
          totalContinents == other.totalContinents &&
          earnedAchievements == other.earnedAchievements &&
          totalAchievements == other.totalAchievements);

  @override
  int get hashCode => Object.hash(
    ownedCountries,
    totalCountries,
    completedContinents,
    totalContinents,
    earnedAchievements,
    totalAchievements,
  );
}

@immutable
class StatsMultiplierBreakdown {
  const StatsMultiplierBreakdown({
    required this.ipLevelSum,
    required this.ipAdditiveBonus,
    required this.influencePowerFactor,
    required this.leadersHired,
    required this.leaderTier1Count,
    required this.leaderTier2Count,
    required this.leaderTier3Count,
    required this.leaderMultiplierSum,
    required this.continentBonusProduct,
    required this.achievementBonusFactor,
    required this.globalUpgradeProduct,
    required this.goldenOpportunityMultiplier,
    required this.boostMultiplier,
    required this.goldenEffectMultiplier,
  });

  final int ipLevelSum;
  final Decimal ipAdditiveBonus;
  final Decimal influencePowerFactor;
  final int leadersHired;
  final int leaderTier1Count;
  final int leaderTier2Count;
  final int leaderTier3Count;
  final Decimal leaderMultiplierSum;
  final Decimal continentBonusProduct;
  final Decimal achievementBonusFactor;
  final Decimal globalUpgradeProduct;
  final Decimal goldenOpportunityMultiplier;
  final Decimal? boostMultiplier;
  final Decimal? goldenEffectMultiplier;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StatsMultiplierBreakdown &&
          ipLevelSum == other.ipLevelSum &&
          ipAdditiveBonus == other.ipAdditiveBonus &&
          influencePowerFactor == other.influencePowerFactor &&
          leadersHired == other.leadersHired &&
          leaderTier1Count == other.leaderTier1Count &&
          leaderTier2Count == other.leaderTier2Count &&
          leaderTier3Count == other.leaderTier3Count &&
          leaderMultiplierSum == other.leaderMultiplierSum &&
          continentBonusProduct == other.continentBonusProduct &&
          achievementBonusFactor == other.achievementBonusFactor &&
          globalUpgradeProduct == other.globalUpgradeProduct &&
          goldenOpportunityMultiplier == other.goldenOpportunityMultiplier &&
          boostMultiplier == other.boostMultiplier &&
          goldenEffectMultiplier == other.goldenEffectMultiplier);

  @override
  int get hashCode => Object.hashAll([
    ipLevelSum,
    ipAdditiveBonus,
    influencePowerFactor,
    leadersHired,
    leaderTier1Count,
    leaderTier2Count,
    leaderTier3Count,
    leaderMultiplierSum,
    continentBonusProduct,
    achievementBonusFactor,
    globalUpgradeProduct,
    goldenOpportunityMultiplier,
    boostMultiplier,
    goldenEffectMultiplier,
  ]);
}

/// Narrow dependency for multiplier rows: rebuilds only when multiplier-driving slices change.
@immutable
class _StatsMultiplierSlice {
  static const _continentEq = MapEquality<ContinentId, bool>();
  static const _stringSetEq = SetEquality<String>();

  const _StatsMultiplierSlice({
    required this.ipLevelSum,
    required this.leadersHired,
    required this.leaderTier1Count,
    required this.leaderTier2Count,
    required this.leaderTier3Count,
    required this.leaderMultiplierSum,
    required this.continentCompletions,
    required this.earnedAchievementIds,
    required this.activeGlobalUpgradeIds,
    required this.goldenOpportunityMultiplier,
    required this.boostMultiplier,
    required this.goldenEffectMultiplier,
  });

  final int ipLevelSum;
  final int leadersHired;
  final int leaderTier1Count;
  final int leaderTier2Count;
  final int leaderTier3Count;
  final Decimal leaderMultiplierSum;
  final Map<ContinentId, bool> continentCompletions;
  final Set<String> earnedAchievementIds;
  final Set<String> activeGlobalUpgradeIds;
  final Decimal goldenOpportunityMultiplier;
  final Decimal? boostMultiplier;
  final int? goldenEffectMultiplier;

  static _StatsMultiplierSlice fromState(GameState s) {
    var ipSum = 0;
    var hired = 0;
    var t1 = 0;
    var t2 = 0;
    var t3 = 0;
    var leaderSum = Decimal.zero;
    for (final c in s.countries.values) {
      if (!c.unlocked) continue;
      ipSum += c.ipLevel;
      if (c.leaderTier != LeaderTier.none) {
        hired++;
        leaderSum += BalanceConfig.leaderMultiplier(c.leaderTier);
        switch (c.leaderTier) {
          case LeaderTier.none:
            break;
          case LeaderTier.tier1:
            t1++;
            break;
          case LeaderTier.tier2:
            t2++;
            break;
          case LeaderTier.tier3:
            t3++;
            break;
        }
      }
    }
    return _StatsMultiplierSlice(
      ipLevelSum: ipSum,
      leadersHired: hired,
      leaderTier1Count: t1,
      leaderTier2Count: t2,
      leaderTier3Count: t3,
      leaderMultiplierSum: leaderSum,
      continentCompletions: Map<ContinentId, bool>.unmodifiable({
        ...s.continentCompletions,
      }),
      earnedAchievementIds: Set<String>.unmodifiable({
        ...s.earnedAchievementIds,
      }),
      activeGlobalUpgradeIds: Set<String>.unmodifiable({
        ...s.activeGlobalUpgradeIds,
      }),
      goldenOpportunityMultiplier: s.goldenOpportunityMultiplier,
      boostMultiplier: s.activeBoost?.multiplier,
      goldenEffectMultiplier: s.activeGoldenEffect?.multiplier,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _StatsMultiplierSlice &&
          ipLevelSum == other.ipLevelSum &&
          leadersHired == other.leadersHired &&
          leaderTier1Count == other.leaderTier1Count &&
          leaderTier2Count == other.leaderTier2Count &&
          leaderTier3Count == other.leaderTier3Count &&
          leaderMultiplierSum == other.leaderMultiplierSum &&
          _continentEq.equals(
            continentCompletions,
            other.continentCompletions,
          ) &&
          _stringSetEq.equals(
            earnedAchievementIds,
            other.earnedAchievementIds,
          ) &&
          _stringSetEq.equals(
            activeGlobalUpgradeIds,
            other.activeGlobalUpgradeIds,
          ) &&
          goldenOpportunityMultiplier == other.goldenOpportunityMultiplier &&
          boostMultiplier == other.boostMultiplier &&
          goldenEffectMultiplier == other.goldenEffectMultiplier);

  @override
  int get hashCode => Object.hash(
    ipLevelSum,
    leadersHired,
    leaderTier1Count,
    leaderTier2Count,
    leaderTier3Count,
    leaderMultiplierSum,
    _continentEq.hash(continentCompletions),
    _stringSetEq.hash(earnedAchievementIds),
    _stringSetEq.hash(activeGlobalUpgradeIds),
    goldenOpportunityMultiplier,
    boostMultiplier,
    goldenEffectMultiplier,
  );
}

final statsProgressSummaryProvider = Provider<StatsProgressSummary?>((ref) {
  final content = ref.watch(contentRegistryProvider).valueOrNull;
  if (content == null) return null;

  final ownedCountries = ref.watch(
    gameWorldProvider.select(
      (s) => s.countries.values.where((c) => c.unlocked).length,
    ),
  );
  final completedContinents = ref.watch(
    gameWorldProvider.select(
      (s) => s.continentCompletions.values.where((v) => v).length,
    ),
  );
  final earnedAchievements = ref.watch(
    gameWorldProvider.select((s) => s.earnedAchievementIds.length),
  );

  return StatsProgressSummary(
    ownedCountries: ownedCountries,
    totalCountries: content.countries.length,
    completedContinents: completedContinents,
    totalContinents: content.continents.length,
    earnedAchievements: earnedAchievements,
    totalAchievements: content.achievements.length,
  );
});

final statsMultiplierBreakdownProvider = Provider<StatsMultiplierBreakdown?>((
  ref,
) {
  final content = ref.watch(contentRegistryProvider).valueOrNull;
  if (content == null) return null;

  final slice = ref.watch(
    gameWorldProvider.select(_StatsMultiplierSlice.fromState),
  );

  final ipAdditive =
      Decimal.fromInt(slice.ipLevelSum) * BalanceConfig.ipMultPerLevel;
  final influencePower = Decimal.one + ipAdditive;

  final continentProduct =
      MultiplierStackHelpers.continentCompletionProductForMap(
        slice.continentCompletions,
        content,
      );

  final achievementFactor =
      MultiplierStackHelpers.achievementInfluenceFactorForIds(
        slice.earnedAchievementIds,
        content,
      );
  final globalProduct = MultiplierStackHelpers.globalUpgradeProductForIds(
    slice.activeGlobalUpgradeIds,
    content,
  );

  final effectDecimal = slice.goldenEffectMultiplier == null
      ? null
      : Decimal.fromInt(slice.goldenEffectMultiplier!);

  return StatsMultiplierBreakdown(
    ipLevelSum: slice.ipLevelSum,
    ipAdditiveBonus: ipAdditive,
    influencePowerFactor: influencePower,
    leadersHired: slice.leadersHired,
    leaderTier1Count: slice.leaderTier1Count,
    leaderTier2Count: slice.leaderTier2Count,
    leaderTier3Count: slice.leaderTier3Count,
    leaderMultiplierSum: slice.leaderMultiplierSum,
    continentBonusProduct: continentProduct,
    achievementBonusFactor: achievementFactor,
    globalUpgradeProduct: globalProduct,
    goldenOpportunityMultiplier: slice.goldenOpportunityMultiplier,
    boostMultiplier: slice.boostMultiplier,
    goldenEffectMultiplier: effectDecimal,
  );
});
