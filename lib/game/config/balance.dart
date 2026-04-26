import 'package:decimal/decimal.dart';

import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/values/intel.dart';

/// Balance constants. Values pinned here are placeholders until Epic 10 final
/// tuning pass. Re-tuning changes happen ONLY in this file + content JSON.
abstract final class BalanceConfig {
  /// Per-level cost multiplier for IP upgrades (1.5^L curve); Epic 10 retune target.
  static final Decimal ipUpgradeCostMultiplier = Decimal.parse('1.5');

  /// B in `cost = B × 1.5^L` — `B = baseInfluence ×` this (Epic 10 may split `baseCost`).
  static final Decimal ipUpgradeBaseInfluenceScale = Decimal.fromInt(10);

  static const int maxIpLevel = 200;

  /// Placeholder — Epic 10 retunes; do not change here without Epic 10 coordination.
  static final Decimal ipMultPerLevel = Decimal.parse('0.1');

  /// Raw table is const [String]; parse to [Decimal] at lookup time.
  static const Map<LeaderTier, String> leaderMultipliers = {
    LeaderTier.none: '1.0',
    LeaderTier.tier1: '1.5',
    LeaderTier.tier2: '2.0',
    LeaderTier.tier3: '3.0',
  };

  static Decimal leaderMultiplier(LeaderTier tier) =>
      Decimal.parse(leaderMultipliers[tier]!);

  /// Minimum IP level to hire a leader.
  static const int leaderHireMinIpLevel = 10;

  /// `hireCost = def.baseInfluence ×` this — Epic 10 may retune.
  static final Decimal leaderHireBaseInfluenceScale = Decimal.fromInt(500);

  /// Tier 1 → 2: `def.baseInfluence ×` this.
  static final Decimal leaderUpgradeT1T2BaseInfluenceScale = Decimal.fromInt(
    750,
  );

  /// Tier 2 → 3: `def.baseInfluence ×` this.
  static final Decimal leaderUpgradeT2T3BaseInfluenceScale = Decimal.fromInt(
    1000,
  );

  /// Probability of attempting a Golden spawn per real wall-clock second of tick time.
  /// Per-tick draw: rng.nextDouble() < goldenSpawnProbabilityPerSecond × dtSeconds.
  /// Placeholder — Epic 10 retunes (target ~1 spawn per 30s of active play).
  static final Decimal goldenSpawnProbabilityPerSecond = Decimal.parse(
    '0.0333',
  );

  /// Inclusive lower bound for the random multiplier on a spawned Golden.
  static const int goldenMinMultiplier = 10;

  /// Inclusive upper bound for the random multiplier on a spawned Golden.
  static const int goldenMaxMultiplier = 100;

  /// Hard cap on simultaneous active Goldens on the map. Prevents pathological
  /// spawn streaks from cluttering the map; Epic 10 may retune.
  static const int goldenMaxConcurrent = 3;

  /// Seconds an unclaimed Golden remains on the map before despawning.
  static const int goldenSpawnExpirySeconds = 10;

  /// Seconds the post-claim multiplier burst remains active.
  static const int goldenEffectDurationSeconds = 30;

  /// Intel cost to activate the time-limited income boost. Epic 10 retunes; do
  /// not change here without Epic 10 coordination.
  static final Intel boostCost = Intel(Decimal.fromInt(100));

  /// Active boost income multiplier (e.g. 2×). Epic 10 retunes; do not change
  /// here without Epic 10 coordination.
  static final Decimal boostMultiplier = Decimal.parse('2.0');

  /// Wall-clock duration of the boost. Epic 10 retunes; do not change here
  /// without Epic 10 coordination.
  static const int boostDurationSeconds = 30;

  /// Concurrent mission slots shown in the Missions UI. Epic 10 may retune.
  static const int missionCatalogSize = 3;
}
