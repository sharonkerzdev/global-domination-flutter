import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/continents/milestones_reducer.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

import '../../../helpers/daily_rewards_test_json.dart';

List<Map<String, Object?>> _fourInfluenceRewards() => [
  {'percent': 25, 'rewardType': 'influence', 'rewardValue': '10'},
  {'percent': 50, 'rewardType': 'influence', 'rewardValue': '20'},
  {'percent': 75, 'rewardType': 'influence', 'rewardValue': '30'},
  {'percent': 100, 'rewardType': 'influence', 'rewardValue': '40'},
];

ContentRegistry _contentFourCountryContinent() {
  final continents = jsonEncode([
    {
      'id': 'africa',
      'name': 'Africa',
      'unlockThreshold': '0',
      'completionBonus': '0.25',
      'milestoneRewards': _fourInfluenceRewards(),
    },
  ]);
  final countries = jsonEncode([
    for (var i = 0; i < 4; i++)
      {
        'id': 'c$i',
        'continent': 'africa',
        'baseInfluence': '1',
        'unlockCost': '0',
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
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

GameState _stateAllLocked(ContentRegistry content) {
  return GameState(
    countries: {
      for (final id in content.countries.keys)
        id: CountryState(
          id: id,
          unlocked: false,
          ipLevel: 0,
          leaderTier: LeaderTier.none,
          bankedInfluence: Influence.zero,
          lastCollectedAt: null,
        ),
    },
    unlockedContinents: {const ContinentId('africa'): true},
  );
}

GameState _unlockFirstK(ContentRegistry content, int k) {
  final ids = content.countries.keys.toList();
  return GameState(
    countries: {
      for (var i = 0; i < ids.length; i++)
        ids[i]: CountryState(
          id: ids[i],
          unlocked: i < k,
          ipLevel: i < k ? 1 : 0,
          leaderTier: LeaderTier.none,
          bankedInfluence: Influence.zero,
          lastCollectedAt: null,
        ),
    },
    unlockedContinents: {const ContinentId('africa'): true},
  );
}

void main() {
  final now = DateTime.utc(2026, 4, 24);
  final content4 = _contentFourCountryContinent();

  test('empty ownership → no events, unchanged state', () {
    final s = _stateAllLocked(content4);
    final (next, ev) = evaluateMilestones(s, content4, now);
    expect(ev, isEmpty);
    expect(identical(next, s), isTrue);
  });

  test('0→1 owned fires MilestoneReached(25) and grants influence', () {
    final s0 = _stateAllLocked(content4);
    final s1 = _unlockFirstK(content4, 1);
    final (_, ev0) = evaluateMilestones(s0, content4, now);
    expect(ev0, isEmpty);

    final (next, ev) = evaluateMilestones(s1, content4, now);
    expect(ev, hasLength(1));
    expect(ev.single, isA<MilestoneReached>());
    final m = ev.single as MilestoneReached;
    expect(m.percent, 25);
    expect(m.rewardType, 'influence');
    expect(next.totalInfluence, Influence(Decimal.parse('10')));
    expect(next.reachedMilestones[const ContinentId('africa')], {25});
  });

  test(
    '0→4 owned emits 25,50,75,100 milestones then ContinentCompleted in order',
    () {
      final s = _unlockFirstK(content4, 4);
      final (next, ev) = evaluateMilestones(s, content4, now);
      expect(ev, hasLength(5));
      expect(ev[0], isA<MilestoneReached>());
      expect((ev[0] as MilestoneReached).percent, 25);
      expect((ev[1] as MilestoneReached).percent, 50);
      expect((ev[2] as MilestoneReached).percent, 75);
      expect((ev[3] as MilestoneReached).percent, 100);
      expect(ev[4], isA<ContinentCompleted>());
      expect(
        next.totalInfluence,
        equals(
          Influence(
            Decimal.parse('10') +
                Decimal.parse('20') +
                Decimal.parse('30') +
                Decimal.parse('40'),
          ),
        ),
      );
    },
  );

  test('replay on post-state emits zero events (idempotent)', () {
    final s = _unlockFirstK(content4, 4);
    final (mid, ev1) = evaluateMilestones(s, content4, now);
    expect(ev1, isNotEmpty);
    final (end, ev2) = evaluateMilestones(mid, content4, now);
    expect(ev2, isEmpty);
    expect(end, equals(mid));
  });

  test(
    'permanentMultiplier emits event but does not change totalInfluence',
    () {
      final continents = jsonEncode([
        {
          'id': 'africa',
          'name': 'Africa',
          'unlockThreshold': '0',
          'completionBonus': '0.25',
          'milestoneRewards': [
            {
              'percent': 25,
              'rewardType': 'permanentMultiplier',
              'rewardValue': '1.5',
            },
            {'percent': 50, 'rewardType': 'influence', 'rewardValue': '1'},
            {'percent': 75, 'rewardType': 'influence', 'rewardValue': '1'},
            {'percent': 100, 'rewardType': 'influence', 'rewardValue': '1'},
          ],
        },
      ]);
      final countries = jsonEncode([
        for (var i = 0; i < 4; i++)
          {
            'id': 'c$i',
            'continent': 'africa',
            'baseInfluence': '1',
            'unlockCost': '0',
            'tier': 1,
            'generationSeconds': 1,
          },
      ]);
      final c = ContentRegistry.fromJsonStrings(
        countriesJson: countries,
        continentsJson: continents,
        leadersJson: '[]',
        achievementsJson: '[]',
        missionsJson: '[]',
        globalUpgradesJson: '[]',
        dailyRewardsJson: testDailyRewardsJson(),
      );
      final s = _unlockFirstK(c, 1);
      final (next, ev) = evaluateMilestones(s, c, now);
      expect(ev.first, isA<MilestoneReached>());
      expect((ev.first as MilestoneReached).rewardType, 'permanentMultiplier');
      expect(next.totalInfluence, Influence.zero);
    },
  );

  test(
    '100% milestone flips continentCompletions atomically with event emission',
    () {
      final c = ContentRegistry.fromJsonStrings(
        countriesJson: jsonEncode([
          for (var i = 0; i < 3; i++)
            {
              'id': 'c$i',
              'continent': 'africa',
              'baseInfluence': '1',
              'unlockCost': '0',
              'tier': 1,
              'generationSeconds': 1,
            },
        ]),
        continentsJson: jsonEncode([
          {
            'id': 'africa',
            'name': 'Africa',
            'unlockThreshold': '0',
            'completionBonus': '0.25',
            'milestoneRewards': _fourInfluenceRewards(),
          },
        ]),
        leadersJson: '[]',
        achievementsJson: '[]',
        missionsJson: '[]',
        globalUpgradesJson: '[]',
        dailyRewardsJson: testDailyRewardsJson(),
      );
      final s = _unlockFirstK(c, 3);
      expect(s.continentCompletions, isEmpty);
      expect(s.reachedMilestones, isEmpty);

      final (next, ev) = evaluateMilestones(s, c, now);
      final africaId = const ContinentId('africa');
      expect(next.continentCompletions[africaId], isTrue);
      expect(next.reachedMilestones[africaId], contains(100));

      final idx100 = ev.indexWhere(
        (e) => e is MilestoneReached && e.percent == 100,
      );
      expect(idx100, greaterThanOrEqualTo(0));
      expect(ev[idx100 + 1], isA<ContinentCompleted>());
      expect((ev[idx100 + 1] as ContinentCompleted).continentId, africaId);
    },
  );

  test(
    're-running evaluator on a complete continent is a no-op (loaded-from-save scenario)',
    () {
      final c = ContentRegistry.fromJsonStrings(
        countriesJson: jsonEncode([
          for (var i = 0; i < 3; i++)
            {
              'id': 'c$i',
              'continent': 'africa',
              'baseInfluence': '1',
              'unlockCost': '0',
              'tier': 1,
              'generationSeconds': 1,
            },
        ]),
        continentsJson: jsonEncode([
          {
            'id': 'africa',
            'name': 'Africa',
            'unlockThreshold': '0',
            'completionBonus': '0.25',
            'milestoneRewards': _fourInfluenceRewards(),
          },
        ]),
        leadersJson: '[]',
        achievementsJson: '[]',
        missionsJson: '[]',
        globalUpgradesJson: '[]',
        dailyRewardsJson: testDailyRewardsJson(),
      );
      final base = _unlockFirstK(c, 3);
      final (completed, ev1) = evaluateMilestones(base, c, now);
      expect(ev1, isNotEmpty);
      expect(
        completed.continentCompletions[const ContinentId('africa')],
        isTrue,
      );
      expect(
        completed.reachedMilestones[const ContinentId('africa')],
        contains(100),
      );

      final (next, ev2) = evaluateMilestones(completed, c, now);
      expect(ev2, isEmpty);
      expect(identical(next, completed), isTrue);
    },
  );

  test(
    'missing reached[100] with completion flag true does not re-emit completion',
    () {
      final c = ContentRegistry.fromJsonStrings(
        countriesJson: jsonEncode([
          for (var i = 0; i < 3; i++)
            {
              'id': 'c$i',
              'continent': 'africa',
              'baseInfluence': '1',
              'unlockCost': '0',
              'tier': 1,
              'generationSeconds': 1,
            },
        ]),
        continentsJson: jsonEncode([
          {
            'id': 'africa',
            'name': 'Africa',
            'unlockThreshold': '0',
            'completionBonus': '0.25',
            'milestoneRewards': _fourInfluenceRewards(),
          },
        ]),
        leadersJson: '[]',
        achievementsJson: '[]',
        missionsJson: '[]',
        globalUpgradesJson: '[]',
        dailyRewardsJson: testDailyRewardsJson(),
      );
      final loaded = _unlockFirstK(c, 3).copyWith(
        reachedMilestones: {
          const ContinentId('africa'): {25, 50, 75},
        },
        continentCompletions: {const ContinentId('africa'): true},
      );
      final (next, ev) = evaluateMilestones(loaded, c, now);
      expect(ev.whereType<ContinentCompleted>(), isEmpty);
      expect(
        ev.whereType<MilestoneReached>().any((e) => e.percent == 100),
        isFalse,
      );
      expect(identical(next, loaded), isTrue);
    },
  );

  test('partial unlock does not flip continentCompletions', () {
    final c = ContentRegistry.fromJsonStrings(
      countriesJson: jsonEncode([
        for (var i = 0; i < 3; i++)
          {
            'id': 'c$i',
            'continent': 'africa',
            'baseInfluence': '1',
            'unlockCost': '0',
            'tier': 1,
            'generationSeconds': 1,
          },
      ]),
      continentsJson: jsonEncode([
        {
          'id': 'africa',
          'name': 'Africa',
          'unlockThreshold': '0',
          'completionBonus': '0.25',
          'milestoneRewards': _fourInfluenceRewards(),
        },
      ]),
      leadersJson: '[]',
      achievementsJson: '[]',
      missionsJson: '[]',
      globalUpgradesJson: '[]',
      dailyRewardsJson: testDailyRewardsJson(),
    );
    final s = _unlockFirstK(c, 2);
    final (next, ev) = evaluateMilestones(s, c, now);
    expect(ev, isNotEmpty);
    expect(next.continentCompletions, isEmpty);
    expect(next.continentCompletions[const ContinentId('africa')], isNot(true));
  });

  test('N=19: 25% tier requires 4 countries owned', () {
    final continents = jsonEncode([
      {
        'id': 'africa',
        'name': 'Africa',
        'unlockThreshold': '0',
        'completionBonus': '0.25',
        'milestoneRewards': _fourInfluenceRewards(),
      },
    ]);
    final countries = jsonEncode([
      for (var i = 0; i < 19; i++)
        {
          'id': 'c$i',
          'continent': 'africa',
          'baseInfluence': '1',
          'unlockCost': '0',
          'tier': 1,
          'generationSeconds': 1,
        },
    ]);
    final c = ContentRegistry.fromJsonStrings(
      countriesJson: countries,
      continentsJson: continents,
      leadersJson: '[]',
      achievementsJson: '[]',
      missionsJson: '[]',
      globalUpgradesJson: '[]',
      dailyRewardsJson: testDailyRewardsJson(),
    );
    final s3 = _unlockFirstK(c, 3);
    final (_, ev3) = evaluateMilestones(s3, c, now);
    expect(ev3, isEmpty);

    final s4 = _unlockFirstK(c, 4);
    final (next, ev4) = evaluateMilestones(s4, c, now);
    expect(ev4, hasLength(1));
    expect((ev4.single as MilestoneReached).percent, 25);
    expect(next.reachedMilestones[const ContinentId('africa')], {25});
  });

  test('N=3: floor math allows 25% tier at zero owned', () {
    final continents = jsonEncode([
      {
        'id': 'africa',
        'name': 'Africa',
        'unlockThreshold': '0',
        'completionBonus': '0.25',
        'milestoneRewards': _fourInfluenceRewards(),
      },
    ]);
    final countries = jsonEncode([
      for (var i = 0; i < 3; i++)
        {
          'id': 'c$i',
          'continent': 'africa',
          'baseInfluence': '1',
          'unlockCost': '0',
          'tier': 1,
          'generationSeconds': 1,
        },
    ]);
    final c = ContentRegistry.fromJsonStrings(
      countriesJson: countries,
      continentsJson: continents,
      leadersJson: '[]',
      achievementsJson: '[]',
      missionsJson: '[]',
      globalUpgradesJson: '[]',
      dailyRewardsJson: testDailyRewardsJson(),
    );
    final s0 = _stateAllLocked(c);
    final (next, ev) = evaluateMilestones(s0, c, now);
    expect(ev, hasLength(1));
    expect((ev.single as MilestoneReached).percent, 25);
    expect(next.reachedMilestones[const ContinentId('africa')], {25});
  });

  test(
    'multi-continent: sorted continent ids, milestones then completions',
    () {
      final continents = jsonEncode([
        {
          'id': 'oceania',
          'name': 'Oceania',
          'unlockThreshold': '0',
          'completionBonus': '0.1',
          'milestoneRewards': _fourInfluenceRewards(),
        },
        {
          'id': 'africa',
          'name': 'Africa',
          'unlockThreshold': '0',
          'completionBonus': '0.25',
          'milestoneRewards': _fourInfluenceRewards(),
        },
      ]);
      final countries = jsonEncode([
        for (var i = 0; i < 4; i++)
          {
            'id': 'a$i',
            'continent': 'africa',
            'baseInfluence': '1',
            'unlockCost': '0',
            'tier': 1,
            'generationSeconds': 1,
          },
        for (var i = 0; i < 4; i++)
          {
            'id': 'o$i',
            'continent': 'oceania',
            'baseInfluence': '1',
            'unlockCost': '0',
            'tier': 1,
            'generationSeconds': 1,
          },
      ]);
      final c = ContentRegistry.fromJsonStrings(
        countriesJson: countries,
        continentsJson: continents,
        leadersJson: '[]',
        achievementsJson: '[]',
        missionsJson: '[]',
        globalUpgradesJson: '[]',
        dailyRewardsJson: testDailyRewardsJson(),
      );
      final countriesMap = <CountryId, CountryState>{};
      for (final id in c.countries.keys) {
        final unlocked = id.value.startsWith('a') || id.value.startsWith('o');
        countriesMap[id] = CountryState(
          id: id,
          unlocked: unlocked,
          ipLevel: unlocked ? 1 : 0,
          leaderTier: LeaderTier.none,
          bankedInfluence: Influence.zero,
          lastCollectedAt: null,
        );
      }
      final s = GameState(
        countries: countriesMap,
        unlockedContinents: {
          const ContinentId('africa'): true,
          const ContinentId('oceania'): true,
        },
      );
      final (_, ev) = evaluateMilestones(s, c, now);
      expect(ev, hasLength(10));
      final africaId = const ContinentId('africa');
      final oceaniaId = const ContinentId('oceania');
      expect((ev[0] as MilestoneReached).continentId, africaId);
      expect((ev[4] as ContinentCompleted).continentId, africaId);
      expect((ev[5] as MilestoneReached).continentId, oceaniaId);
      expect((ev[9] as ContinentCompleted).continentId, oceaniaId);
    },
  );
}
