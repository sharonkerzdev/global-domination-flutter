import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/continents/unlocks_reducer.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

ContentRegistry _contentAfrica() {
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
    {
      'id': 'nigeria',
      'continent': 'africa',
      'baseInfluence': '5',
      'unlockCost': '5',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'south_africa',
      'continent': 'africa',
      'baseInfluence': '15',
      'unlockCost': '25',
      'tier': 1,
      'generationSeconds': 2,
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

/// Europe with a very high unlock threshold — continent stays "locked" until story 4.2-style state exists.
ContentRegistry _contentEuropeLocked() {
  final continents = jsonEncode([
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
      'id': 'france',
      'continent': 'europe',
      'baseInfluence': '1',
      'unlockCost': '10',
      'tier': 1,
      'generationSeconds': 1,
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

ContentRegistry _contentNegativeUnlockCost() {
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
    {
      'id': 'nigeria',
      'continent': 'africa',
      'baseInfluence': '5',
      'unlockCost': '-1',
      'tier': 1,
      'generationSeconds': 1,
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

void main() {
  final now = DateTime.utc(2026, 4, 24);
  const nigeria = CountryId('nigeria');
  const cmd = UnlockCountry(countryId: nigeria);

  group('applyUnlockCountry', () {
    test('happy path: unlock nigeria, deducts def.unlockCost, emits CountryUnlocked', () {
      final content = _contentAfrica();
      final base = GameState.initialSeed(content).copyWith(
        totalInfluence: Influence(Decimal.fromInt(5)),
      );
      final r = applyUnlockCountry(base, content, cmd, now: now);
      expect(r.isSuccess, isTrue);
      final (next, ev) = r.valueOrNull!;
      final unlocked = next.countries[nigeria]!;
      expect(unlocked.unlocked, isTrue);
      expect(unlocked.ipLevel, equals(1));
      expect(unlocked.leaderTier, LeaderTier.none);
      expect(unlocked.bankedInfluence, Influence.zero);
      expect(unlocked.lastCollectedAt, isNull);
      expect(next.totalInfluence, equals(Influence.zero));
      expect(ev, isA<CountryUnlocked>());
      final e = ev! as CountryUnlocked;
      expect(e.at, equals(now));
      expect(e.countryId, nigeria);
      expect(e.continent, const ContinentId('africa'));
      expect(e.cost, equals(Influence(Decimal.fromInt(5))));
    });

    test('already unlocked → Locked(already_unlocked), no mutation', () {
      final content = _contentAfrica();
      final r1 = applyUnlockCountry(
        GameState.initialSeed(content).copyWith(
          totalInfluence: Influence(Decimal.fromInt(5)),
        ),
        content,
        cmd,
        now: now,
      );
      final afterFirst = r1.valueOrNull!.$1;
      final beforeSecondAttempt = afterFirst.copyWith();
      final r2 = applyUnlockCountry(afterFirst, content, cmd, now: now);
      expect(r2.isFailure, isTrue);
      expect((r2.errorOrNull! as Locked).reason, equals('already_unlocked'));
      expect(afterFirst, equals(beforeSecondAttempt));
    });

    test('continent_locked when totalInfluence below continent threshold', () {
      final content = _contentEuropeLocked();
      const france = CountryId('france');
      final before = GameState(
        countries: {
          france: CountryState(
            id: france,
            unlocked: false,
            ipLevel: 0,
            leaderTier: LeaderTier.none,
            bankedInfluence: Influence.zero,
          ),
        },
        totalInfluence: Influence(Decimal.fromInt(100)),
      );
      const franceCmd = UnlockCountry(countryId: france);
      final r = applyUnlockCountry(before, content, franceCmd, now: now);
      expect(r.isFailure, isTrue);
      expect((r.errorOrNull! as Locked).reason, equals('continent_locked'));
      final unchanged = GameState(
        countries: {
          france: CountryState(
            id: france,
            unlocked: false,
            ipLevel: 0,
            leaderTier: LeaderTier.none,
            bankedInfluence: Influence.zero,
          ),
        },
        totalInfluence: Influence(Decimal.fromInt(100)),
      );
      expect(before, equals(unchanged));
    });

    test('insufficient funds → InsufficientFunds(required: cost), no mutation', () {
      final content = _contentAfrica();
      final before = GameState.initialSeed(content).copyWith(
        totalInfluence: Influence(Decimal.parse('4')),
      );
      final r = applyUnlockCountry(before, content, cmd, now: now);
      expect(r.isFailure, isTrue);
      final err = r.errorOrNull! as InsufficientFunds;
      expect(err.required, equals(Influence(Decimal.fromInt(5))));
      final unchanged = GameState.initialSeed(content).copyWith(
        totalInfluence: Influence(Decimal.parse('4')),
      );
      expect(before, equals(unchanged));
    });

    test('missing country id not in state → MissingCountry', () {
      final content = _contentAfrica();
      final s = GameState.initialSeed(content);
      const atlantis = CountryId('atlantis');
      final r = applyUnlockCountry(
        s,
        content,
        const UnlockCountry(countryId: atlantis),
        now: now,
      );
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull!, isA<MissingCountry>());
      expect((r.errorOrNull! as MissingCountry).id, atlantis);
    });

    test('country in state but not in content → MissingCountry', () {
      final content = _contentAfrica();
      const orphan = CountryId('orphan');
      final s = GameState(
        countries: {
          ...GameState.initialSeed(content).countries,
          orphan: CountryState(
            id: orphan,
            unlocked: false,
            ipLevel: 0,
            leaderTier: LeaderTier.none,
            bankedInfluence: Influence.zero,
          ),
        },
        totalInfluence: Influence(Decimal.fromInt(100)),
      );
      final r = applyUnlockCountry(
        s,
        content,
        const UnlockCountry(countryId: orphan),
        now: now,
      );
      expect(r.isFailure, isTrue);
      expect((r.errorOrNull! as MissingCountry).id, orphan);
    });

    test('africa threshold 0: exact cost boundary succeeds (>=)', () {
      final content = _contentAfrica();
      final s = GameState.initialSeed(content).copyWith(
        totalInfluence: Influence(Decimal.fromInt(5)),
      );
      final r = applyUnlockCountry(s, content, cmd, now: now);
      expect(r.isSuccess, isTrue);
    });

    test('negative unlockCost in content → InvariantBroken', () {
      final content = _contentNegativeUnlockCost();
      final before = GameState.initialSeed(content).copyWith(
        totalInfluence: Influence(Decimal.fromInt(10)),
      );
      final r = applyUnlockCountry(before, content, cmd, now: now);
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull, isA<InvariantBroken>());
      final err = r.errorOrNull! as InvariantBroken;
      expect(err.message, contains('negative unlockCost'));
      final unchanged = GameState.initialSeed(content).copyWith(
        totalInfluence: Influence(Decimal.fromInt(10)),
      );
      expect(before, equals(unchanged));
    });
  });
}
