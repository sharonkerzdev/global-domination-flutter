import 'package:decimal/decimal.dart';

import 'package:global_domination/game/config/constants.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/economy/income_calculator.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/influence.dart';

/// Result of applying offline elapsed time to [GameState] without tick/mission side
/// effects.
class OfflineCatchupResult {
  const OfflineCatchupResult({
    required this.state,
    required this.elapsed,
    required this.totalEarned,
    required this.event,
  });

  final GameState state;
  final Duration elapsed;
  final Influence totalEarned;
  final OfflineEarningsApplied? event;

  bool get emittedEvent => event != null;
}

abstract final class OfflineCatchup {
  /// Computes offline influence from [lastSavedAt] to [now], capped at
  /// [GameConstants.maxOfflineHours]. Transient boost/golden multipliers are
  /// excluded; IP/leader/continent/achievement/global-upgrade stacks apply via
  /// [IncomeCalculator] on a stable state copy.
  static OfflineCatchupResult apply(
    GameState state,
    ContentRegistry content, {
    required DateTime now,
    required DateTime lastSavedAt,
  }) {
    final nowUtc = now.toUtc();
    final savedAtUtc = lastSavedAt.toUtc();
    final rawElapsed = nowUtc.difference(savedAtUtc);
    if (rawElapsed <= Duration.zero) {
      return OfflineCatchupResult(
        state: state,
        elapsed: Duration.zero,
        totalEarned: Influence.zero,
        event: null,
      );
    }

    final cap = Duration(hours: GameConstants.maxOfflineHours);
    final elapsed = rawElapsed > cap ? cap : rawElapsed;

    final stableState = state.copyWith(
      goldenOpportunityMultiplier: Decimal.one,
      activeBoost: null,
      activeGoldenEffect: null,
    );

    Influence totalEarned = Influence.zero;
    for (final country in stableState.countries.values) {
      if (!country.unlocked || country.leaderTier == LeaderTier.none) {
        continue;
      }
      final rate = IncomeCalculator.compute(country, stableState, content);
      totalEarned += rate * Decimal.fromInt(elapsed.inSeconds);
    }

    final newState = state.copyWith(
      totalInfluence: state.totalInfluence + totalEarned,
    );

    final event = OfflineEarningsApplied(
      nowUtc,
      totalEarned: totalEarned,
      elapsed: elapsed,
    );

    return OfflineCatchupResult(
      state: newState,
      elapsed: elapsed,
      totalEarned: totalEarned,
      event: event,
    );
  }
}
