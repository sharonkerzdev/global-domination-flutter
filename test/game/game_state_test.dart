import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/boosts/boost_state.dart';
import 'package:global_domination/game/features/daily_rewards/daily_streak.dart';
import 'package:global_domination/game/features/missions/mission_state.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/intel.dart';

import '../helpers/daily_rewards_test_json.dart';

void main() {
  group('GameState', () {
    test('can be constructed with default args', () {
      final state = GameState();
      expect(state, isA<GameState>());
    });

    test('equality: two default GameState instances are equal', () {
      final a = GameState();
      final b = GameState();
      expect(a, equals(b));
    });

    test(
      'hashCode: two default GameState instances have the same hashCode',
      () {
        final a = GameState();
        final b = GameState();
        expect(a.hashCode, equals(b.hashCode));
      },
    );

    test('toString returns expected representation', () {
      expect(
        GameState().toString(),
        equals(
          'GameState(countries: 0 entries, totalInfluence: Influence(0), '
          'totalIntel: Intel(0), dailyStreak: DailyStreak(day: 0, lastClaimDate: null), '
          'activeMissions: 0, completedMissionIds: 0, '
          'unlockedContinents: 0, reachedMilestones: 0, continentCompletions: 0, '
          'earnedAchievementIds: 0, '
          'activeGlobalUpgradeIds: 0, goldenOpportunityMultiplier: 1, '
          'activeBoost: null, activeGoldens: 0, activeGoldenEffect: null)',
        ),
      );
    });

    test('copyWith returns an equal GameState', () {
      final original = GameState();
      final copy = original.copyWith();
      expect(copy, equals(original));
    });

    test('equality includes unlockedContinents', () {
      const id = ContinentId('africa');
      final a = GameState(unlockedContinents: {id: true});
      final b = GameState(unlockedContinents: {id: true});
      final c = GameState(unlockedContinents: {id: false});
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('equality includes totalIntel', () {
      final a = GameState(totalIntel: Intel(Decimal.fromInt(10)));
      final b = GameState(totalIntel: Intel(Decimal.fromInt(10)));
      final c = GameState(totalIntel: Intel(Decimal.fromInt(5)));
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('equality includes dailyStreak', () {
      final t = DateTime.utc(2026, 1, 1);
      final a = GameState(dailyStreak: DailyStreak(day: 1, lastClaimDate: t));
      final b = GameState(dailyStreak: DailyStreak(day: 1, lastClaimDate: t));
      final c = GameState(dailyStreak: DailyStreak.empty);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith round-trips dailyStreak', () {
      final t = DateTime.utc(2026, 2, 1);
      final s = GameState(dailyStreak: DailyStreak.empty);
      final u = s.copyWith(dailyStreak: DailyStreak(day: 2, lastClaimDate: t));
      expect(u.dailyStreak, equals(DailyStreak(day: 2, lastClaimDate: t)));
    });

    test('equality includes activeBoost', () {
      final t1 = DateTime.utc(2026, 1, 1);
      final t2 = DateTime.utc(2026, 1, 2);
      final boost = BoostState(multiplier: Decimal.parse('2'), expiresAt: t1);
      final a = GameState(activeBoost: boost);
      final b = GameState(
        activeBoost: BoostState(multiplier: Decimal.parse('2'), expiresAt: t1),
      );
      final c = GameState(
        activeBoost: BoostState(multiplier: Decimal.parse('2'), expiresAt: t2),
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith clears activeBoost back to null', () {
      final s = GameState(
        activeBoost: BoostState(
          multiplier: Decimal.parse('2'),
          expiresAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final cleared = s.copyWith(activeBoost: null);
      expect(cleared.activeBoost, isNull);
    });

    test('equality includes reachedMilestones nested sets', () {
      const id = ContinentId('africa');
      final a = GameState(
        reachedMilestones: {
          id: {25, 50},
        },
      );
      final b = GameState(
        reachedMilestones: {
          id: {25, 50},
        },
      );
      final c = GameState(
        reachedMilestones: {
          id: {25},
        },
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith round-trips reachedMilestones', () {
      const id = ContinentId('africa');
      final s = GameState(
        reachedMilestones: {
          id: {25},
        },
      );
      final t = s.copyWith(
        reachedMilestones: {
          id: {25, 50},
        },
      );
      expect(t.reachedMilestones[id], {25, 50});
    });

    ContentRegistry minimalContent({required String missionsJson}) {
      return ContentRegistry.fromJsonStrings(
        countriesJson:
            '[{"id":"egypt","continent":"africa","baseInfluence":"1","unlockCost":"0","tier":1,"generationSeconds":1}]',
        continentsJson:
            '[{"id":"africa","name":"Africa","unlockThreshold":"0","completionBonus":"0","milestoneRewards":[]}]',
        leadersJson: '[]',
        achievementsJson: '[]',
        missionsJson: missionsJson,
        globalUpgradesJson: '[]',
        dailyRewardsJson: testDailyRewardsJson(),
      );
    }

    final fiveMissionsJson = jsonEncode([
      {
        'id': 'm1',
        'name': 'M1',
        'conditionType': 'tap_countries_n',
        'conditionParams': {'count': 1},
        'rewardIntel': '1',
      },
      {
        'id': 'm2',
        'name': 'M2',
        'conditionType': 'tap_countries_n',
        'conditionParams': {'count': 1},
        'rewardIntel': '1',
      },
      {
        'id': 'm3',
        'name': 'M3',
        'conditionType': 'tap_countries_n',
        'conditionParams': {'count': 1},
        'rewardIntel': '1',
      },
      {
        'id': 'm4',
        'name': 'M4',
        'conditionType': 'tap_countries_n',
        'conditionParams': {'count': 1},
        'rewardIntel': '1',
      },
      {
        'id': 'm5',
        'name': 'M5',
        'conditionType': 'tap_countries_n',
        'conditionParams': {'count': 1},
        'rewardIntel': '1',
      },
    ]);

    test('initialSeed fills activeMissions up to missionCatalogSize', () {
      final c = minimalContent(missionsJson: fiveMissionsJson);
      final s = GameState.initialSeed(c);
      expect(s.activeMissions.length, BalanceConfig.missionCatalogSize);
      expect(s.totalIntel, Intel.zero);
      expect(s.completedMissionIds, isEmpty);
    });

    test('initialSeed uses fewer slots when catalog is short', () {
      final two = jsonEncode([
        {
          'id': 'a',
          'name': 'A',
          'conditionType': 'tap_countries_n',
          'conditionParams': {'count': 1},
          'rewardIntel': '1',
        },
        {
          'id': 'b',
          'name': 'B',
          'conditionType': 'tap_countries_n',
          'conditionParams': {'count': 1},
          'rewardIntel': '1',
        },
      ]);
      final c = minimalContent(missionsJson: two);
      final s = GameState.initialSeed(c);
      expect(s.activeMissions.length, 2);
    });

    test('equality distinguishes activeMissions progress', () {
      final a = MissionState(
        id: 'x',
        progress: 0,
        target: 3,
        rewardIntel: Intel.zero,
      );
      final b = MissionState(
        id: 'x',
        progress: 1,
        target: 3,
        rewardIntel: Intel.zero,
      );
      expect(
        GameState(activeMissions: [a]),
        isNot(equals(GameState(activeMissions: [b]))),
      );
    });

    test('equality distinguishes completedMissionIds', () {
      expect(
        GameState(completedMissionIds: {'a'}),
        isNot(equals(GameState(completedMissionIds: {'b'}))),
      );
    });

    test('copyWith swaps activeMissions completedMissionIds totalIntel', () {
      final m = MissionState(
        id: 'z',
        progress: 0,
        target: 1,
        rewardIntel: Intel(Decimal.one),
      );
      final base = GameState();
      final t1 = base.copyWith(totalIntel: Intel(Decimal.fromInt(9)));
      expect(t1.totalIntel, Intel(Decimal.fromInt(9)));
      final t2 = base.copyWith(activeMissions: [m]);
      expect(t2.activeMissions.single, m);
      final t3 = base.copyWith(completedMissionIds: {'done'});
      expect(t3.completedMissionIds, {'done'});
    });
  });
}
