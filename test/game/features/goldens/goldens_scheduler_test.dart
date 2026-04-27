import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/goldens/active_golden.dart';
import 'package:global_domination/game/features/goldens/active_golden_effect.dart';
import 'package:global_domination/game/features/goldens/goldens_scheduler.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

import '../../../helpers/achievements_fixture.dart';
import '../../../helpers/daily_rewards_test_json.dart';

/// Africa @0, egypt / nigeria / south_africa — mirrors income_calculator_test.
ContentRegistry _fixture3() {
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
      'unlockCost': '0',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'kenya',
      'continent': 'africa',
      'baseInfluence': '2',
      'unlockCost': '0',
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

void main() {
  const egypt = CountryId('egypt');
  const nigeria = CountryId('nigeria');
  const kenya = CountryId('kenya');
  const africa = ContinentId('africa');

  CountryState cs(CountryId id, {required bool unlocked}) {
    return CountryState(
      id: id,
      unlocked: unlocked,
      ipLevel: 1,
      leaderTier: LeaderTier.none,
      bankedInfluence: Influence.zero,
      lastCollectedAt: null,
    );
  }

  final content = _fixture3();
  final t0 = DateTime.utc(2026, 4, 25, 10, 0, 0);
  final unlockedAfrica = {africa: true};

  test('12.3 determinism: same input → identical result', () {
    const dt = Duration(seconds: 1);
    final s = GameState(
      countries: {
        egypt: cs(egypt, unlocked: true),
        nigeria: cs(nigeria, unlocked: true),
        kenya: cs(kenya, unlocked: false),
      },
      unlockedContinents: unlockedAfrica,
    );
    const rngSeed = 42;
    final a1 = evaluateGoldens(
      s,
      content,
      dt,
      now: t0,
      rng: SeededRng(rngSeed),
    );
    final a2 = evaluateGoldens(
      s,
      content,
      dt,
      now: t0,
      rng: SeededRng(rngSeed),
    );
    expect(a1.$1, equals(a2.$1));
    expect(a1.$2, equals(a2.$2));
  });

  test('12.4 no spawn when pTick effectively zero (1µs dt)', () {
    final s = GameState(
      countries: {egypt: cs(egypt, unlocked: true)},
      unlockedContinents: unlockedAfrica,
    );
    final (ns, ev) = evaluateGoldens(
      s,
      content,
      const Duration(microseconds: 1),
      now: t0,
      rng: SeededRng(0),
    );
    expect(ns, equals(s));
    expect(ev, isEmpty);
  });

  test(
    '12.5 spawn: one ActiveGolden, multiplier in [10,100], GoldenSpawned',
    () {
      int? goodSeed;
      for (var s = 0; s < 5000; s++) {
        if (SeededRng(s).nextDouble() < 0.0333) {
          goodSeed = s;
          break;
        }
      }
      expect(goodSeed, isNotNull);
      final s = GameState(
        countries: {egypt: cs(egypt, unlocked: true)},
        unlockedContinents: unlockedAfrica,
      );
      final (ns, ev) = evaluateGoldens(
        s,
        content,
        const Duration(seconds: 1),
        now: t0,
        rng: SeededRng(goodSeed!),
      );
      expect(ns.activeGoldens, hasLength(1));
      final g = ns.activeGoldens.values.first;
      expect(g.multiplier, inInclusiveRange(10, 100));
      expect(
        g.expiresAt,
        equals(
          t0.add(
            const Duration(seconds: BalanceConfig.goldenSpawnExpirySeconds),
          ),
        ),
      );
      expect(ev.whereType<GoldenSpawned>(), hasLength(1));
    },
  );

  test(
    '12.6: expired map entries removed, GoldenExpired claimed: false, id order',
    () {
      final tPast = t0.subtract(const Duration(seconds: 1));
      final a = ActiveGolden(
        id: 'z_last',
        countryId: egypt,
        multiplier: 10,
        expiresAt: tPast,
      );
      final b = ActiveGolden(
        id: 'a_first',
        countryId: nigeria,
        multiplier: 11,
        expiresAt: tPast,
      );
      final s = GameState(
        countries: {
          egypt: cs(egypt, unlocked: true),
          nigeria: cs(nigeria, unlocked: true),
        },
        activeGoldens: {'a_first': b, 'z_last': a},
        unlockedContinents: unlockedAfrica,
      );
      final (ns, ev) = evaluateGoldens(
        s,
        content,
        Duration.zero,
        now: t0,
        rng: SeededRng(0),
      );
      expect(ns.activeGoldens, isEmpty);
      final gex = ev.whereType<GoldenExpired>().toList();
      expect(gex, hasLength(2));
      expect(gex[0].goldenId, equals('a_first'));
      expect(gex[0].claimed, isFalse);
      expect(gex[1].goldenId, equals('z_last'));
    },
  );

  test(
    '12.7: activeGoldenEffect expires, multiplier one, GoldenExpired claimed: true',
    () {
      const gid = 'eff1';
      final s = GameState(
        countries: {egypt: cs(egypt, unlocked: true)},
        activeGoldenEffect: ActiveGoldenEffect(
          goldenId: gid,
          multiplier: 50,
          expiresAt: DateTime.utc(2026, 1, 1, 0, 0, 0),
        ),
        goldenOpportunityMultiplier: Decimal.fromInt(50),
        unlockedContinents: unlockedAfrica,
      );
      final tNow = DateTime.utc(2026, 1, 1, 0, 0, 1);
      final (ns, ev) = evaluateGoldens(
        s,
        content,
        Duration.zero,
        now: tNow,
        rng: SeededRng(0),
      );
      expect(ns.activeGoldenEffect, isNull);
      expect(ns.goldenOpportunityMultiplier, equals(Decimal.one));
      expect(ev.whereType<GoldenExpired>().single.claimed, isTrue);
      expect(ev.whereType<GoldenExpired>().single.goldenId, equals(gid));
    },
  );

  test('12.8: no new spawn at max concurrent', () {
    int? goodSeed;
    for (var s = 0; s < 5000; s++) {
      if (SeededRng(s).nextDouble() < 0.0333) {
        goodSeed = s;
        break;
      }
    }
    final tBase = t0;
    const mult = 10;
    const expS = 3600;
    final m0 = {
      for (var i = 0; i < 3; i++)
        'id$i': ActiveGolden(
          id: 'id$i',
          countryId: egypt,
          multiplier: mult,
          expiresAt: tBase.add(Duration(seconds: expS + i)),
        ),
    };
    final s = GameState(
      countries: {egypt: cs(egypt, unlocked: true)},
      activeGoldens: m0,
      unlockedContinents: unlockedAfrica,
    );
    final (ns, ev) = evaluateGoldens(
      s,
      content,
      const Duration(seconds: 1),
      now: t0,
      rng: SeededRng(goodSeed!),
    );
    expect(ns.activeGoldens, hasLength(3));
    expect(ev.whereType<GoldenSpawned>(), isEmpty);
  });

  test('12.9: empty-unlocked, roll consumed, no spawn (AC #10)', () {
    int? goodSeed;
    for (var s = 0; s < 5000; s++) {
      if (SeededRng(s).nextDouble() < 0.0333) {
        goodSeed = s;
        break;
      }
    }
    final s = GameState(
      countries: {
        egypt: cs(egypt, unlocked: false),
        nigeria: cs(nigeria, unlocked: false),
        kenya: cs(kenya, unlocked: false),
      },
      unlockedContinents: unlockedAfrica,
    );
    final (ns, ev) = evaluateGoldens(
      s,
      content,
      const Duration(seconds: 1),
      now: t0,
      rng: SeededRng(goodSeed!),
    );
    expect(ns.activeGoldens, isEmpty);
    expect(ev.whereType<GoldenSpawned>(), isEmpty);
  });

  test('12.10: dt=0 no spawn', () {
    int? goodSeed;
    for (var s = 0; s < 5000; s++) {
      if (SeededRng(s).nextDouble() < 0.0333) {
        goodSeed = s;
        break;
      }
    }
    final s = GameState(
      countries: {egypt: cs(egypt, unlocked: true)},
      unlockedContinents: unlockedAfrica,
    );
    final (ns, ev) = evaluateGoldens(
      s,
      content,
      Duration.zero,
      now: t0,
      rng: SeededRng(goodSeed!),
    );
    expect(ns, equals(s));
    expect(ev, isEmpty);
  });

  test('12.11: sorted egypt, nigeria — nigeria at nextInt(2)==1', () {
    for (var seed = 0; seed < 10000; seed++) {
      final r = SeededRng(seed);
      final roll = r.nextDouble();
      if (roll >= 0.0333) continue;
      final idx = r.nextInt(2);
      if (idx != 1) continue;
      // Burn multiplier int for actual scheduler (same as range 91)
      r.nextInt(
        BalanceConfig.goldenMaxMultiplier -
            BalanceConfig.goldenMinMultiplier +
            1,
      );
      // Verify full evaluate picks nigeria
      final st = GameState(
        countries: {
          egypt: cs(egypt, unlocked: true),
          nigeria: cs(nigeria, unlocked: true),
        },
        unlockedContinents: unlockedAfrica,
      );
      final (ns, ev) = evaluateGoldens(
        st,
        content,
        const Duration(seconds: 1),
        now: t0,
        rng: SeededRng(seed),
      );
      final spawned = ev.whereType<GoldenSpawned>().toList();
      expect(spawned, hasLength(1));
      expect(spawned.first.countryId, equals(nigeria));
      expect(ns.activeGoldens.values.first.countryId, equals(nigeria));
      return;
    }
    fail('no seed with spawn + nextInt(2)==1 found');
  });
}
