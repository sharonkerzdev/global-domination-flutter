import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/economy/income_calculator.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/features/upgrades/upgrades_reducer.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

import '../../../helpers/achievements_fixture.dart';
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
    achievementsJson: trivial27AchievementsJson(),
    missionsJson: '[]',
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

GameState _egyptState({
  required int ipLevel,
  required Influence total,
  bool unlocked = true,
}) {
  return GameState(
    countries: {
      const CountryId('egypt'): CountryState(
        id: const CountryId('egypt'),
        unlocked: unlocked,
        ipLevel: ipLevel,
        leaderTier: LeaderTier.none,
        bankedInfluence: Influence.zero,
        lastCollectedAt: null,
      ),
    },
    totalInfluence: total,
  );
}

void main() {
  final content = _content();
  final def = content.countries[const CountryId('egypt')]!;
  final now = DateTime.utc(2026, 4, 22);

  group('applyPurchaseUpgrade', () {
    test('1x: deducts cost, increments ipLevel, emits UpgradePurchased', () {
      final startLevel = 1;
      final cost = IncomeCalculator.upgradeCost(def, startLevel, 1);
      final state = _egyptState(ipLevel: startLevel, total: cost);
      final cmd = const PurchaseUpgrade(countryId: CountryId('egypt'), bulk: 1);
      final r = applyPurchaseUpgrade(state, content, cmd, now: now);
      expect(r.isSuccess, isTrue);
      final (next, ev) = r.valueOrNull!;
      expect(next.countries[const CountryId('egypt')]!.ipLevel, equals(2));
      expect(next.totalInfluence, equals(Influence.zero));
      expect(ev, isA<UpgradePurchased>());
      final u = ev! as UpgradePurchased;
      expect(u.levelsAdded, equals(1));
      expect(u.bulkRequested, equals(1));
      expect(u.totalCost, equals(cost));
    });

    test('insufficient funds: no state change', () {
      final state = _egyptState(
        ipLevel: 1,
        total: IncomeCalculator.upgradeCost(def, 1, 1) - Influence(Decimal.one),
      );
      final r = applyPurchaseUpgrade(
        state,
        content,
        const PurchaseUpgrade(countryId: CountryId('egypt'), bulk: 1),
        now: now,
      );
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull, isA<InsufficientFunds>());
      final err = r.errorOrNull! as InsufficientFunds;
      expect(err.required, equals(IncomeCalculator.upgradeCost(def, 1, 1)));
    });

    test('max level: userLocked max_level', () {
      final state = _egyptState(
        ipLevel: BalanceConfig.maxIpLevel,
        total: Influence(Decimal.parse('1000000000000000000000000000000')),
      );
      final r = applyPurchaseUpgrade(
        state,
        content,
        const PurchaseUpgrade(countryId: CountryId('egypt'), bulk: 1),
        now: now,
      );
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull, isA<Locked>());
      expect((r.errorOrNull! as Locked).reason, equals('max_level'));
    });

    test('10x: one event, ip +10, full cost', () {
      const start = 5;
      final fullCost = IncomeCalculator.upgradeCost(def, start, 10);
      final state = _egyptState(ipLevel: start, total: fullCost);
      final r = applyPurchaseUpgrade(
        state,
        content,
        const PurchaseUpgrade(countryId: CountryId('egypt'), bulk: 10),
        now: now,
      );
      expect(r.isSuccess, isTrue);
      final (next, ev) = r.valueOrNull!;
      expect(next.countries[const CountryId('egypt')]!.ipLevel, equals(15));
      final u = ev! as UpgradePurchased;
      expect(u.levelsAdded, equals(10));
      expect(u.bulkRequested, equals(10));
      expect(u.totalCost, equals(fullCost));
    });

    test('partial cap at 200: levelsAdded and cost match actual buy', () {
      final start = 198;
      final buy = 2;
      final cost = IncomeCalculator.upgradeCost(def, start, buy);
      final state = _egyptState(ipLevel: start, total: cost);
      final r = applyPurchaseUpgrade(
        state,
        content,
        const PurchaseUpgrade(countryId: CountryId('egypt'), bulk: 10),
        now: now,
      );
      expect(r.isSuccess, isTrue);
      final (next, ev) = r.valueOrNull!;
      expect(next.countries[const CountryId('egypt')]!.ipLevel, equals(200));
      final u = ev! as UpgradePurchased;
      expect(u.levelsAdded, equals(2));
      expect(u.bulkRequested, equals(10));
      expect(u.totalCost, equals(cost));
    });

    test('cannot afford full (capped) stack: no partial buy', () {
      final start = 198;
      final fullCost = IncomeCalculator.upgradeCost(def, start, 2);
      final state = _egyptState(
        ipLevel: start,
        total: fullCost - Influence(Decimal.one),
      );
      final r = applyPurchaseUpgrade(
        state,
        content,
        const PurchaseUpgrade(countryId: CountryId('egypt'), bulk: 10),
        now: now,
      );
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull, isA<InsufficientFunds>());
      expect((r.errorOrNull! as InsufficientFunds).required, equals(fullCost));
    });

    test('locked country: userLocked', () {
      final cost = IncomeCalculator.upgradeCost(def, 1, 1);
      final state = _egyptState(ipLevel: 1, total: cost, unlocked: false);
      final r = applyPurchaseUpgrade(
        state,
        content,
        const PurchaseUpgrade(countryId: CountryId('egypt'), bulk: 1),
        now: now,
      );
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull, isA<Locked>());
    });

    test('bulk < 1 is blocked by PurchaseUpgrade assert in test mode', () {
      expect(
        () => PurchaseUpgrade(countryId: const CountryId('egypt'), bulk: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('missing country in state: internalMissingCountry', () {
      final empty = GameState();
      final r = applyPurchaseUpgrade(
        empty,
        content,
        const PurchaseUpgrade(countryId: CountryId('egypt'), bulk: 1),
        now: now,
      );
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull, isA<MissingCountry>());
    });

    test('negative ipLevel: internalInvariantBroken', () {
      final state = _egyptState(
        ipLevel: -1,
        total: Influence(Decimal.parse('1000')),
      );
      final r = applyPurchaseUpgrade(
        state,
        content,
        const PurchaseUpgrade(countryId: CountryId('egypt'), bulk: 1),
        now: now,
      );
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull, isA<InvariantBroken>());
    });

    test('missing country in content: internalMissingCountry', () {
      final emptyContent = ContentRegistry.fromJsonStrings(
        countriesJson: jsonEncode([
          {
            'id': 'nigeria',
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
        achievementsJson: trivial27AchievementsJson(),
        missionsJson: '[]',
        globalUpgradesJson: '[]',
        dailyRewardsJson: testDailyRewardsJson(),
      );
      final state = _egyptState(
        ipLevel: 1,
        total: Influence(Decimal.parse('1000')),
      );
      final r = applyPurchaseUpgrade(
        state,
        emptyContent,
        const PurchaseUpgrade(countryId: CountryId('egypt'), bulk: 1),
        now: now,
      );
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull, isA<MissingCountry>());
    });

    test('non-positive baseInfluence: internalInvariantBroken', () {
      final badContent = _content(baseInfluence: '0');
      final badDef = badContent.countries[const CountryId('egypt')]!;
      final state = _egyptState(
        ipLevel: 1,
        total: IncomeCalculator.upgradeCost(def, 1, 1),
      );
      expect(
        IncomeCalculator.upgradeCost(badDef, 1, 1),
        equals(Influence.zero),
      );
      final r = applyPurchaseUpgrade(
        state,
        badContent,
        const PurchaseUpgrade(countryId: CountryId('egypt'), bulk: 1),
        now: now,
      );
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull, isA<InvariantBroken>());
    });
  });
}
