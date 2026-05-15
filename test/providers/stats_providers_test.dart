import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/boosts/boost_state.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/stats_providers.dart';

import '../helpers/achievements_fixture.dart';
import '../helpers/daily_rewards_test_json.dart';
import '../helpers/game_state_builder.dart';
import '../helpers/test_content_registry.dart';

class _TestGameWorldNotifier extends GameWorldNotifier {
  _TestGameWorldNotifier({
    required ContentRegistry content,
    required GameState initialState,
  }) : super(
         GameWorld(
           content: content,
           clock: const SystemClock(),
           rng: SeededRng(0),
           initialState: initialState,
         ),
       );

  void setTestState(GameState s) {
    state = s;
  }
}

ContentRegistry _content79Countries() {
  const continents = '''
[
  {"id":"africa","name":"Africa","unlockThreshold":"0","completionBonus":"0.25","milestoneRewards":[]},
  {"id":"europe","name":"Europe","unlockThreshold":"0","completionBonus":"0.50","milestoneRewards":[]}
]''';
  final countryObjs = <Map<String, Object>>[];
  for (var i = 0; i < 79; i++) {
    countryObjs.add({
      'id': 'c$i',
      'continent': 'africa',
      'baseInfluence': '1',
      'unlockCost': '0',
      'tier': 1,
      'generationSeconds': 1,
    });
  }
  final countries = jsonEncode(countryObjs);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: '[]',
    achievementsJson: trivial27AchievementsJson(),
    missionsJson: '[]',
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

void main() {
  group('statsProgressSummaryProvider', () {
    test(
      'counts and denominators from content (3-country mapper fixture)',
      () async {
        final content = testMapperContentRegistry();
        final notifier = _TestGameWorldNotifier(
          content: content,
          initialState: GameState(
            countries: {
              for (final id in content.countries.keys)
                id: CountryState(
                  id: id,
                  unlocked: true,
                  ipLevel: 1,
                  leaderTier: LeaderTier.none,
                  bankedInfluence: Influence.zero,
                ),
            },
            continentCompletions: {const ContinentId('africa'): true},
            earnedAchievementIds: {'ach_fixture_inert_0'},
          ),
        );
        final container = ProviderContainer(
          overrides: [
            contentRegistryProvider.overrideWith((_) async => content),
            gameWorldProvider.overrideWith((_) => notifier),
          ],
        );
        addTearDown(container.dispose);
        await container.read(contentRegistryProvider.future);

        final s = container.read(statsProgressSummaryProvider)!;
        expect(s.totalCountries, 3);
        expect(s.ownedCountries, 3);
        expect(s.totalContinents, 2);
        expect(s.completedContinents, 1);
        expect(s.totalAchievements, 27);
        expect(s.earnedAchievements, 1);
      },
    );

    test(
      '79-country content shows denominator 79 without UI hardcode',
      () async {
        final content = _content79Countries();
        final notifier = _TestGameWorldNotifier(
          content: content,
          initialState: GameState(
            countries: {
              const CountryId('c0'): CountryState(
                id: const CountryId('c0'),
                unlocked: true,
                ipLevel: 0,
                leaderTier: LeaderTier.none,
                bankedInfluence: Influence.zero,
              ),
            },
          ),
        );
        final container = ProviderContainer(
          overrides: [
            contentRegistryProvider.overrideWith((_) async => content),
            gameWorldProvider.overrideWith((_) => notifier),
          ],
        );
        addTearDown(container.dispose);
        await container.read(contentRegistryProvider.future);

        final s = container.read(statsProgressSummaryProvider)!;
        expect(s.totalCountries, 79);
        expect(s.ownedCountries, 1);
      },
    );
  });

  group('statsMultiplierBreakdownProvider', () {
    test('IP sum uses unlocked countries only', () async {
      final content = testMapperContentRegistry();
      const egypt = CountryId('egypt');
      const nigeria = CountryId('nigeria');
      final notifier = _TestGameWorldNotifier(
        content: content,
        initialState: GameState(
          countries: {
            egypt: CountryState(
              id: egypt,
              unlocked: true,
              ipLevel: 3,
              leaderTier: LeaderTier.none,
              bankedInfluence: Influence.zero,
            ),
            nigeria: CountryState(
              id: nigeria,
              unlocked: false,
              ipLevel: 99,
              leaderTier: LeaderTier.none,
              bankedInfluence: Influence.zero,
            ),
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          contentRegistryProvider.overrideWith((_) async => content),
          gameWorldProvider.overrideWith((_) => notifier),
        ],
      );
      addTearDown(container.dispose);
      await container.read(contentRegistryProvider.future);

      final m = container.read(statsMultiplierBreakdownProvider)!;
      expect(m.ipLevelSum, 3);
      expect(
        m.influencePowerFactor,
        Decimal.one + Decimal.fromInt(3) * BalanceConfig.ipMultPerLevel,
      );
    });

    test('leader tiers and multiplier sum', () async {
      final content = testMapperContentRegistry();
      final notifier = _TestGameWorldNotifier(
        content: content,
        initialState: GameState(
          countries: {
            const CountryId('egypt'): CountryState(
              id: const CountryId('egypt'),
              unlocked: true,
              ipLevel: 1,
              leaderTier: LeaderTier.tier1,
              bankedInfluence: Influence.zero,
            ),
            const CountryId('nigeria'): CountryState(
              id: const CountryId('nigeria'),
              unlocked: true,
              ipLevel: 1,
              leaderTier: LeaderTier.tier2,
              bankedInfluence: Influence.zero,
            ),
            const CountryId('france'): CountryState(
              id: const CountryId('france'),
              unlocked: true,
              ipLevel: 1,
              leaderTier: LeaderTier.tier3,
              bankedInfluence: Influence.zero,
            ),
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          contentRegistryProvider.overrideWith((_) async => content),
          gameWorldProvider.overrideWith((_) => notifier),
        ],
      );
      addTearDown(container.dispose);
      await container.read(contentRegistryProvider.future);

      final m = container.read(statsMultiplierBreakdownProvider)!;
      expect(m.leadersHired, 3);
      expect(m.leaderTier1Count, 1);
      expect(m.leaderTier2Count, 1);
      expect(m.leaderTier3Count, 1);
      expect(
        m.leaderMultiplierSum,
        BalanceConfig.leaderMultiplier(LeaderTier.tier1) +
            BalanceConfig.leaderMultiplier(LeaderTier.tier2) +
            BalanceConfig.leaderMultiplier(LeaderTier.tier3),
      );
    });

    test('continent product ignores missing ids', () async {
      final content = testMapperContentRegistry();
      final notifier = _TestGameWorldNotifier(
        content: content,
        initialState: GameState(
          continentCompletions: {
            const ContinentId('africa'): true,
            const ContinentId('phantom'): true,
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          contentRegistryProvider.overrideWith((_) async => content),
          gameWorldProvider.overrideWith((_) => notifier),
        ],
      );
      addTearDown(container.dispose);
      await container.read(contentRegistryProvider.future);

      final m = container.read(statsMultiplierBreakdownProvider)!;
      expect(m.continentBonusProduct, Decimal.one + Decimal.parse('0.25'));
    });

    test('achievement factor uses influenceMultiplier only', () async {
      final achievementsJson = achievementsJson27([
        {
          'id': 'ach_inf',
          'name': 'Inf',
          'conditionType': 'countriesUnlockedAtLeast',
          'conditionParams': {'count': 1},
          'rewardType': 'influenceMultiplier',
          'rewardValue': '0.05',
        },
        {
          'id': 'ach_intel',
          'name': 'Intel',
          'conditionType': 'countriesUnlockedAtLeast',
          'conditionParams': {'count': 1},
          'rewardType': 'intel',
          'rewardValue': '50',
        },
      ]);
      final content = ContentRegistry.fromJsonStrings(
        countriesJson:
            '[{"id":"egypt","continent":"africa","baseInfluence":"1","unlockCost":"0","tier":1,"generationSeconds":1}]',
        continentsJson:
            '[{"id":"africa","name":"Africa","unlockThreshold":"0","completionBonus":"0","milestoneRewards":[]}]',
        leadersJson: '[]',
        achievementsJson: achievementsJson,
        missionsJson: '[]',
        globalUpgradesJson: '[]',
        dailyRewardsJson: testDailyRewardsJson(),
      );
      final notifier = _TestGameWorldNotifier(
        content: content,
        initialState: GameState(
          countries: {
            const CountryId('egypt'): CountryState(
              id: const CountryId('egypt'),
              unlocked: true,
              ipLevel: 0,
              leaderTier: LeaderTier.none,
              bankedInfluence: Influence.zero,
            ),
          },
          earnedAchievementIds: {'ach_inf', 'ach_intel'},
        ),
      );
      final container = ProviderContainer(
        overrides: [
          contentRegistryProvider.overrideWith((_) async => content),
          gameWorldProvider.overrideWith((_) => notifier),
        ],
      );
      addTearDown(container.dispose);
      await container.read(contentRegistryProvider.future);

      final m = container.read(statsMultiplierBreakdownProvider)!;
      expect(m.achievementBonusFactor, Decimal.one + Decimal.parse('0.05'));
    });

    test(
      'global upgrade product defaults to 1 and multiplies known ids',
      () async {
        final content = testMapperContentRegistry();
        final notifier = _TestGameWorldNotifier(
          content: content,
          initialState: GameState(
            activeGlobalUpgradeIds: {'gu_fixture', 'missing_gu'},
          ),
        );
        final container = ProviderContainer(
          overrides: [
            contentRegistryProvider.overrideWith((_) async => content),
            gameWorldProvider.overrideWith((_) => notifier),
          ],
        );
        addTearDown(container.dispose);
        await container.read(contentRegistryProvider.future);

        final m = container.read(statsMultiplierBreakdownProvider)!;
        expect(m.globalUpgradeProduct, Decimal.parse('1.1'));
      },
    );

    test('temporary boost and golden fields surface in breakdown', () async {
      final content = testMapperContentRegistry();
      final t = DateTime.utc(2026, 4, 28);
      final notifier = _TestGameWorldNotifier(
        content: content,
        initialState: GameState(
          goldenOpportunityMultiplier: Decimal.parse('12'),
          activeBoost: BoostState(
            multiplier: BalanceConfig.boostMultiplier,
            expiresAt: t.add(const Duration(seconds: 10)),
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          contentRegistryProvider.overrideWith((_) async => content),
          gameWorldProvider.overrideWith((_) => notifier),
        ],
      );
      addTearDown(container.dispose);
      await container.read(contentRegistryProvider.future);

      final m = container.read(statsMultiplierBreakdownProvider)!;
      expect(m.goldenOpportunityMultiplier, Decimal.parse('12'));
      expect(m.boostMultiplier, BalanceConfig.boostMultiplier);
    });

    test(
      'fully populated fixture matches continent and achievement helpers',
      () async {
        final content = testMapperContentRegistry();
        final notifier = _TestGameWorldNotifier(
          content: content,
          initialState: GameStateBuilder.fullyPopulated(
            content: content,
            savedAtUtc: DateTime.utc(2026, 4, 28),
          ),
        );
        final container = ProviderContainer(
          overrides: [
            contentRegistryProvider.overrideWith((_) async => content),
            gameWorldProvider.overrideWith((_) => notifier),
          ],
        );
        addTearDown(container.dispose);
        await container.read(contentRegistryProvider.future);

        final m = container.read(statsMultiplierBreakdownProvider)!;
        expect(m.continentBonusProduct, Decimal.one + Decimal.parse('0.25'));
        expect(m.boostMultiplier, isNotNull);
        expect(m.goldenEffectMultiplier, isNotNull);
      },
    );

    test(
      'intel-only state change does not notify statsMultiplierBreakdown',
      () async {
        final content = testMapperContentRegistry();
        final base = GameState(
          countries: {
            const CountryId('egypt'): CountryState(
              id: const CountryId('egypt'),
              unlocked: true,
              ipLevel: 2,
              leaderTier: LeaderTier.none,
              bankedInfluence: Influence.zero,
            ),
          },
          totalInfluence: Influence(Decimal.parse('10')),
          totalIntel: Intel(Decimal.parse('1')),
        );
        final notifier = _TestGameWorldNotifier(
          content: content,
          initialState: base,
        );
        final container = ProviderContainer(
          overrides: [
            contentRegistryProvider.overrideWith((_) async => content),
            gameWorldProvider.overrideWith((_) => notifier),
          ],
        );
        addTearDown(container.dispose);
        await container.read(contentRegistryProvider.future);

        var builds = 0;
        container.listen(
          statsMultiplierBreakdownProvider,
          (prev, next) => builds++,
          fireImmediately: true,
        );
        expect(builds, 1);

        notifier.setTestState(
          base.copyWith(totalIntel: Intel(Decimal.parse('99'))),
        );
        expect(builds, 1);
      },
    );

    test(
      'influence-only state change does not notify statsMultiplierBreakdown',
      () async {
        final content = testMapperContentRegistry();
        final base = GameState(
          countries: {
            const CountryId('egypt'): CountryState(
              id: const CountryId('egypt'),
              unlocked: true,
              ipLevel: 2,
              leaderTier: LeaderTier.none,
              bankedInfluence: Influence.zero,
            ),
          },
          totalInfluence: Influence(Decimal.parse('10')),
          totalIntel: Intel(Decimal.parse('1')),
        );
        final notifier = _TestGameWorldNotifier(
          content: content,
          initialState: base,
        );
        final container = ProviderContainer(
          overrides: [
            contentRegistryProvider.overrideWith((_) async => content),
            gameWorldProvider.overrideWith((_) => notifier),
          ],
        );
        addTearDown(container.dispose);
        await container.read(contentRegistryProvider.future);

        var builds = 0;
        container.listen(
          statsMultiplierBreakdownProvider,
          (prev, next) => builds++,
          fireImmediately: true,
        );
        expect(builds, 1);

        notifier.setTestState(
          base.copyWith(totalInfluence: Influence(Decimal.parse('999'))),
        );
        expect(builds, 1);
      },
    );
  });
}
