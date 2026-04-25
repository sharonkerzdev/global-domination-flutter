import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/content/country_def.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/economy/income_calculator.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

ContentRegistry _fixtureRegistry() {
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
      'unlockThreshold': '0',
      'completionBonus': '0.50',
      'milestoneRewards': <dynamic>[],
    },
    {
      'id': 'asia',
      'name': 'Asia',
      'unlockThreshold': '0',
      'completionBonus': '0.75',
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
      'id': 'tokyo',
      'continent': 'asia',
      'baseInfluence': '100',
      'unlockCost': '0',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'zeroland',
      'continent': 'africa',
      'baseInfluence': '0',
      'unlockCost': '0',
      'tier': 1,
      'generationSeconds': 1,
    },
  ]);
  final achievements = jsonEncode([
    {
      'id': 'ach_mult_small',
      'name': 'Small',
      'conditionType': 'none',
      'conditionParams': {},
      'rewardType': 'influenceMultiplier',
      'rewardValue': '0.10',
    },
    {
      'id': 'ach_mult_big',
      'name': 'Big',
      'conditionType': 'none',
      'conditionParams': {},
      'rewardType': 'influenceMultiplier',
      'rewardValue': '0.25',
    },
    {
      'id': 'ach_intel',
      'name': 'Intel',
      'conditionType': 'none',
      'conditionParams': {},
      'rewardType': 'intelBoost',
      'rewardValue': '5.0',
    },
  ]);
  final upgrades = jsonEncode([
    {'id': 'upg_small', 'name': 'S', 'influenceAmplifier': '1.5'},
    {'id': 'upg_big', 'name': 'B', 'influenceAmplifier': '2.0'},
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: '[]',
    achievementsJson: achievements,
    missionsJson: '[]',
    globalUpgradesJson: upgrades,
  );
}

String _liveContinentsJson() =>
    File('assets/data/continents.json').readAsStringSync();

CountryState _egypt({
  bool unlocked = true,
  int ipLevel = 0,
  LeaderTier leaderTier = LeaderTier.none,
}) {
  return CountryState(
    id: const CountryId('egypt'),
    unlocked: unlocked,
    ipLevel: ipLevel,
    leaderTier: leaderTier,
    bankedInfluence: Influence.zero,
  );
}

GameState _state({
  CountryState? egypt,
  Map<ContinentId, bool>? continentCompletions,
  Set<String>? earnedAchievementIds,
  Set<String>? activeGlobalUpgradeIds,
  Decimal? goldenOpportunityMultiplier,
  Decimal? boostMultiplier,
}) {
  return GameState(
    countries: {const CountryId('egypt'): egypt ?? _egypt()},
    continentCompletions: continentCompletions,
    earnedAchievementIds: earnedAchievementIds,
    activeGlobalUpgradeIds: activeGlobalUpgradeIds,
    goldenOpportunityMultiplier: goldenOpportunityMultiplier,
    boostMultiplier: boostMultiplier,
  );
}

