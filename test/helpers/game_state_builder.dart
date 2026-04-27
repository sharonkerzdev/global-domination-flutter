import 'package:decimal/decimal.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/boosts/boost_state.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/daily_rewards/daily_streak.dart';
import 'package:global_domination/game/features/goldens/active_golden.dart';
import 'package:global_domination/game/features/goldens/active_golden_effect.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/features/missions/mission_state.dart';
import 'package:global_domination/game/features/missions/missions_seed.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';

/// Canonical rich [GameState] for persistence / mapper tests.
class GameStateBuilder {
  /// Non-trivial state covering every v3-persisted slice (see Story 6-1 AC #5).
  static GameState fullyPopulated({
    required ContentRegistry content,
    required DateTime savedAtUtc,
  }) {
    assert(savedAtUtc.isUtc);
    final sortedCountryIds = content.countries.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final countries = <CountryId, CountryState>{};
    for (var i = 0; i < sortedCountryIds.length; i++) {
      final id = sortedCountryIds[i];
      final tier = LeaderTier.values[i % LeaderTier.values.length];
      countries[id] = CountryState(
        id: id,
        unlocked: true,
        ipLevel: i + 1,
        leaderTier: tier,
        bankedInfluence: Influence(Decimal.fromInt(10 * (i + 1))),
        lastCollectedAt: i.isEven ? null : savedAtUtc,
      );
    }

    const africa = ContinentId('africa');
    const europe = ContinentId('europe');
    final missionSeed = seedActiveMissions(content);
    final activeMissions = <MissionState>[
      for (var i = 0; i < missionSeed.length; i++)
        missionSeed[i].copyWith(progress: i + 1),
    ];

    return GameState(
      countries: countries,
      totalInfluence: Influence(Decimal.parse('999.5')),
      totalIntel: Intel(Decimal.parse('321.75')),
      dailyStreak: DailyStreak(
        day: 3,
        lastClaimDate: savedAtUtc.subtract(const Duration(days: 1)),
      ),
      activeMissions: activeMissions,
      completedMissionIds: const {'m_prior_done'},
      unlockedContinents: {africa: true, europe: true},
      reachedMilestones: {
        africa: {25, 50, 75, 100},
        europe: {25},
      },
      continentCompletions: {africa: true},
      earnedAchievementIds: const {
        'ach_fixture_inert_0',
        'ach_fixture_inert_1',
      },
      activeGlobalUpgradeIds: const {'gu_fixture'},
      goldenOpportunityMultiplier: Decimal.parse('10'),
      activeBoost: BoostState(
        multiplier: BalanceConfig.boostMultiplier,
        expiresAt: savedAtUtc.add(const Duration(seconds: 30)),
      ),
      activeGoldens: {
        'g1': ActiveGolden(
          id: 'g1',
          countryId: const CountryId('egypt'),
          multiplier: 20,
          expiresAt: savedAtUtc,
        ),
        'g2': ActiveGolden(
          id: 'g2',
          countryId: const CountryId('nigeria'),
          multiplier: 30,
          expiresAt: savedAtUtc,
        ),
        'g3': ActiveGolden(
          id: 'g3',
          countryId: const CountryId('france'),
          multiplier: 40,
          expiresAt: savedAtUtc,
        ),
      },
      activeGoldenEffect: ActiveGoldenEffect(
        goldenId: 'g1',
        multiplier: 15,
        expiresAt: savedAtUtc,
      ),
    );
  }
}
