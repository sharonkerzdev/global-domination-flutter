import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/missions/mission_state.dart';
import 'package:global_domination/game/features/missions/missions_reducer.dart';
import 'package:global_domination/game/features/missions/missions_seed.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';

import '../../../helpers/daily_rewards_test_json.dart';

const _minimalCountries = '''
[{"id":"egypt","continent":"africa","baseInfluence":"1","unlockCost":"0","tier":1,"generationSeconds":1}]
''';

const _minimalContinents = '''
[{"id":"africa","name":"Africa","unlockThreshold":"0","completionBonus":"0","milestoneRewards":[]}]
''';

String _missionsCatalog5() => jsonEncode([
  {
    'id': 'tap_50_countries',
    'name': 'Tap 50 countries',
    'conditionType': 'tap_countries_n',
    'conditionParams': {'count': 50},
    'rewardIntel': '10',
  },
  {
    'id': 'purchase_5_upgrades',
    'name': 'Purchase 5 upgrades',
    'conditionType': 'purchase_upgrades_n',
    'conditionParams': {'count': 5},
    'rewardIntel': '15',
  },
  {
    'id': 'unlock_2_countries',
    'name': 'Unlock 2 countries',
    'conditionType': 'unlock_countries_n',
    'conditionParams': {'count': 2},
    'rewardIntel': '25',
  },
  {
    'id': 'hire_3_leaders',
    'name': 'Hire 3 leaders',
    'conditionType': 'hire_leaders_n',
    'conditionParams': {'count': 3},
    'rewardIntel': '40',
  },
  {
    'id': 'unlock_1_continent',
    'name': 'Unlock a new continent',
    'conditionType': 'unlock_continents_n',
    'conditionParams': {'count': 1},
    'rewardIntel': '100',
  },
]);

