import 'dart:convert';

import 'package:test/test.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

import '../helpers/fake_clock.dart';

ContentRegistry _buildContent({bool includeNonEgypt = true}) {
  final continents = jsonEncode([
    {
      'id': 'africa',
      'name': 'Africa',
      'unlockThreshold': '0',
      'completionBonus': '0.25',
      'milestoneRewards': <dynamic>[],
    },
  ]);
  final countriesList = [
    {
      'id': 'egypt',
      'continent': 'africa',
      'baseInfluence': '1',
      'unlockCost': '0',
      'tier': 1,
      'generationSeconds': 1,
    },
    if (includeNonEgypt) ...[
      {
        'id': 'nigeria',
        'continent': 'africa',
        'baseInfluence': '2',
        'unlockCost': '100',
        'tier': 1,
        'generationSeconds': 2,
      },
      {
        'id': 'south_africa',
        'continent': 'africa',
        'baseInfluence': '3',
        'unlockCost': '200',
        'tier': 2,
        'generationSeconds': 3,
      },
    ],
  ];
  final countries = jsonEncode(countriesList);

  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: jsonEncode([]),
    achievementsJson: jsonEncode([]),
    missionsJson: jsonEncode([]),
    globalUpgradesJson: jsonEncode([]),
  );
}

ContentRegistry _buildAfricaAndEuropeContent() {
  final continents = jsonEncode([
    {
      'id': 'africa',
      'name': 'Africa',
      'unlockThreshold': '0',
      'completionBonus': '0.25',
      'milestoneRewards': <dynamic>[],
    },
    {
      'id': 'europe',
      'name': 'Europe',
      'unlockThreshold': '1000000000',
      'completionBonus': '0.25',
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
      'id': 'france',
      'continent': 'europe',
      'baseInfluence': '1',
      'unlockCost': '100',
      'tier': 1,
      'generationSeconds': 1,
    },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: jsonEncode([]),
    achievementsJson: jsonEncode([]),
    missionsJson: jsonEncode([]),
    globalUpgradesJson: jsonEncode([]),
  );
}

void main() {
  group('GameState.initialSeed', () {
    test('4.2: produces exactly content.countries.length entries', () {
      final content = _buildContent();
      final state = GameState.initialSeed(content);
      expect(state.countries, hasLength(content.countries.length));
    });

    test(
      '4.3: Egypt is unlocked=true, ipLevel=1, leaderTier=none, bankedInfluence=zero',
      () {
        final content = _buildContent();
        final state = GameState.initialSeed(content);
        final egypt = state.countries[const CountryId('egypt')]!;
        expect(egypt.unlocked, isTrue);
        expect(egypt.ipLevel, equals(1));
        expect(egypt.leaderTier, equals(LeaderTier.none));
        expect(egypt.bankedInfluence, equals(Influence.zero));
        expect(egypt.lastCollectedAt, isNull);
      },
    );

    test(
      '4.4: all non-Egypt countries are unlocked=false, ipLevel=0, leaderTier=none, bankedInfluence=zero',
      () {
        final content = _buildContent();
        final state = GameState.initialSeed(content);
        final nonEgypt = state.countries.entries
            .where((e) => e.key != const CountryId('egypt'))
            .toList();
        expect(nonEgypt, isNotEmpty);
        for (final entry in nonEgypt) {
          expect(
            entry.value.unlocked,
            isFalse,
            reason: '${entry.key} unlocked',
          );
          expect(
            entry.value.ipLevel,
            equals(0),
            reason: '${entry.key} ipLevel',
          );
          expect(
            entry.value.leaderTier,
            equals(LeaderTier.none),
            reason: '${entry.key} leaderTier',
          );
          expect(
            entry.value.bankedInfluence,
            equals(Influence.zero),
            reason: '${entry.key} bankedInfluence',
          );
          expect(
            entry.value.lastCollectedAt,
            isNull,
            reason: '${entry.key} lastCollectedAt',
          );
        }
      },
    );

    test('4.5: totalInfluence == Influence.zero', () {
      final content = _buildContent();
      final state = GameState.initialSeed(content);
      expect(state.totalInfluence, equals(Influence.zero));
    });

    test(
      '4.2: seed includes continents with unlockThreshold <= 0 in unlockedContinents',
      () {
        final single = _buildContent();
        expect(
          GameState.initialSeed(single).unlockedContinents,
          equals({const ContinentId('africa'): true}),
        );

        final twoContinents = _buildAfricaAndEuropeContent();
        expect(
          GameState.initialSeed(twoContinents).unlockedContinents,
          equals({const ContinentId('africa'): true}),
        );
      },
    );

    test('4.6: passing initialState to GameWorld overrides the seed', () {
      final content = _buildContent();
      final clock = FakeClock(DateTime.utc(2026, 1, 1));

      // Build a custom state with Egypt locked and ipLevel=0
      final seed = GameState.initialSeed(content);
      final customState = seed.copyWith(
        countries: {
          ...seed.countries,
          const CountryId('egypt'): seed.countries[const CountryId('egypt')]!
              .copyWith(unlocked: false, ipLevel: 0),
        },
      );

      final world = GameWorld(
        content: content,
        clock: clock,
        initialState: customState,
      );

      // State should match customState (Egypt locked), not the seed (Egypt unlocked)
      expect(
        world.state.countries[const CountryId('egypt')]!.unlocked,
        isFalse,
      );
      expect(
        world.state.countries[const CountryId('egypt')]!.ipLevel,
        equals(0),
      );
      world.dispose();
    });

    test('each CountryState.id matches its map key', () {
      final content = _buildContent();
      final state = GameState.initialSeed(content);
      for (final entry in state.countries.entries) {
        expect(entry.value.id, equals(entry.key));
      }
    });

    test('every CountryDef in content has a corresponding CountryState', () {
      final content = _buildContent();
      final state = GameState.initialSeed(content);
      for (final countryId in content.countries.keys) {
        expect(
          state.countries.containsKey(countryId),
          isTrue,
          reason: '$countryId missing from seed',
        );
      }
    });
  });
}
