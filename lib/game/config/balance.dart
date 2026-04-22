import 'package:decimal/decimal.dart';

import 'package:global_domination/game/features/leaders/leader_tier.dart';

/// Balance constants. Values pinned here are placeholders until Epic 10 final
/// tuning pass. Re-tuning changes happen ONLY in this file + content JSON.
abstract final class BalanceConfig {
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
}