void main() {
  late ContentRegistry content;

  setUp(() {
    content = _fixtureRegistry();
  });

  test('5.3 baseline egypt — all defaults → rate == baseInfluence', () {
    final r = IncomeCalculator.compute(_egypt(), _state(), content);
    expect(r, equals(Influence(Decimal.one)));
  });

  test('5-1 AC5: goldenOpportunityMultiplier 50 multiplies the stack', () {
    final noGolden = IncomeCalculator.compute(
      _egypt(ipLevel: 0),
      _state(),
      content,
    ).value;
    final withGolden = IncomeCalculator.compute(
      _egypt(ipLevel: 0),
      _state(goldenOpportunityMultiplier: Decimal.fromInt(50)),
      content,
    ).value;
    expect(withGolden, equals(noGolden * Decimal.fromInt(50)));
  });

  test('5.4 IP isolation', () {
    expect(
      IncomeCalculator.compute(_egypt(ipLevel: 0), _state(), content).value,
      equals(Decimal.one),
    );
    expect(
      IncomeCalculator.compute(_egypt(ipLevel: 10), _state(), content).value,
      equals(Decimal.parse('2')),
    );
    expect(
      IncomeCalculator.compute(_egypt(ipLevel: 200), _state(), content).value,
      equals(Decimal.parse('21')),
    );
  });

  test('5.5 leader isolation', () {
    expect(
      IncomeCalculator.compute(
        _egypt(leaderTier: LeaderTier.none),
        _state(),
        content,
      ).value,
      equals(Decimal.one),
    );
    expect(
      IncomeCalculator.compute(
        _egypt(leaderTier: LeaderTier.tier1),
        _state(),
        content,
      ).value,
      equals(Decimal.parse('1.5')),
    );
    expect(
      IncomeCalculator.compute(
        _egypt(leaderTier: LeaderTier.tier2),
        _state(),
        content,
      ).value,
      equals(Decimal.parse('2')),
    );
    expect(
      IncomeCalculator.compute(
        _egypt(leaderTier: LeaderTier.tier3),
        _state(),
        content,
      ).value,
      equals(Decimal.parse('3')),
    );
  });

  test('5.6 continent completion isolation', () {
    final s = _state(continentCompletions: {const ContinentId('africa'): true});
    expect(
      IncomeCalculator.compute(_egypt(), s, content).value,
      equals(Decimal.parse('1.25')),
    );
  });

  test('5.6b continent completion is global, not country-own-continent', () {
    final s = _state(continentCompletions: {const ContinentId('europe'): true});
    expect(
      IncomeCalculator.compute(_egypt(), s, content).value,
      equals(Decimal.parse('1.5')),
    );
  });

  test('5.6c continent completion product across two continents', () {
    final s = _state(
      continentCompletions: {
        const ContinentId('africa'): true,
        const ContinentId('europe'): true,
      },
    );
    expect(
      IncomeCalculator.compute(_egypt(), s, content).value,
      equals(Decimal.parse('1.875')),
    );
  });

  test('5.6d continent completion product across all seven', () {
    final seven = ContentRegistry.fromJsonStrings(
      countriesJson: jsonEncode([
        {
          'id': 'egypt',
          'continent': 'africa',
          'baseInfluence': '1',
          'unlockCost': '0',
          'tier': 1,
          'generationSeconds': 1,
        },
      ]),
      continentsJson: _liveContinentsJson(),
      leadersJson: '[]',
      achievementsJson: '[]',
      missionsJson: '[]',
      globalUpgradesJson: '[]',
    );
    final expected = seven.continents.values.fold<Decimal>(
      Decimal.one,
      (acc, c) => acc * (Decimal.one + c.completionBonus),
    );
    final s = _state(
      continentCompletions: {for (final id in seven.continents.keys) id: true},
    );
    expect(
      IncomeCalculator.compute(_egypt(), s, seven).value,
      equals(expected),
    );
  });

  test('5.6e continent completion ignores ids missing from content', () {
    final s = _state(
      continentCompletions: {
        const ContinentId('africa'): true,
        const ContinentId('atlantis'): true,
      },
    );
    expect(
      IncomeCalculator.compute(_egypt(), s, content).value,
      equals(Decimal.parse('1.25')),
    );
  });

  test('5.7 achievement isolation', () {
    expect(
      IncomeCalculator.compute(
        _egypt(),
        _state(earnedAchievementIds: {'ach_mult_small'}),
        content,
      ).value,
      equals(Decimal.parse('1.1')),
    );
    expect(
      IncomeCalculator.compute(
        _egypt(),
        _state(earnedAchievementIds: {'ach_mult_small', 'ach_mult_big'}),
        content,
      ).value,
      equals(Decimal.parse('1.35')),
    );
    expect(
      IncomeCalculator.compute(
        _egypt(),
        _state(earnedAchievementIds: {'ach_intel'}),
        content,
      ).value,
      equals(Decimal.one),
    );
  });

  test('5.8 global upgrade isolation', () {
    expect(
      IncomeCalculator.compute(
        _egypt(),
        _state(activeGlobalUpgradeIds: {'upg_small'}),
        content,
      ).value,
      equals(Decimal.parse('1.5')),
    );
    expect(
      IncomeCalculator.compute(
        _egypt(),
        _state(activeGlobalUpgradeIds: {'upg_small', 'upg_big'}),
        content,
      ).value,
      equals(Decimal.parse('3')),
    );
  });

  test('5.9 golden isolation', () {
    expect(
      IncomeCalculator.compute(
        _egypt(),
        _state(goldenOpportunityMultiplier: Decimal.parse('10')),
        content,
      ).value,
      equals(Decimal.parse('10')),
    );
  });

  test('5.10 boost isolation', () {
    expect(
      IncomeCalculator.compute(
        _egypt(),
        _state(boostMultiplier: Decimal.parse('2')),
        content,
      ).value,
      equals(Decimal.parse('2')),
    );
  });

  test('5.11 composed stack order regression', () {
    final s = _state(
      egypt: _egypt(ipLevel: 100, leaderTier: LeaderTier.tier2),
      continentCompletions: {const ContinentId('africa'): true},
      earnedAchievementIds: {'ach_mult_small', 'ach_mult_big'},
      activeGlobalUpgradeIds: {'upg_small', 'upg_big'},
      goldenOpportunityMultiplier: Decimal.parse('10'),
      boostMultiplier: Decimal.parse('2'),
    );
    // 1 × (1 + 10) × 2 × 1.25 × 1.35 × 3 × 10 × 2 = 2227.5
    final country = s.countries[const CountryId('egypt')]!;
    expect(
      IncomeCalculator.compute(country, s, content).value,
      equals(Decimal.parse('2227.5')),
    );
  });

  test('5.12 locked country → zero', () {
    expect(
      IncomeCalculator.compute(_egypt(unlocked: false), _state(), content),
      equals(Influence.zero),
    );
  });

  test('5.13 missing CountryDef → zero', () {
    final c = CountryState(
      id: const CountryId('atlantis'),
      unlocked: true,
      ipLevel: 0,
      leaderTier: LeaderTier.none,
      bankedInfluence: Influence.zero,
    );
    expect(
      IncomeCalculator.compute(
        c,
        GameState(countries: {const CountryId('atlantis'): c}),
        content,
      ),
      equals(Influence.zero),
    );
  });

  test('5.14 zero baseInfluence → zero', () {
    final z = CountryState(
      id: const CountryId('zeroland'),
      unlocked: true,
      ipLevel: 99,
      leaderTier: LeaderTier.tier3,
      bankedInfluence: Influence.zero,
    );
    final s = GameState(
      countries: {const CountryId('zeroland'): z},
      earnedAchievementIds: {'ach_mult_small'},
      activeGlobalUpgradeIds: {'upg_small'},
      goldenOpportunityMultiplier: Decimal.parse('99'),
      boostMultiplier: Decimal.parse('99'),
    );
    expect(IncomeCalculator.compute(z, s, content), equals(Influence.zero));
  });

  test('5.15 precision stress — finite exact Decimal', () {
    final achIds = <String>{for (var i = 0; i < 20; i++) 'ach10_$i'};
    final achievements = jsonEncode([
      for (var i = 0; i < 20; i++)
        {
          'id': 'ach10_$i',
          'name': 'a',
          'conditionType': 'none',
          'conditionParams': {},
          'rewardType': 'influenceMultiplier',
          'rewardValue': '0.10',
        },
    ]);
    final upgrades = jsonEncode([
      for (var i = 0; i < 10; i++)
        {'id': 'up10_$i', 'name': 'u', 'influenceAmplifier': '10'},
    ]);
    final c = ContentRegistry.fromJsonStrings(
      countriesJson: jsonEncode([
        {
          'id': 'egypt',
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
          'milestoneRewards': <dynamic>[],
        },
      ]),
      leadersJson: '[]',
      achievementsJson: achievements,
      missionsJson: '[]',
      globalUpgradesJson: upgrades,
    );
    final upgradeIds = <String>{for (var i = 0; i < 10; i++) 'up10_$i'};
    final s = _state(
      egypt: _egypt(ipLevel: 200, leaderTier: LeaderTier.tier3),
      continentCompletions: {const ContinentId('africa'): true},
      earnedAchievementIds: achIds,
      activeGlobalUpgradeIds: upgradeIds,
      goldenOpportunityMultiplier: Decimal.parse('100'),
      boostMultiplier: Decimal.parse('2'),
    );
    final country = s.countries[const CountryId('egypt')]!;
    final out = IncomeCalculator.compute(country, s, c);
    // Expected built in-order (mirrors implementation):
    var expected = Decimal.one;
    expected *= Decimal.one + Decimal.fromInt(200) * Decimal.parse('0.1');
    expected *= Decimal.parse('3');
    expected *= Decimal.one + Decimal.parse('0.25');
    expected *= Decimal.one + (Decimal.parse('0.10') * Decimal.fromInt(20));
    for (var i = 0; i < 10; i++) {
      expected *= Decimal.parse('10');
    }
    expected *= Decimal.parse('100');
    expected *= Decimal.parse('2');
    expect(out.value, equals(expected));
  });

  group('upgradeCost', () {
    late CountryDef egyptDef;

    setUp(() {
      egyptDef = content.countries[const CountryId('egypt')]!;
    });

    test('single level at L: B × 1.5^L (AC4)', () {
      const l = 7;
      final b =
          egyptDef.baseInfluence * BalanceConfig.ipUpgradeBaseInfluenceScale;
      final r = BalanceConfig.ipUpgradeCostMultiplier;
      var expected = b;
      for (var i = 0; i < l; i++) {
        expected *= r;
      }
      expect(
        IncomeCalculator.upgradeCost(egyptDef, l, 1).value,
        equals(expected),
      );
    });

    test('bulk 10 and 25 match successive single-level costs (AC8)', () {
      for (final bulk in [10, 25]) {
        for (final l in [0, 3, 12, 50]) {
          if (l + bulk > 200) continue;
          var sum = Influence.zero;
          for (var i = 0; i < bulk; i++) {
            sum = sum + IncomeCalculator.upgradeCost(egyptDef, l + i, 1);
          }
          expect(IncomeCalculator.upgradeCost(egyptDef, l, bulk), equals(sum));
        }
      }
    });
  });

  group('leader costs (Story 3.3)', () {
    test('BalanceConfig leaderMultipliers are 1.0, 1.5, 2.0, 3.0', () {
      expect(BalanceConfig.leaderMultipliers[LeaderTier.none], '1.0');
      expect(BalanceConfig.leaderMultipliers[LeaderTier.tier1], '1.5');
      expect(BalanceConfig.leaderMultipliers[LeaderTier.tier2], '2.0');
      expect(BalanceConfig.leaderMultipliers[LeaderTier.tier3], '3.0');
    });

    test('leaderHireCost and leaderUpgradeCost', () {
      final content = _fixtureRegistry();
      final egypt = content.countries[const CountryId('egypt')]!;
      expect(
        IncomeCalculator.leaderHireCost(egypt).value,
        equals(
          egypt.baseInfluence * BalanceConfig.leaderHireBaseInfluenceScale,
        ),
      );
      expect(
        IncomeCalculator.leaderUpgradeCost(egypt, LeaderTier.tier1).value,
        equals(
          egypt.baseInfluence *
              BalanceConfig.leaderUpgradeT1T2BaseInfluenceScale,
        ),
      );
      expect(
        IncomeCalculator.leaderUpgradeCost(egypt, LeaderTier.tier2).value,
        equals(
          egypt.baseInfluence *
              BalanceConfig.leaderUpgradeT2T3BaseInfluenceScale,
        ),
      );
    });
  });
}
