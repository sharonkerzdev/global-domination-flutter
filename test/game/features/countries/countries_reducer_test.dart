import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/countries/countries_reducer.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

import '../../../helpers/achievements_fixture.dart';
import '../../../helpers/daily_rewards_test_json.dart';

ContentRegistry _makeRegistry({
  String id = 'egypt',
  String baseInfluence = '1',
  int generationSeconds = 1,
}) {
  final continents = jsonEncode([
    {
      'id': 'africa',
      'name': 'Africa',
      'unlockThreshold': '0',
      'completionBonus': '0.25',
      'milestoneRewards': <dynamic>[],
    },
  ]);
  final countries = jsonEncode([
    {
      'id': id,
      'continent': 'africa',
      'baseInfluence': baseInfluence,
      'unlockCost': '0',
      'tier': 1,
      'generationSeconds': generationSeconds,
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

ContentRegistry _makeTwoCountryRegistry() {
  final continents = jsonEncode([
    {
      'id': 'africa',
      'name': 'Africa',
      'unlockThreshold': '0',
      'completionBonus': '0.25',
      'milestoneRewards': <dynamic>[],
    },
  ]);
  final countries = jsonEncode([
    {
      'id': 'egypt',
      'continent': 'africa',
      'baseInfluence': '2',
      'unlockCost': '0',
      'tier': 1,
      'generationSeconds': 2,
    },
    {
      'id': 'ghana',
      'continent': 'africa',
      'baseInfluence': '3',
      'unlockCost': '0',
      'tier': 1,
      'generationSeconds': 3,
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

CountryState _country(
  String id, {
  bool unlocked = true,
  Influence? bankedInfluence,
}) {
  return CountryState(
    id: CountryId(id),
    unlocked: unlocked,
    ipLevel: 0,
    leaderTier: LeaderTier.none,
    bankedInfluence: bankedInfluence ?? Influence.zero,
  );
}

GameState _game(Map<CountryId, CountryState> countries) =>
    GameState(countries: countries);

void main() {
  group('tickCountries', () {
    test('unlocked country accumulates baseInfluence over 1 second', () {
      final content = _makeRegistry(baseInfluence: '1', generationSeconds: 1);
      var gs = _game({CountryId('egypt'): _country('egypt')});

      for (var i = 0; i < 10; i++) {
        final newMap = tickCountries(
          gs,
          const Duration(milliseconds: 100),
          content,
        );
        gs = gs.copyWith(countries: newMap);
      }

      final banked = gs.countries[CountryId('egypt')]!.bankedInfluence;
      expect(
        banked.value,
        equals(Decimal.one),
        reason: 'Should accumulate exactly 1.0 influence after 1 second',
      );
    });

    test('locked country does not accumulate influence', () {
      final content = _makeRegistry(baseInfluence: '1', generationSeconds: 1);
      var gs = _game({CountryId('egypt'): _country('egypt', unlocked: false)});

      for (var i = 0; i < 300; i++) {
        final newMap = tickCountries(
          gs,
          const Duration(milliseconds: 16),
          content,
        );
        gs = gs.copyWith(countries: newMap);
      }

      expect(
        gs.countries[CountryId('egypt')]!.bankedInfluence,
        equals(Influence.zero),
      );
    });

    test('multiple countries accumulate independently', () {
      final content = _makeTwoCountryRegistry();
      var gs = _game({
        CountryId('egypt'): _country('egypt'),
        CountryId('ghana'): _country('ghana'),
      });

      final newMap = tickCountries(gs, const Duration(seconds: 6), content);
      gs = gs.copyWith(countries: newMap);

      expect(
        gs.countries[CountryId('egypt')]!.bankedInfluence.value,
        equals(Decimal.parse('6')),
      );
      expect(
        gs.countries[CountryId('ghana')]!.bankedInfluence.value,
        equals(Decimal.parse('6')),
      );
    });

    test(
      'zero-duration tick produces no change and returns same map instance',
      () {
        final content = _makeRegistry();
        final countries = {CountryId('egypt'): _country('egypt')};
        final gs = _game(countries);

        final result = tickCountries(gs, Duration.zero, content);

        expect(identical(result, gs.countries), isTrue);
      },
    );

    test('sub-second accumulation is correct', () {
      final content = _makeRegistry(baseInfluence: '1', generationSeconds: 1);
      final gs = _game({CountryId('egypt'): _country('egypt')});

      final result = tickCountries(
        gs,
        const Duration(milliseconds: 500),
        content,
      );

      expect(
        result[CountryId('egypt')]!.bankedInfluence.value,
        equals(Decimal.parse('0.5')),
      );
    });

    test('no unlocked countries returns same map instance', () {
      final content = _makeRegistry();
      final countries = {
        CountryId('egypt'): _country('egypt', unlocked: false),
      };
      final gs = _game(countries);

      final result = tickCountries(
        gs,
        const Duration(milliseconds: 100),
        content,
      );

      expect(identical(result, gs.countries), isTrue);
    });

    test('single large tick matches formula exactly', () {
      final content = _makeRegistry(baseInfluence: '1', generationSeconds: 1);
      final gs = _game({CountryId('egypt'): _country('egypt')});

      final result = tickCountries(gs, const Duration(seconds: 1), content);

      expect(
        result[CountryId('egypt')]!.bankedInfluence.value,
        equals(Decimal.one),
      );
    });

    test('accumulation is additive across multiple ticks', () {
      final content = _makeRegistry(baseInfluence: '1', generationSeconds: 1);
      var gs = _game({CountryId('egypt'): _country('egypt')});

      var newMap = tickCountries(
        gs,
        const Duration(milliseconds: 500),
        content,
      );
      gs = gs.copyWith(countries: newMap);
      newMap = tickCountries(gs, const Duration(milliseconds: 500), content);
      gs = gs.copyWith(countries: newMap);

      expect(
        gs.countries[CountryId('egypt')]!.bankedInfluence.value,
        equals(Decimal.one),
      );
    });

    test('asserts on negative dt', () {
      final content = _makeRegistry();
      final gs = _game({CountryId('egypt'): _country('egypt')});
      expect(
        () => tickCountries(gs, const Duration(milliseconds: -1), content),
        throwsA(isA<AssertionError>()),
      );
    });

    test(
      'hired leader accrues at per-second rate (ignores long generation period)',
      () {
        final content = _makeRegistry(baseInfluence: '1', generationSeconds: 4);
        final cs = CountryState(
          id: const CountryId('egypt'),
          unlocked: true,
          ipLevel: 0,
          leaderTier: LeaderTier.tier1,
          bankedInfluence: Influence.zero,
        );
        final gs = _game({CountryId('egypt'): cs});
        final m = tickCountries(gs, const Duration(seconds: 4), content);
        // Without a leader, 1.0 * (1 + 0) * 1.5 = 1.5 per "period unit";
        // time ratio is 4/1s → 1.5 × 4 = 6
        expect(
          m[CountryId('egypt')]!.bankedInfluence.value,
          equals(Decimal.parse('6')),
        );
      },
    );

    test('non-positive generationSeconds never accrues, even with leader', () {
      final content = _makeRegistry(baseInfluence: '1', generationSeconds: 0);
      final cs = CountryState(
        id: const CountryId('egypt'),
        unlocked: true,
        ipLevel: 0,
        leaderTier: LeaderTier.tier2,
        bankedInfluence: Influence.zero,
      );
      final gs = _game({CountryId('egypt'): cs});
      final m = tickCountries(gs, const Duration(seconds: 2), content);
      expect(m[CountryId('egypt')]!.bankedInfluence, equals(Influence.zero));
    });
  });
}
