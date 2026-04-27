import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/achievements/achievements_reducer.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/economy/income_calculator.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';

import '../../../helpers/achievements_fixture.dart';
import '../../../helpers/daily_rewards_test_json.dart';

ContentRegistry _registry(List<Map<String, dynamic>> leading) {
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
    achievementsJson: achievementsJson27(leading),
    missionsJson: '[]',
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

CountryState _cs(String id, {required bool unlocked, int ip = 0}) {
  return CountryState(
    id: CountryId(id),
    unlocked: unlocked,
    ipLevel: ip,
    leaderTier: LeaderTier.none,
    bankedInfluence: Influence.zero,
  );
}

void main() {
  final t0 = DateTime.utc(2026, 1, 1);
  final t1 = DateTime.utc(2026, 6, 1);

  test('no countries unlocked → no events, earned ids unchanged', () {
    final content = _registry([
      {
        'id': 'ach_one_country',
        'name': 'One',
        'conditionType': 'countriesUnlockedAtLeast',
        'conditionParams': {'count': 1},
        'rewardType': 'influenceMultiplier',
        'rewardValue': '0.10',
      },
    ]);
    final state = GameState(
      countries: {
        const CountryId('egypt'): _cs('egypt', unlocked: false),
        const CountryId('nigeria'): _cs('nigeria', unlocked: false),
      },
    );
    final (next, ev) = evaluateAchievements(state, content, t0);
    expect(identical(next, state), isTrue);
    expect(ev, isEmpty);
  });

  test('one country unlocked → AchievementEarned + id in set', () {
    final content = _registry([
      {
        'id': 'ach_one_country',
        'name': 'One',
        'conditionType': 'countriesUnlockedAtLeast',
        'conditionParams': {'count': 1},
        'rewardType': 'influenceMultiplier',
        'rewardValue': '0.10',
      },
    ]);
    final state = GameState(
      countries: {
        const CountryId('egypt'): _cs('egypt', unlocked: true),
        const CountryId('nigeria'): _cs('nigeria', unlocked: false),
      },
    );
    final (next, ev) = evaluateAchievements(state, content, t0);
    expect(next.earnedAchievementIds, contains('ach_one_country'));
    expect(ev, hasLength(1));
    expect(ev.single, isA<AchievementEarned>());
    final a = ev.single as AchievementEarned;
    expect(a.achievementId, 'ach_one_country');
    expect(a.rewardType, 'influenceMultiplier');
    expect(a.rewardValue, Decimal.parse('0.10'));
    expect(a.at, t0);
  });

  test('influence + country conditions fire in declaration order', () {
    final content = _registry([
      {
        'id': 'ach_country_first',
        'name': 'C',
        'conditionType': 'countriesUnlockedAtLeast',
        'conditionParams': {'count': 1},
        'rewardType': 'influenceMultiplier',
        'rewardValue': '0.05',
      },
      {
        'id': 'ach_influence_second',
        'name': 'I',
        'conditionType': 'totalInfluenceAtLeast',
        'conditionParams': {'value': '1000'},
        'rewardType': 'influenceMultiplier',
        'rewardValue': '0.07',
      },
    ]);
    final state = GameState(
      countries: {
        const CountryId('egypt'): _cs('egypt', unlocked: true),
        const CountryId('nigeria'): _cs('nigeria', unlocked: false),
      },
      totalInfluence: Influence(Decimal.parse('2000')),
    );
    final (_, ev) = evaluateAchievements(state, content, t0);
    expect(ev, hasLength(2));
    expect((ev[0] as AchievementEarned).achievementId, 'ach_country_first');
    expect((ev[1] as AchievementEarned).achievementId, 'ach_influence_second');
  });

  test('idempotent re-run returns same state ref and empty events', () {
    final content = _registry([
      {
        'id': 'ach_one_country',
        'name': 'One',
        'conditionType': 'countriesUnlockedAtLeast',
        'conditionParams': {'count': 1},
        'rewardType': 'influenceMultiplier',
        'rewardValue': '0.10',
      },
    ]);
    final state = GameState(
      countries: {
        const CountryId('egypt'): _cs('egypt', unlocked: true),
        const CountryId('nigeria'): _cs('nigeria', unlocked: false),
      },
    );
    final (mid, first) = evaluateAchievements(state, content, t0);
    expect(first, isNotEmpty);
    final (same, second) = evaluateAchievements(mid, content, t0);
    expect(identical(same, mid), isTrue);
    expect(second, isEmpty);
  });

  test('intel reward: event fires, totalIntel unchanged on GameState', () {
    final content = _registry([
      {
        'id': 'ach_intel_only',
        'name': 'Intel',
        'conditionType': 'countriesUnlockedAtLeast',
        'conditionParams': {'count': 1},
        'rewardType': 'intel',
        'rewardValue': '99',
      },
    ]);
    final s0 = GameState(
      countries: {
        const CountryId('egypt'): _cs('egypt', unlocked: true),
        const CountryId('nigeria'): _cs('nigeria', unlocked: false),
      },
      totalIntel: Intel(Decimal.parse('3')),
    );
    final intelBefore = s0.totalIntel;
    final (next, ev) = evaluateAchievements(s0, content, t0);
    expect(next.totalIntel, intelBefore);
    expect(ev.single, isA<AchievementEarned>());
    expect((ev.single as AchievementEarned).rewardType, 'intel');
    expect(next.earnedAchievementIds, contains('ach_intel_only'));
  });

  test('injected now only changes event timestamp', () {
    final content = _registry([
      {
        'id': 'ach_one_country',
        'name': 'One',
        'conditionType': 'countriesUnlockedAtLeast',
        'conditionParams': {'count': 1},
        'rewardType': 'influenceMultiplier',
        'rewardValue': '0.10',
      },
    ]);
    final state = GameState(
      countries: {
        const CountryId('egypt'): _cs('egypt', unlocked: true),
        const CountryId('nigeria'): _cs('nigeria', unlocked: false),
      },
    );
    final (_, a) = evaluateAchievements(state, content, t0);
    final (_, b) = evaluateAchievements(state, content, t1);
    expect(a.single, isA<AchievementEarned>());
    expect(b.single, isA<AchievementEarned>());
    expect((a.single as AchievementEarned).at, t0);
    expect((b.single as AchievementEarned).at, t1);
  });

  test('IncomeCalculator picks up earned multiplier achievement', () {
    final content = _registry([
      {
        'id': 'ach_slot',
        'name': 'Slot',
        'conditionType': 'countriesUnlockedAtLeast',
        'conditionParams': {'count': 1},
        'rewardType': 'influenceMultiplier',
        'rewardValue': '0.25',
      },
    ]);
    final base = GameState(
      countries: {
        const CountryId('egypt'): _cs('egypt', unlocked: true),
        const CountryId('nigeria'): _cs('nigeria', unlocked: false),
      },
    );
    final (withEarned, _) = evaluateAchievements(base, content, t0);
    final country = withEarned.countries[const CountryId('egypt')]!;
    final withMult = IncomeCalculator.compute(country, withEarned, content);
    final without = IncomeCalculator.compute(country, base, content);
    expect(
      withMult.value,
      equals(without.value * (Decimal.one + Decimal.parse('0.25'))),
    );
  });
}
