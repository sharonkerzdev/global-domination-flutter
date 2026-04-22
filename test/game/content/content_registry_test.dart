import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/content/content_load_exception.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';

void main() {
  final validContinents = jsonEncode([
    {
      'id': 'africa',
      'name': 'Africa',
      'unlockThreshold': '0',
      'completionBonus': '0.25',
      'milestoneRewards': <dynamic>[],
    },
  ]);

  final validCountries = jsonEncode([
    {
      'id': 'egypt',
      'continent': 'africa',
      'baseInfluence': '1',
      'unlockCost': '0',
      'tier': 1,
      'generationSeconds': 1,
    },
  ]);

  final validLeaders = jsonEncode([
    {
      'id': 'default_leader',
      'name': 'General',
      'tierMultipliers': ['1.0', '1.5', '2.0', '3.0'],
    },
  ]);

  const emptyArray = '[]';

  ContentRegistry buildRegistry({
    String? countriesJson,
    String? continentsJson,
    String? leadersJson,
    String? achievementsJson,
    String? missionsJson,
    String? globalUpgradesJson,
  }) {
    return ContentRegistry.fromJsonStrings(
      countriesJson: countriesJson ?? validCountries,
      continentsJson: continentsJson ?? validContinents,
      leadersJson: leadersJson ?? validLeaders,
      achievementsJson: achievementsJson ?? emptyArray,
      missionsJson: missionsJson ?? emptyArray,
      globalUpgradesJson: globalUpgradesJson ?? emptyArray,
    );
  }

  group('ContentRegistry.fromJsonStrings', () {
    test('parses valid JSON into correct maps and lists', () {
      final registry = buildRegistry();

      expect(registry.countries, hasLength(1));
      expect(registry.continents, hasLength(1));
      expect(registry.leaders, hasLength(1));
      expect(registry.achievements, isEmpty);
      expect(registry.missions, isEmpty);
      expect(registry.globalUpgrades, isEmpty);
    });

    test('countries map keyed by CountryId', () {
      final registry = buildRegistry();

      final egypt = registry.countries[const CountryId('egypt')];
      expect(egypt, isNotNull);
      expect(egypt!.id, const CountryId('egypt'));
      expect(egypt.continent, const ContinentId('africa'));
    });

    test('continents map keyed by ContinentId', () {
      final registry = buildRegistry();

      final africa = registry.continents[const ContinentId('africa')];
      expect(africa, isNotNull);
      expect(africa!.name, 'Africa');
    });

    test('Decimal fields parsed correctly', () {
      final registry = buildRegistry();

      final egypt = registry.countries[const CountryId('egypt')]!;
      expect(egypt.baseInfluence, Decimal.parse('1'));
      expect(egypt.unlockCost, Decimal.parse('0'));

      final africa = registry.continents[const ContinentId('africa')]!;
      expect(africa.unlockThreshold, Decimal.parse('0'));
      expect(africa.completionBonus, Decimal.parse('0.25'));
    });

    test('empty achievements/missions arrays parse to empty lists', () {
      final registry = buildRegistry();

      expect(registry.achievements, isEmpty);
      expect(registry.missions, isEmpty);
    });

    test('throws ContentLoadException on malformed JSON', () {
      expect(
        () => buildRegistry(countriesJson: '{not valid json'),
        throwsA(isA<ContentLoadException>()),
      );
    });

    test(
      'throws ContentLoadException when country references non-existent continent',
      () {
        final badCountries = jsonEncode([
          {
            'id': 'egypt',
            'continent': 'atlantis',
            'baseInfluence': '1',
            'unlockCost': '0',
            'tier': 1,
            'generationSeconds': 1,
          },
        ]);

        expect(
          () => buildRegistry(countriesJson: badCountries),
          throwsA(
            isA<ContentLoadException>().having(
              (e) => e.message,
              'message',
              contains('non-existent continent'),
            ),
          ),
        );
      },
    );

    test('throws ContentLoadException on empty countries array', () {
      expect(
        () => buildRegistry(countriesJson: emptyArray),
        throwsA(
          isA<ContentLoadException>().having(
            (e) => e.message,
            'message',
            contains('empty'),
          ),
        ),
      );
    });

    test('collections are unmodifiable', () {
      final registry = buildRegistry();

      expect(() => registry.countries.clear(), throwsUnsupportedError);

      expect(() => registry.continents.clear(), throwsUnsupportedError);

      expect(() => (registry.leaders as List).clear(), throwsUnsupportedError);
    });
  });
}
