import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/continents/continents_reducer.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

ContentRegistry _registry(String continentsJson, String countriesJson) {
  return ContentRegistry.fromJsonStrings(
    countriesJson: countriesJson,
    continentsJson: continentsJson,
    leadersJson: '[]',
    achievementsJson: '[]',
    missionsJson: '[]',
    globalUpgradesJson: '[]',
  );
}

GameState _minimalState({
  required Influence total,
  Map<ContinentId, bool>? unlockedContinents,
}) {
  return GameState(
    countries: {
      const CountryId('egypt'): CountryState(
        id: const CountryId('egypt'),
        unlocked: true,
        ipLevel: 1,
        leaderTier: LeaderTier.none,
        bankedInfluence: Influence.zero,
      ),
    },
    totalInfluence: total,
    unlockedContinents: unlockedContinents ?? const {},
  );
}

void main() {
  final now = DateTime.utc(2026, 4, 24);

  group('evaluateContinentUnlocks', () {
    test('single new unlock at threshold returns new state + one event', () {
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
          'unlockThreshold': '100',
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
          'unlockCost': '10',
          'tier': 1,
          'generationSeconds': 1,
        },
      ]);
      final content = _registry(continents, countries);
      final state = _minimalState(
        total: Influence(Decimal.fromInt(100)),
        unlockedContinents: {const ContinentId('africa'): true},
      );

      final r = evaluateContinentUnlocks(state, content, now: now);
      expect(r.isSuccess, isTrue);
      final (newState, events) = r.valueOrNull!;
      expect(events, hasLength(1));
      expect(events.single, isA<ContinentUnlocked>());
      expect(
        (events.single as ContinentUnlocked).continentId,
        const ContinentId('europe'),
      );
      expect(newState.unlockedContinents[const ContinentId('europe')], isTrue);
    });

    test(
      'below threshold returns same GameState instance and empty events',
      () {
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
            'unlockThreshold': '100',
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
            'unlockCost': '10',
            'tier': 1,
            'generationSeconds': 1,
          },
        ]);
        final content = _registry(continents, countries);
        final state = _minimalState(
          total: Influence(Decimal.fromInt(99)),
          unlockedContinents: {const ContinentId('africa'): true},
        );

        final r = evaluateContinentUnlocks(state, content, now: now);
        expect(r.isSuccess, isTrue);
        final (newState, events) = r.valueOrNull!;
        expect(events, isEmpty);
        expect(identical(newState, state), isTrue);
      },
    );

    test('multiple thresholds crossed emit events in threshold ASC order', () {
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
          'unlockThreshold': '10',
          'completionBonus': '0.25',
          'milestoneRewards': <dynamic>[],
        },
        {
          'id': 'asia',
          'name': 'Asia',
          'unlockThreshold': '20',
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
          'unlockCost': '10',
          'tier': 1,
          'generationSeconds': 1,
        },
        {
          'id': 'china',
          'continent': 'asia',
          'baseInfluence': '1',
          'unlockCost': '10',
          'tier': 1,
          'generationSeconds': 1,
        },
      ]);
      final content = _registry(continents, countries);
      final state = _minimalState(
        total: Influence(Decimal.fromInt(25)),
        unlockedContinents: const {},
      );

      final r = evaluateContinentUnlocks(state, content, now: now);
      expect(r.isSuccess, isTrue);
      final (_, events) = r.valueOrNull!;
      expect(events, hasLength(3));
      expect(
        (events[0] as ContinentUnlocked).continentId,
        const ContinentId('africa'),
      );
      expect(
        (events[1] as ContinentUnlocked).continentId,
        const ContinentId('europe'),
      );
      expect(
        (events[2] as ContinentUnlocked).continentId,
        const ContinentId('asia'),
      );
    });

    test(
      'already-unlocked continent emits nothing and leaves state unchanged',
      () {
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
            'baseInfluence': '1',
            'unlockCost': '0',
            'tier': 1,
            'generationSeconds': 1,
          },
        ]);
        final content = _registry(continents, countries);
        final state = _minimalState(
          total: Influence.zero,
          unlockedContinents: {const ContinentId('africa'): true},
        );

        final r = evaluateContinentUnlocks(state, content, now: now);
        expect(r.isSuccess, isTrue);
        final (newState, events) = r.valueOrNull!;
        expect(events, isEmpty);
        expect(identical(newState, state), isTrue);
      },
    );

    test('tied thresholds: secondary sort by continent id.value ASC', () {
      final continents = jsonEncode([
        {
          'id': 'zulu',
          'name': 'Z',
          'unlockThreshold': '0',
          'completionBonus': '0.25',
          'milestoneRewards': <dynamic>[],
        },
        {
          'id': 'alpha',
          'name': 'A',
          'unlockThreshold': '0',
          'completionBonus': '0.25',
          'milestoneRewards': <dynamic>[],
        },
      ]);
      final countries = jsonEncode([
        {
          'id': 'egypt',
          'continent': 'zulu',
          'baseInfluence': '1',
          'unlockCost': '0',
          'tier': 1,
          'generationSeconds': 1,
        },
        {
          'id': 'france',
          'continent': 'alpha',
          'baseInfluence': '1',
          'unlockCost': '10',
          'tier': 1,
          'generationSeconds': 1,
        },
      ]);
      final content = _registry(continents, countries);
      final state = _minimalState(
        total: Influence.zero,
        unlockedContinents: const {},
      );

      final r = evaluateContinentUnlocks(state, content, now: now);
      expect(r.isSuccess, isTrue);
      final (_, events) = r.valueOrNull!;
      expect(events, hasLength(2));
      expect(
        (events[0] as ContinentUnlocked).continentId,
        const ContinentId('alpha'),
      );
      expect(
        (events[1] as ContinentUnlocked).continentId,
        const ContinentId('zulu'),
      );
    });

    test('negative unlockThreshold returns InvariantBroken', () {
      final continents = jsonEncode([
        {
          'id': 'africa',
          'name': 'Africa',
          'unlockThreshold': '-1',
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
      ]);
      final content = _registry(continents, countries);
      final state = _minimalState(total: Influence.zero);

      final r = evaluateContinentUnlocks(state, content, now: now);
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull, isA<InvariantBroken>());
    });

    test('unlockedContinents map on success is unmodifiable', () {
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
          'baseInfluence': '1',
          'unlockCost': '0',
          'tier': 1,
          'generationSeconds': 1,
        },
      ]);
      final content = _registry(continents, countries);
      final state = _minimalState(
        total: Influence.zero,
        unlockedContinents: const {},
      );

      final r = evaluateContinentUnlocks(state, content, now: now);
      expect(r.isSuccess, isTrue);
      final (newState, _) = r.valueOrNull!;
      expect(
        () => newState.unlockedContinents[const ContinentId('africa')] = false,
        throwsUnsupportedError,
      );
    });
  });
}
