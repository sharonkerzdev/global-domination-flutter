import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/countries/countries_reducer.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

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
    achievementsJson: '[]',
    missionsJson: '[]',
    globalUpgradesJson: '[]',
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
    achievementsJson: '[]',
    missionsJson: '[]',
    globalUpgradesJson: '[]',
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

void main() {
  group('tickCountries', () {
    test('unlocked country accumulates baseInfluence over 1 second', () {
      final content = _makeRegistry(baseInfluence: '1', generationSeconds: 1);
      final countries = {CountryId('egypt'): _country('egypt')};

      // Use 10 ticks of 100ms = exactly 1 second, producing exact Decimal result
      var result = countries;
      for (var i = 0; i < 10; i++) {
        result = tickCountries(
          result,
          const Duration(milliseconds: 100),
          content,
        );
      }

      final banked = result[CountryId('egypt')]!.bankedInfluence;
      expect(
        banked.value,
        equals(Decimal.one),
        reason: 'Should accumulate exactly 1.0 influence after 1 second',
      );
    });

    test('locked country does not accumulate influence', () {
      final content = _makeRegistry(baseInfluence: '1', generationSeconds: 1);
      final countries = {
        CountryId('egypt'): _country('egypt', unlocked: false),
      };

      var result = countries;
      for (var i = 0; i < 300; i++) {
        result = tickCountries(
          result,
          const Duration(milliseconds: 16),
          content,
        );
      }

      expect(
        result[CountryId('egypt')]!.bankedInfluence,
        equals(Influence.zero),
      );
    });

    test('multiple countries accumulate independently', () {
      final content = _makeTwoCountryRegistry();
      final countries = {
        CountryId('egypt'): _country('egypt'),
        CountryId('ghana'): _country('ghana'),
      };

      // egypt: baseInfluence=2, generationSeconds=2 → 2s tick → 2s * 2/2 = 2.0 (exact)
      // ghana: baseInfluence=3, generationSeconds=3 → 3s tick → 3s * 3/3 = 3.0 (exact)
      // Use 6-second tick so both produce exact results
      var result = countries;
      result = tickCountries(result, const Duration(seconds: 6), content);

      // egypt: 6s * 2/2 = 6.0
      // ghana: 6s * 3/3 = 6.0
      expect(
        result[CountryId('egypt')]!.bankedInfluence.value,
        equals(Decimal.parse('6')),
      );
      expect(
        result[CountryId('ghana')]!.bankedInfluence.value,
        equals(Decimal.parse('6')),
      );
    });

    test(
      'zero-duration tick produces no change and returns same map instance',
      () {
        final content = _makeRegistry();
        final countries = {CountryId('egypt'): _country('egypt')};

        final result = tickCountries(countries, Duration.zero, content);

        expect(identical(result, countries), isTrue);
      },
    );

    test('sub-second accumulation is correct', () {
      final content = _makeRegistry(baseInfluence: '1', generationSeconds: 1);
      final countries = {CountryId('egypt'): _country('egypt')};

      final result = tickCountries(
        countries,
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

      final result = tickCountries(
        countries,
        const Duration(milliseconds: 100),
        content,
      );

      expect(identical(result, countries), isTrue);
    });

    test('single large tick matches formula exactly', () {
      final content = _makeRegistry(baseInfluence: '1', generationSeconds: 1);
      final countries = {CountryId('egypt'): _country('egypt')};

      final result = tickCountries(
        countries,
        const Duration(seconds: 1),
        content,
      );

      expect(
        result[CountryId('egypt')]!.bankedInfluence.value,
        equals(Decimal.one),
      );
    });

    test('accumulation is additive across multiple ticks', () {
      final content = _makeRegistry(baseInfluence: '1', generationSeconds: 1);
      var countries = {CountryId('egypt'): _country('egypt')};

      countries = tickCountries(
        countries,
        const Duration(milliseconds: 500),
        content,
      );
      countries = tickCountries(
        countries,
        const Duration(milliseconds: 500),
        content,
      );

      expect(
        countries[CountryId('egypt')]!.bankedInfluence.value,
        equals(Decimal.one),
      );
    });

    test('asserts on negative dt', () {
      final content = _makeRegistry();
      final countries = {CountryId('egypt'): _country('egypt')};
      expect(
        () =>
            tickCountries(countries, const Duration(milliseconds: -1), content),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
