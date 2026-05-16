import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/continent_progress_providers.dart';
import 'package:global_domination/providers/game_providers.dart';

import '../helpers/achievements_fixture.dart';
import '../helpers/daily_rewards_test_json.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

ContentRegistry _twoContinent({
  String africaUnlockThreshold = '0',
  String europeUnlockThreshold = '1000',
}) {
  final continents = jsonEncode([
    {
      'id': 'africa',
      'name': 'Africa',
      'unlockThreshold': africaUnlockThreshold,
      'completionBonus': '0.25',
      'milestoneRewards': [
        {'percent': 25, 'rewardType': 'influence', 'rewardValue': '0'},
        {'percent': 50, 'rewardType': 'influence', 'rewardValue': '0'},
        {'percent': 75, 'rewardType': 'influence', 'rewardValue': '0'},
        {'percent': 100, 'rewardType': 'influence', 'rewardValue': '0'},
      ],
    },
    {
      'id': 'europe',
      'name': 'Europe',
      'unlockThreshold': europeUnlockThreshold,
      'completionBonus': '0.50',
      'milestoneRewards': <dynamic>[],
    },
  ]);
  final countries = jsonEncode([
    {
      'id': 'egypt',
      'continent': 'africa',
      'baseInfluence': '1',
      'unlockCost': '0',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'nigeria',
      'continent': 'africa',
      'baseInfluence': '5',
      'unlockCost': '10',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'south_africa',
      'continent': 'africa',
      'baseInfluence': '4',
      'unlockCost': '20',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'france',
      'continent': 'europe',
      'baseInfluence': '2',
      'unlockCost': '20',
      'tier': 1,
      'generationSeconds': 1,
    },
  ]);
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

class _SpyNotifier extends GameWorldNotifier {
  _SpyNotifier({
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

  void setTestState(GameState next) {
    state = next;
  }
}

ProviderContainer _container(ContentRegistry content, GameState state) {
  final notifier = _SpyNotifier(content: content, initialState: state);
  final container = ProviderContainer(
    overrides: [
      contentRegistryProvider.overrideWith((_) async => content),
      gameWorldProvider.overrideWith((_) => notifier),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

CountryState _unlocked(String id) => CountryState(
  id: CountryId(id),
  unlocked: true,
  ipLevel: 1,
  leaderTier: LeaderTier.none,
  bankedInfluence: Influence.zero,
);

CountryState _locked(String id) => CountryState(
  id: CountryId(id),
  unlocked: false,
  ipLevel: 0,
  leaderTier: LeaderTier.none,
  bankedInfluence: Influence.zero,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const africa = ContinentId('africa');
  const europe = ContinentId('europe');
  const egypt = CountryId('egypt');
  const nigeria = CountryId('nigeria');
  const southAfrica = CountryId('south_africa');
  const france = CountryId('france');

  group('continentProgressRowsProvider', () {
    test('returns null when content is loading', () {
      final content = _twoContinent();
      final container = ProviderContainer(
        overrides: [
          // Override with a Future that never completes — simulates loading.
          contentRegistryProvider.overrideWith(
            (_) => Future<ContentRegistry>.delayed(const Duration(days: 9999)),
          ),
          gameWorldProvider.overrideWith(
            (_) => _SpyNotifier(content: content, initialState: GameState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final rows = container.read(continentProgressRowsProvider);
      expect(rows, isNull);
    });

    test('returns empty list when no continents are unlocked', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          egypt: _locked('egypt'),
          nigeria: _locked('nigeria'),
          southAfrica: _locked('south_africa'),
          france: _locked('france'),
        },
        unlockedContinents: {},
        totalInfluence: Influence(Decimal.parse('0')),
      );
      final container = _container(content, state);
      await container.read(contentRegistryProvider.future);

      final rows = container.read(continentProgressRowsProvider);
      expect(rows, isNotNull);
      expect(rows!, isEmpty);
    });

    test(
      'single continent: Africa unlocked with 1 of 3 owned, no milestones',
      () async {
        final content = _twoContinent();
        final state = GameState(
          countries: {
            egypt: _unlocked('egypt'),
            nigeria: _locked('nigeria'),
            southAfrica: _locked('south_africa'),
            france: _locked('france'),
          },
          unlockedContinents: {africa: true},
          reachedMilestones: const {},
          totalInfluence: Influence(Decimal.parse('0')),
        );
        final container = _container(content, state);
        await container.read(contentRegistryProvider.future);

        final rows = container.read(continentProgressRowsProvider);
        expect(rows, isNotNull);
        expect(rows!.length, 1);
        final row = rows.first;
        expect(row.continentId, africa);
        expect(row.ownedCount, 1);
        expect(row.totalCount, 3);
        expect(row.reachedMilestoneTiers, isEmpty);
        expect(row.highestReachedTier, 0);
      },
    );

    test('tier-25 reached: highestReachedTier is 25', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          egypt: _unlocked('egypt'),
          nigeria: _locked('nigeria'),
          southAfrica: _locked('south_africa'),
          france: _locked('france'),
        },
        unlockedContinents: {africa: true},
        reachedMilestones: {
          africa: {25},
        },
        totalInfluence: Influence(Decimal.parse('0')),
      );
      final container = _container(content, state);
      await container.read(contentRegistryProvider.future);

      final rows = container.read(continentProgressRowsProvider);
      expect(rows!.first.highestReachedTier, 25);
      expect(rows.first.reachedMilestoneTiers, {25});
    });

    test('multi-tier: {25, 50, 75} → highestReachedTier is 75', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          egypt: _unlocked('egypt'),
          nigeria: _unlocked('nigeria'),
          southAfrica: _unlocked('south_africa'),
          france: _locked('france'),
        },
        unlockedContinents: {africa: true},
        reachedMilestones: {
          africa: {25, 50, 75},
        },
        totalInfluence: Influence(Decimal.parse('0')),
      );
      final container = _container(content, state);
      await container.read(contentRegistryProvider.future);

      final rows = container.read(continentProgressRowsProvider);
      expect(rows!.first.highestReachedTier, 75);
      expect(rows.first.reachedMilestoneTiers, {25, 50, 75});
    });

    test('100% reached: all tiers, highestReachedTier is 100', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          egypt: _unlocked('egypt'),
          nigeria: _unlocked('nigeria'),
          southAfrica: _unlocked('south_africa'),
          france: _locked('france'),
        },
        unlockedContinents: {africa: true},
        reachedMilestones: {
          africa: {25, 50, 75, 100},
        },
        totalInfluence: Influence(Decimal.parse('0')),
      );
      final container = _container(content, state);
      await container.read(contentRegistryProvider.future);

      final rows = container.read(continentProgressRowsProvider);
      expect(rows!.first.highestReachedTier, 100);
      expect(rows.first.reachedMilestoneTiers, {25, 50, 75, 100});
    });

    test('locked continent is omitted from the list', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          egypt: _unlocked('egypt'),
          nigeria: _locked('nigeria'),
          southAfrica: _locked('south_africa'),
          france: _locked('france'),
        },
        unlockedContinents: {africa: true, europe: false},
        totalInfluence: Influence(Decimal.parse('0')),
      );
      final container = _container(content, state);
      await container.read(contentRegistryProvider.future);

      final rows = container.read(continentProgressRowsProvider);
      expect(rows!.length, 1);
      expect(rows.first.continentId, africa);
    });

    test(
      'ordering: unlockThreshold ascending (Africa before Europe)',
      () async {
        final content = _twoContinent(
          africaUnlockThreshold: '0',
          europeUnlockThreshold: '1000',
        );
        final state = GameState(
          countries: {
            egypt: _unlocked('egypt'),
            nigeria: _locked('nigeria'),
            southAfrica: _locked('south_africa'),
            france: _unlocked('france'),
          },
          unlockedContinents: {africa: true, europe: true},
          totalInfluence: Influence(Decimal.parse('0')),
        );
        final container = _container(content, state);
        await container.read(contentRegistryProvider.future);

        final rows = container.read(continentProgressRowsProvider);
        expect(rows!.length, 2);
        expect(rows[0].continentId, africa);
        expect(rows[1].continentId, europe);
      },
    );

    test('degenerate empty continent (zero countries) is skipped', () async {
      // Build a content with a continent that has no countries.
      final continents = jsonEncode([
        {
          'id': 'africa',
          'name': 'Africa',
          'unlockThreshold': '0',
          'completionBonus': '0.25',
          'milestoneRewards': <dynamic>[],
        },
        {
          'id': 'empty_continent',
          'name': 'Empty',
          'unlockThreshold': '0',
          'completionBonus': '0.0',
          'milestoneRewards': <dynamic>[],
        },
      ]);
      final countries = jsonEncode([
        {
          'id': 'egypt',
          'continent': 'africa',
          'baseInfluence': '1',
          'unlockCost': '0',
          'tier': 1,
          'generationSeconds': 1,
        },
      ]);
      final content = ContentRegistry.fromJsonStrings(
        countriesJson: countries,
        continentsJson: continents,
        leadersJson: '[]',
        achievementsJson: trivial27AchievementsJson(),
        missionsJson: '[]',
        globalUpgradesJson: '[]',
        dailyRewardsJson: testDailyRewardsJson(),
      );
      const emptyContinent = ContinentId('empty_continent');
      final state = GameState(
        countries: {egypt: _unlocked('egypt')},
        unlockedContinents: {africa: true, emptyContinent: true},
        totalInfluence: Influence(Decimal.parse('0')),
      );
      final container = ProviderContainer(
        overrides: [
          contentRegistryProvider.overrideWith((_) async => content),
          gameWorldProvider.overrideWith(
            (_) => _SpyNotifier(content: content, initialState: state),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(contentRegistryProvider.future);

      final rows = container.read(continentProgressRowsProvider);
      expect(rows!.length, 1);
      expect(rows.first.continentId, africa);
    });

    test(
      'ordering tiebreak: same unlockThreshold, sorted by id.value',
      () async {
        // Both Africa and Europe have unlockThreshold 0 → tiebreak on id.value.
        final content = _twoContinent(
          africaUnlockThreshold: '0',
          europeUnlockThreshold: '0',
        );
        final state = GameState(
          countries: {
            egypt: _unlocked('egypt'),
            nigeria: _locked('nigeria'),
            southAfrica: _locked('south_africa'),
            france: _unlocked('france'),
          },
          unlockedContinents: {africa: true, europe: true},
          totalInfluence: Influence(Decimal.parse('0')),
        );
        final container = _container(content, state);
        await container.read(contentRegistryProvider.future);

        final rows = container.read(continentProgressRowsProvider);
        expect(rows!.length, 2);
        // 'africa' < 'europe' alphabetically.
        expect(rows[0].continentId, africa);
        expect(rows[1].continentId, europe);
      },
    );

    test(
      'no spurious rebuild: consecutive reads with same state return equal rows',
      () async {
        final content = _twoContinent();
        final state = GameState(
          countries: {
            egypt: _unlocked('egypt'),
            nigeria: _locked('nigeria'),
            southAfrica: _locked('south_africa'),
            france: _locked('france'),
          },
          unlockedContinents: {africa: true},
          totalInfluence: Influence(Decimal.parse('0')),
        );
        final container = _container(content, state);
        await container.read(contentRegistryProvider.future);

        final rows1 = container.read(continentProgressRowsProvider);
        final rows2 = container.read(continentProgressRowsProvider);
        // Same provider read should return the identical cached instance.
        expect(identical(rows1, rows2), isTrue);
      },
    );
  });
}
