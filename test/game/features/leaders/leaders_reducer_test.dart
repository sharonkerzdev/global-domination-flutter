import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/economy/income_calculator.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/features/leaders/leaders_reducer.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

import '../../../helpers/daily_rewards_test_json.dart';

ContentRegistry _content({String baseInfluence = '1'}) {
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
      'baseInfluence': baseInfluence,
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

GameState _egypt({
  required int ipLevel,
  required LeaderTier leader,
  required Influence total,
  bool unlocked = true,
}) {
  return GameState(
    countries: {
      const CountryId('egypt'): CountryState(
        id: const CountryId('egypt'),
        unlocked: unlocked,
        ipLevel: ipLevel,
        leaderTier: leader,
        bankedInfluence: Influence.zero,
        lastCollectedAt: null,
      ),
    },
    totalInfluence: total,
  );
}

void main() {
  final content = _content();
  final egyptDef = content.countries[const CountryId('egypt')]!;
  final now = DateTime.utc(2026, 4, 22);
  const cmdHire = HireLeader(countryId: CountryId('egypt'));
  const cmdUp = UpgradeLeader(countryId: CountryId('egypt'));

  group('applyHireLeader', () {
    test('hires at IP 10, deducts cost, emits LeaderHired', () {
      final cost = IncomeCalculator.leaderHireCost(egyptDef);
      final s = _egypt(
        ipLevel: BalanceConfig.leaderHireMinIpLevel,
        leader: LeaderTier.none,
        total: cost,
      );
      final r = applyHireLeader(s, content, cmdHire, now: now);
      expect(r.isSuccess, isTrue);
      final (next, ev) = r.valueOrNull!;
      expect(
        next.countries[const CountryId('egypt')]!.leaderTier,
        LeaderTier.tier1,
      );
      expect(next.totalInfluence, Influence.zero);
      expect(ev, isA<LeaderHired>());
      final h = ev! as LeaderHired;
      expect(h.cost, equals(cost));
      expect(h.newTier, LeaderTier.tier1);
    });

    test('ip below 10 → ip_below_10', () {
      final s = _egypt(
        ipLevel: 9,
        leader: LeaderTier.none,
        total: Influence(Decimal.parse('99999')),
      );
      final r = applyHireLeader(s, content, cmdHire, now: now);
      expect(r.isFailure, isTrue);
      final e = r.errorOrNull! as Locked;
      expect(e.reason, equals('ip_below_10'));
    });

    test('leader present → leader_already_hired', () {
      final s = _egypt(
        ipLevel: 20,
        leader: LeaderTier.tier1,
        total: Influence(Decimal.parse('99999')),
      );
      final r = applyHireLeader(s, content, cmdHire, now: now);
      expect(r.isFailure, isTrue);
      final e = r.errorOrNull! as Locked;
      expect(e.reason, equals('leader_already_hired'));
    });

    test('insufficient funds → userInsufficientFunds', () {
      final cost = IncomeCalculator.leaderHireCost(egyptDef);
      final s = _egypt(
        ipLevel: BalanceConfig.leaderHireMinIpLevel,
        leader: LeaderTier.none,
        total: cost - Influence(Decimal.one),
      );
      final r = applyHireLeader(s, content, cmdHire, now: now);
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull, isA<InsufficientFunds>());
      final e = r.errorOrNull! as InsufficientFunds;
      expect(e.required, equals(cost));
    });
  });

  group('applyUpgradeLeader', () {
    test('tier1 to tier2', () {
      final c = IncomeCalculator.leaderUpgradeCost(egyptDef, LeaderTier.tier1);
      final s = _egypt(ipLevel: 20, leader: LeaderTier.tier1, total: c);
      final r = applyUpgradeLeader(s, content, cmdUp, now: now);
      expect(r.isSuccess, isTrue);
      final (next, ev) = r.valueOrNull!;
      expect(
        next.countries[const CountryId('egypt')]!.leaderTier,
        LeaderTier.tier2,
      );
      expect(ev, isA<LeaderUpgraded>());
      final u = ev! as LeaderUpgraded;
      expect(u.newTier, LeaderTier.tier2);
      expect(u.cost, equals(c));
    });

    test('tier2 to tier3', () {
      final c = IncomeCalculator.leaderUpgradeCost(egyptDef, LeaderTier.tier2);
      final s = _egypt(ipLevel: 20, leader: LeaderTier.tier2, total: c);
      final r = applyUpgradeLeader(s, content, cmdUp, now: now);
      expect(r.isSuccess, isTrue);
      final (next, ev) = r.valueOrNull!;
      expect(
        next.countries[const CountryId('egypt')]!.leaderTier,
        LeaderTier.tier3,
      );
      final u = ev! as LeaderUpgraded;
      expect(u.newTier, LeaderTier.tier3);
    });

    test('tier3 → leader_max_tier', () {
      final s = _egypt(
        ipLevel: 50,
        leader: LeaderTier.tier3,
        total: Influence(Decimal.parse('99999')),
      );
      final r = applyUpgradeLeader(s, content, cmdUp, now: now);
      expect(r.isFailure, isTrue);
      final e = r.errorOrNull! as Locked;
      expect(e.reason, equals('leader_max_tier'));
    });

    test('no leader → no_leader_hired', () {
      final s = _egypt(
        ipLevel: 20,
        leader: LeaderTier.none,
        total: Influence(Decimal.parse('99999')),
      );
      final r = applyUpgradeLeader(s, content, cmdUp, now: now);
      expect(r.isFailure, isTrue);
      final e = r.errorOrNull! as Locked;
      expect(e.reason, equals('no_leader_hired'));
    });

    test('insufficient funds → userInsufficientFunds', () {
      final cost = IncomeCalculator.leaderUpgradeCost(
        egyptDef,
        LeaderTier.tier1,
      );
      final s = _egypt(
        ipLevel: 20,
        leader: LeaderTier.tier1,
        total: cost - Influence(Decimal.one),
      );
      final r = applyUpgradeLeader(s, content, cmdUp, now: now);
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull, isA<InsufficientFunds>());
      final e = r.errorOrNull! as InsufficientFunds;
      expect(e.required, equals(cost));
    });

    test('negative ipLevel → internal invariant broken', () {
      final s = _egypt(
        ipLevel: -1,
        leader: LeaderTier.tier1,
        total: Influence(Decimal.parse('99999')),
      );
      final r = applyUpgradeLeader(s, content, cmdUp, now: now);
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull, isA<InvariantBroken>());
      final e = r.errorOrNull! as InvariantBroken;
      expect(e.message, contains('negative ipLevel'));
    });
  });
}
