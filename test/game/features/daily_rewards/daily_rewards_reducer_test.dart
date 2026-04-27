import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/content/content_load_exception.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/daily_rewards/daily_streak.dart';
import 'package:global_domination/game/features/daily_rewards/daily_rewards_reducer.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';

import '../../../helpers/achievements_fixture.dart';
import '../../../helpers/daily_rewards_test_json.dart';

ContentRegistry _fixture() {
  return ContentRegistry.fromJsonStrings(
    countriesJson:
        '[{"id":"egypt","continent":"africa","baseInfluence":"1","unlockCost":"0","tier":1,"generationSeconds":1}]',
    continentsJson:
        '[{"id":"africa","name":"Africa","unlockThreshold":"0","completionBonus":"0","milestoneRewards":[]}]',
    leadersJson: '[]',
    achievementsJson: trivial27AchievementsJson(),
    missionsJson: '[]',
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

void main() {
  final content = _fixture();
  const claim = ClaimDailyReward();

  group('DailyStreak', () {
    test('value equality and toString', () {
      const a = DailyStreak(day: 0, lastClaimDate: null);
      const b = DailyStreak.empty;
      expect(a, equals(b));
      expect(a.toString(), equals('DailyStreak(day: 0, lastClaimDate: null)'));
    });
  });

  group('dailyRewardAvailable', () {
    test('true when lastClaimDate is null', () {
      final s = GameState();
      expect(dailyRewardAvailable(s, DateTime(2026, 4, 25, 12, 0)), isTrue);
    });

    test('false on same local calendar day', () {
      final t = DateTime(2026, 4, 25, 8, 0);
      final s = GameState(dailyStreak: DailyStreak(day: 1, lastClaimDate: t));
      expect(dailyRewardAvailable(s, DateTime(2026, 4, 25, 18, 0)), isFalse);
    });

    test('true across local midnight (calendar, not 24h)', () {
      final last = DateTime(2026, 4, 25, 23, 59, 59, 999);
      final s = GameState(
        dailyStreak: DailyStreak(day: 1, lastClaimDate: last),
      );
      final now = DateTime(2026, 4, 26, 0, 0, 0, 1);
      expect(dailyRewardAvailable(s, now), isTrue);
    });

    test('false when lastClaimDate is after now local calendar day', () {
      final future = DateTime(2026, 4, 26, 8, 0);
      final s = GameState(
        dailyStreak: DailyStreak(day: 1, lastClaimDate: future),
      );
      expect(dailyRewardAvailable(s, DateTime(2026, 4, 25, 8, 0)), isFalse);
    });
  });

  group('applyClaimDailyReward', () {
    test('first ever claim: day 1, totals and event', () {
      final s = GameState();
      final now = DateTime(2026, 4, 25, 12, 0);
      final r = applyClaimDailyReward(s, content, claim, now: now);
      expect(r.isSuccess, isTrue);
      final (ns, ev) = r.valueOrNull!;
      expect(
        ev,
        equals(
          DailyRewardClaimed(
            now,
            day: 1,
            influenceReward: Influence(Decimal.one),
            intelReward: Intel(Decimal.parse('10')),
          ),
        ),
      );
      expect(ns.dailyStreak, equals(DailyStreak(day: 1, lastClaimDate: now)));
      expect(ns.totalInfluence, equals(Influence(Decimal.one)));
      expect(ns.totalIntel, equals(Intel(Decimal.parse('10'))));
    });

    test('consecutive: prior day 3, claim today -> day 4', () {
      final yesterday = DateTime(2026, 4, 24, 8, 0);
      final today = DateTime(2026, 4, 25, 8, 0);
      final s = GameState(
        dailyStreak: DailyStreak(day: 3, lastClaimDate: yesterday),
        totalInfluence: Influence.zero,
        totalIntel: Intel.zero,
      );
      final r = applyClaimDailyReward(s, content, claim, now: today);
      expect(r.isSuccess, isTrue);
      final (ns, ev) = r.valueOrNull!;
      final claimed = ev as DailyRewardClaimed;
      expect(claimed.day, 4);
      expect(ns.totalInfluence, equals(Influence(Decimal.parse('4'))));
      expect(ns.totalIntel, equals(Intel(Decimal.parse('40'))));
    });

    test('day 7 consecutive -> cycles to day 1 reward', () {
      final y = DateTime(2026, 4, 30, 8, 0);
      final t = DateTime(2026, 5, 1, 8, 0);
      final s = GameState(
        dailyStreak: DailyStreak(day: 7, lastClaimDate: y),
        totalInfluence: Influence.zero,
        totalIntel: Intel.zero,
      );
      final r = applyClaimDailyReward(s, content, claim, now: t);
      final (ns, ev) = r.valueOrNull!;
      final claimed = ev as DailyRewardClaimed;
      expect(claimed.day, 1);
      expect(claimed.influenceReward, equals(Influence(Decimal.one)));
      expect(ns.dailyStreak.day, 1);
    });

    test('skip >1 day: reset to 1, no clawback', () {
      final longAgo = DateTime(2026, 4, 20, 8, 0);
      final today = DateTime(2026, 4, 25, 8, 0);
      final s = GameState(
        dailyStreak: DailyStreak(day: 5, lastClaimDate: longAgo),
        totalInfluence: Influence(Decimal.parse('9999')),
        totalIntel: Intel(Decimal.parse('500')),
      );
      final r = applyClaimDailyReward(s, content, claim, now: today);
      expect(r.isSuccess, isTrue);
      final (ns, ev) = r.valueOrNull!;
      expect((ev as DailyRewardClaimed).day, 1);
      expect(ns.totalInfluence, equals(Influence(Decimal.parse('10000'))));
      expect(ns.totalIntel, equals(Intel(Decimal.parse('510'))));
    });

    test('double same-day claim: failure, unchanged state', () {
      final now = DateTime(2026, 4, 25, 12, 0);
      final s = GameState(
        dailyStreak: DailyStreak(day: 1, lastClaimDate: now),
        totalInfluence: Influence(Decimal.parse('1')),
        totalIntel: Intel(Decimal.parse('10')),
      );
      final r = applyClaimDailyReward(s, content, claim, now: now);
      expect(r.isFailure, isTrue);
      expect(
        r.errorOrNull,
        const GameError.userLocked(reason: 'daily_reward_already_claimed'),
      );
    });

    test('future lastClaimDate: failure, unchanged state', () {
      final now = DateTime(2026, 4, 25, 12, 0);
      final s = GameState(
        dailyStreak: DailyStreak(
          day: 1,
          lastClaimDate: DateTime(2026, 4, 26, 12, 0),
        ),
        totalInfluence: Influence(Decimal.parse('1')),
        totalIntel: Intel(Decimal.parse('10')),
      );
      final r = applyClaimDailyReward(s, content, claim, now: now);
      expect(r.isFailure, isTrue);
      expect(
        r.errorOrNull,
        const GameError.userLocked(reason: 'daily_reward_already_claimed'),
      );
    });

    test('missing daily reward content returns invariant failure', () {
      final badContent = ContentRegistry(
        countries: content.countries,
        continents: content.continents,
        leaders: content.leaders,
        achievements: content.achievements,
        missions: content.missions,
        globalUpgrades: content.globalUpgrades,
        dailyRewards: const [],
      );
      final r = applyClaimDailyReward(
        GameState(),
        badContent,
        claim,
        now: DateTime(2026, 4, 25, 12, 0),
      );
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull, isA<InvariantBroken>());
    });

    test('DST: local day advance remains one calendar step', () {
      final a = DateTime(2026, 3, 14, 23, 0);
      final b = DateTime(2026, 3, 15, 23, 0);
      final s = GameState(
        dailyStreak: DailyStreak(day: 1, lastClaimDate: a),
        totalInfluence: Influence.zero,
        totalIntel: Intel.zero,
      );
      final r = applyClaimDailyReward(s, content, claim, now: b);
      expect(r.isSuccess, isTrue);
    });
  });

  group('ContentRegistry daily reward parse', () {
    const countriesJson =
        '[{"id":"egypt","continent":"africa","baseInfluence":"1","unlockCost":"0","tier":1,"generationSeconds":1}]';
    const continentsJson =
        '[{"id":"africa","name":"Africa","unlockThreshold":"0","completionBonus":"0","milestoneRewards":[]}]';

    test('wrong length (6) throws', () {
      final bad6 = jsonEncode([
        for (var d = 1; d <= 6; d++)
          {'day': d, 'influenceReward': '$d', 'intelReward': '${d * 10}'},
      ]);
      expect(
        () => ContentRegistry.fromJsonStrings(
          countriesJson: countriesJson,
          continentsJson: continentsJson,
          leadersJson: '[]',
          achievementsJson: trivial27AchievementsJson(),
          missionsJson: '[]',
          globalUpgradesJson: '[]',
          dailyRewardsJson: bad6,
        ),
        throwsA(
          isA<ContentLoadException>().having(
            (e) => e.message,
            'message',
            contains('7'),
          ),
        ),
      );
    });

    test('out-of-order days: throws', () {
      final ooo = jsonEncode([
        {'day': 1, 'influenceReward': '1', 'intelReward': '10'},
        {'day': 2, 'influenceReward': '2', 'intelReward': '20'},
        {'day': 4, 'influenceReward': '4', 'intelReward': '40'},
        {'day': 3, 'influenceReward': '3', 'intelReward': '30'},
        {'day': 5, 'influenceReward': '5', 'intelReward': '50'},
        {'day': 6, 'influenceReward': '6', 'intelReward': '60'},
        {'day': 7, 'influenceReward': '7', 'intelReward': '70'},
      ]);
      expect(
        () => ContentRegistry.fromJsonStrings(
          countriesJson: countriesJson,
          continentsJson: continentsJson,
          leadersJson: '[]',
          achievementsJson: trivial27AchievementsJson(),
          missionsJson: '[]',
          globalUpgradesJson: '[]',
          dailyRewardsJson: ooo,
        ),
        throwsA(isA<ContentLoadException>()),
      );
    });

    test('duplicate day throws', () {
      final dup = jsonEncode([
        for (var d in [1, 2, 2, 4, 5, 6, 7])
          {'day': d, 'influenceReward': '1', 'intelReward': '1'},
      ]);
      expect(
        () => ContentRegistry.fromJsonStrings(
          countriesJson: countriesJson,
          continentsJson: continentsJson,
          leadersJson: '[]',
          achievementsJson: trivial27AchievementsJson(),
          missionsJson: '[]',
          globalUpgradesJson: '[]',
          dailyRewardsJson: dup,
        ),
        throwsA(isA<ContentLoadException>()),
      );
    });

    test('unparseable decimal throws', () {
      final bad = jsonEncode([
        {'day': 1, 'influenceReward': '???', 'intelReward': '1'},
        for (var d = 2; d <= 7; d++)
          {'day': d, 'influenceReward': '1', 'intelReward': '1'},
      ]);
      expect(
        () => ContentRegistry.fromJsonStrings(
          countriesJson: countriesJson,
          continentsJson: continentsJson,
          leadersJson: '[]',
          achievementsJson: trivial27AchievementsJson(),
          missionsJson: '[]',
          globalUpgradesJson: '[]',
          dailyRewardsJson: bad,
        ),
        throwsA(isA<ContentLoadException>()),
      );
    });
  });
}