ContentRegistry _registry({String? missionsJson}) {
  return ContentRegistry.fromJsonStrings(
    countriesJson: _minimalCountries,
    continentsJson: _minimalContinents,
    leadersJson: '[]',
    achievementsJson: '[]',
    missionsJson: missionsJson ?? _missionsCatalog5(),
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

GameState _stateWithMissions(List<MissionState> missions, {Set<String>? done}) {
  return GameState(
    activeMissions: List.unmodifiable(missions),
    completedMissionIds: Set.unmodifiable(done ?? const <String>{}),
  );
}

void main() {
  final at = DateTime.utc(2026, 4, 26);

  group('seedActiveMissions', () {
    test('5 defs + catalog size 3 → first three in declaration order', () {
      final c = _registry();
      final seeded = seedActiveMissions(c);
      expect(seeded.length, BalanceConfig.missionCatalogSize);
      expect(seeded[0].id, 'tap_50_countries');
      expect(seeded[1].id, 'purchase_5_upgrades');
      expect(seeded[2].id, 'unlock_2_countries');
      expect(seeded.every((m) => m.progress == 0), isTrue);
    });

    test('completedIds skips first; fills from indices 1,2,3', () {
      final c = _registry();
      final seeded = seedActiveMissions(c, completedIds: {'tap_50_countries'});
      expect(seeded.length, 3);
      expect(seeded[0].id, 'purchase_5_upgrades');
      expect(seeded[1].id, 'unlock_2_countries');
      expect(seeded[2].id, 'hire_3_leaders');
    });

    test('empty catalog → empty list', () {
      final c = _registry(missionsJson: '[]');
      expect(seedActiveMissions(c), isEmpty);
    });
  });

  group('evaluateMissions', () {
    test('Tick → identical state and empty events', () {
      final c = _registry();
      final s = GameState.initialSeed(c);
      final (next, ev) = evaluateMissions(s, c, Tick(at), at);
      expect(identical(next, s), isTrue);
      expect(ev, isEmpty);
    });

    test('CountryTapped advances tap_countries_n by 1; no completion', () {
      final c = _registry();
      final ms = MissionState(
        id: 'tap_50_countries',
        progress: 0,
        target: 2,
        rewardIntel: Intel(Decimal.fromInt(10)),
      );
      final s = _stateWithMissions([ms]);
      final (next, ev) = evaluateMissions(
        s,
        c,
        CountryTapped(
          at,
          countryId: const CountryId('egypt'),
          collected: Influence(Decimal.one),
        ),
        at,
      );
      expect(ev, isEmpty);
      expect(next.activeMissions.single.progress, 1);
    });

    test('completion emits MissionCompleted + MissionRotated and intel', () {
      final c = _registry();
      final ms = MissionState(
        id: 'tap_50_countries',
        progress: 1,
        target: 2,
        rewardIntel: Intel(Decimal.fromInt(10)),
      );
      final s = _stateWithMissions([ms]);
      final (next, ev) = evaluateMissions(
        s,
        c,
        CountryTapped(
          at,
          countryId: const CountryId('egypt'),
          collected: Influence(Decimal.one),
        ),
        at,
      );
      expect(ev.length, 2);
      expect(ev[0], isA<MissionCompleted>());
      expect(ev[1], isA<MissionRotated>());
      final mc = ev[0] as MissionCompleted;
      expect(mc.missionId, 'tap_50_countries');
      expect(mc.rewardIntel, Intel(Decimal.fromInt(10)));
      expect(next.totalIntel, Intel(Decimal.fromInt(10)));
      expect(next.completedMissionIds, contains('tap_50_countries'));
      expect(next.activeMissions.single.id, 'purchase_5_upgrades');
      final mr = ev[1] as MissionRotated;
      expect(mr.oldMissionId, 'tap_50_countries');
      expect(mr.newMissionId, 'purchase_5_upgrades');
    });

    test('rotation with no eligible def removes slot (AC #3)', () {
      final solo = jsonEncode([
        {
          'id': 'solo_tap',
          'name': 'Solo',
          'conditionType': 'tap_countries_n',
          'conditionParams': {'count': 1},
          'rewardIntel': '7',
        },
      ]);
      final c = _registry(missionsJson: solo);
      final s = GameState.initialSeed(c);
      expect(s.activeMissions.length, 1);

      final (next, ev) = evaluateMissions(
        s,
        c,
        CountryTapped(
          at,
          countryId: const CountryId('egypt'),
          collected: Influence(Decimal.one),
        ),
        at,
      );
      expect(next.activeMissions, isEmpty);
      expect(next.completedMissionIds, contains('solo_tap'));
      expect(next.totalIntel, Intel(Decimal.fromInt(7)));
      expect(ev.length, 2);
      expect(ev[0], isA<MissionCompleted>());
      final rot = ev[1] as MissionRotated;
      expect(rot.oldMissionId, 'solo_tap');
      expect(rot.newMissionId, isNull);
    });

    test('two tap_countries_n slots both advance on one tap', () {
      final twoTap = jsonEncode([
        {
          'id': 'tap_a',
          'name': 'A',
          'conditionType': 'tap_countries_n',
          'conditionParams': {'count': 2},
          'rewardIntel': '1',
        },
        {
          'id': 'tap_b',
          'name': 'B',
          'conditionType': 'tap_countries_n',
          'conditionParams': {'count': 2},
          'rewardIntel': '2',
        },
      ]);
      final c = _registry(missionsJson: twoTap);
      final a = MissionState(
        id: 'tap_a',
        progress: 0,
        target: 2,
        rewardIntel: Intel(Decimal.one),
      );
      final b = MissionState(
        id: 'tap_b',
        progress: 0,
        target: 2,
        rewardIntel: Intel(Decimal.parse('2')),
      );
      final s = _stateWithMissions([a, b]);
      final (next, ev) = evaluateMissions(
        s,
        c,
        CountryTapped(
          at,
          countryId: const CountryId('egypt'),
          collected: Influence(Decimal.one),
        ),
        at,
      );
      expect(next.activeMissions[0].progress, 1);
      expect(next.activeMissions[1].progress, 1);
      expect(ev, isEmpty);
    });

    test('two completed slots emit all completions before rotations', () {
      final twoTap = jsonEncode([
        {
          'id': 'tap_a',
          'name': 'A',
          'conditionType': 'tap_countries_n',
          'conditionParams': {'count': 1},
          'rewardIntel': '1',
        },
        {
          'id': 'tap_b',
          'name': 'B',
          'conditionType': 'tap_countries_n',
          'conditionParams': {'count': 1},
          'rewardIntel': '2',
        },
      ]);
      final c = _registry(missionsJson: twoTap);
      final s = _stateWithMissions([
        MissionState(
          id: 'tap_a',
          progress: 0,
          target: 1,
          rewardIntel: Intel(Decimal.one),
        ),
        MissionState(
          id: 'tap_b',
          progress: 0,
          target: 1,
          rewardIntel: Intel(Decimal.fromInt(2)),
        ),
      ]);

      final (next, ev) = evaluateMissions(
        s,
        c,
        CountryTapped(
          at,
          countryId: const CountryId('egypt'),
          collected: Influence(Decimal.one),
        ),
        at,
      );

      expect(ev, [
        isA<MissionCompleted>().having(
          (e) => e.missionId,
          'missionId',
          'tap_a',
        ),
        isA<MissionCompleted>().having(
          (e) => e.missionId,
          'missionId',
          'tap_b',
        ),
        isA<MissionRotated>().having(
          (e) => e.oldMissionId,
          'oldMissionId',
          'tap_a',
        ),
        isA<MissionRotated>().having(
          (e) => e.oldMissionId,
          'oldMissionId',
          'tap_b',
        ),
      ]);
      expect(next.completedMissionIds, containsAll(['tap_a', 'tap_b']));
      expect(next.totalIntel, Intel(Decimal.fromInt(3)));
    });

    test('golden_claimed_count never advances on CountryTapped', () {
      final goldenJson = jsonEncode([
        {
          'id': 'g1',
          'name': 'Golden',
          'conditionType': 'golden_claimed_count',
          'conditionParams': {'count': 1},
          'rewardIntel': '5',
        },
      ]);
      final c = _registry(missionsJson: goldenJson);
      final ms = MissionState(
        id: 'g1',
        progress: 0,
        target: 1,
        rewardIntel: Intel(Decimal.fromInt(5)),
      );
      final s = _stateWithMissions([ms]);
      final (next, ev) = evaluateMissions(
        s,
        c,
        CountryTapped(
          at,
          countryId: const CountryId('egypt'),
          collected: Influence(Decimal.one),
        ),
        at,
      );
      expect(identical(next, s), isTrue);
      expect(ev, isEmpty);
    });

    test('orphaned active mission id is skipped without throw', () {
      final c = _registry();
      final s = _stateWithMissions([
        MissionState(
          id: 'missing_from_content',
          progress: 0,
          target: 1,
          rewardIntel: Intel.zero,
        ),
      ]);
      final (next, ev) = evaluateMissions(
        s,
        c,
        CountryTapped(
          at,
          countryId: const CountryId('egypt'),
          collected: Influence(Decimal.one),
        ),
        at,
      );
      expect(identical(next, s), isTrue);
      expect(ev, isEmpty);
    });
  });

  group('MissionState', () {
    test('value semantics and copyWith', () {
      final a = MissionState(
        id: 'x',
        progress: 1,
        target: 3,
        rewardIntel: Intel(Decimal.fromInt(4)),
      );
      final b = MissionState(
        id: 'x',
        progress: 1,
        target: 3,
        rewardIntel: Intel(Decimal.fromInt(4)),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a.toString(), contains('MissionState'));
      final c = a.copyWith(progress: 2);
      expect(c.progress, 2);
      expect(c.id, 'x');
      expect(c.target, 3);
      expect(c.rewardIntel, Intel(Decimal.fromInt(4)));
    });
  });
}
