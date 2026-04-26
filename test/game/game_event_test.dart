import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';

void main() {
  group('Tick', () {
    final now = DateTime.utc(2026, 1, 1);

    test('can be constructed with a DateTime', () {
      final event = Tick(now);
      expect(event, isA<GameEvent>());
      expect(event, isA<Tick>());
      expect(event.at, equals(now));
    });

    test('equality: two Ticks with the same DateTime are equal', () {
      final a = Tick(now);
      final b = Tick(now);
      expect(a, equals(b));
    });

    test('inequality: two Ticks with different DateTimes are not equal', () {
      final a = Tick(now);
      final b = Tick(now.add(const Duration(seconds: 1)));
      expect(a, isNot(equals(b)));
    });

    test('hashCode: equal Ticks have the same hashCode', () {
      final a = Tick(now);
      final b = Tick(now);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString returns expected representation', () {
      final event = Tick(now);
      expect(event.toString(), equals('Tick(at: $now)'));
    });

    test('exhaustive switch compiles on sealed hierarchy', () {
      final GameEvent event = Tick(now);
      final result = switch (event) {
        Tick() => 'tick',
        CountryTapped() => 'country_tapped',
        UpgradePurchased() => 'upgrade',
        LeaderHired() => 'leader_hired',
        LeaderUpgraded() => 'leader_upgraded',
        ContinentUnlocked() => 'continent_unlocked',
        CountryUnlocked() => 'country_unlocked',
        MilestoneReached() => 'milestone_reached',
        ContinentCompleted() => 'continent_completed',
        GoldenSpawned() => 'golden_spawned',
        GoldenClaimed() => 'golden_claimed',
        GoldenExpired() => 'golden_expired',
        BoostActivated() => 'boost_activated',
        BoostExpired() => 'boost_expired',
      };
      expect(result, equals('tick'));
    });
  });

  group('UpgradePurchased', () {
    final now = DateTime.utc(2026, 1, 1);

    test('exhaustive switch routes UpgradePurchased', () {
      final GameEvent event = UpgradePurchased(
        now,
        countryId: const CountryId('egypt'),
        levelsAdded: 5,
        bulkRequested: 10,
        totalCost: Influence(Decimal.parse('100')),
      );
      final result = switch (event) {
        Tick() => 'tick',
        CountryTapped() => 'country_tapped',
        UpgradePurchased() => 'upgrade',
        LeaderHired() => 'leader_hired',
        LeaderUpgraded() => 'leader_upgraded',
        ContinentUnlocked() => 'continent_unlocked',
        CountryUnlocked() => 'country_unlocked',
        MilestoneReached() => 'milestone_reached',
        ContinentCompleted() => 'continent_completed',
        GoldenSpawned() => 'golden_spawned',
        GoldenClaimed() => 'golden_claimed',
        GoldenExpired() => 'golden_expired',
        BoostActivated() => 'boost_activated',
        BoostExpired() => 'boost_expired',
      };
      expect(result, equals('upgrade'));
    });
  });

  group('LeaderHired / LeaderUpgraded', () {
    final now = DateTime.utc(2026, 1, 1);

    test('switch routes new events', () {
      final GameEvent hired = LeaderHired(
        now,
        countryId: const CountryId('egypt'),
        cost: Influence(Decimal.parse('100')),
      );
      final GameEvent upgraded = LeaderUpgraded(
        now,
        countryId: const CountryId('egypt'),
        cost: Influence(Decimal.parse('200')),
        newTier: LeaderTier.tier2,
      );
      final rh = switch (hired) {
        Tick() => 'tick',
        CountryTapped() => 'country_tapped',
        UpgradePurchased() => 'upgrade',
        LeaderHired() => 'h',
        LeaderUpgraded() => 'leader_upgraded',
        ContinentUnlocked() => 'continent_unlocked',
        CountryUnlocked() => 'country_unlocked',
        MilestoneReached() => 'milestone_reached',
        ContinentCompleted() => 'continent_completed',
        GoldenSpawned() => 'golden_spawned',
        GoldenClaimed() => 'golden_claimed',
        GoldenExpired() => 'golden_expired',
        BoostActivated() => 'boost_activated',
        BoostExpired() => 'boost_expired',
      };
      final ru = switch (upgraded) {
        Tick() => 'tick',
        CountryTapped() => 'country_tapped',
        UpgradePurchased() => 'upgrade',
        LeaderHired() => 'leader_hired',
        LeaderUpgraded() => 'g',
        ContinentUnlocked() => 'continent_unlocked',
        CountryUnlocked() => 'country_unlocked',
        MilestoneReached() => 'milestone_reached',
        ContinentCompleted() => 'continent_completed',
        GoldenSpawned() => 'golden_spawned',
        GoldenClaimed() => 'golden_claimed',
        GoldenExpired() => 'golden_expired',
        BoostActivated() => 'boost_activated',
        BoostExpired() => 'boost_expired',
      };
      expect(rh, equals('h'));
      expect(ru, equals('g'));
    });
  });

  group('CountryUnlocked', () {
    final now = DateTime.utc(2026, 1, 1);

    test('equality, fields, toString', () {
      const id = CountryId('nigeria');
      final a = CountryUnlocked(
        now,
        countryId: id,
        continent: const ContinentId('africa'),
        cost: Influence(Decimal.parse('5')),
      );
      final b = CountryUnlocked(
        now,
        countryId: id,
        continent: const ContinentId('africa'),
        cost: Influence(Decimal.parse('5')),
      );
      expect(a, equals(b));
      expect(a.toString(), contains('CountryUnlocked'));
    });

    test('exhaustive switch routes CountryUnlocked', () {
      const id = CountryId('nigeria');
      final GameEvent event = CountryUnlocked(
        now,
        countryId: id,
        continent: const ContinentId('africa'),
        cost: Influence(Decimal.parse('5')),
      );
      final result = switch (event) {
        Tick() => 'tick',
        CountryTapped() => 'country_tapped',
        UpgradePurchased() => 'upgrade',
        LeaderHired() => 'leader_hired',
        LeaderUpgraded() => 'leader_upgraded',
        ContinentUnlocked() => 'continent_unlocked',
        CountryUnlocked() => 'country_unlocked',
        MilestoneReached() => 'milestone_reached',
        ContinentCompleted() => 'continent_completed',
        GoldenSpawned() => 'golden_spawned',
        GoldenClaimed() => 'golden_claimed',
        GoldenExpired() => 'golden_expired',
        BoostActivated() => 'boost_activated',
        BoostExpired() => 'boost_expired',
      };
      expect(result, equals('country_unlocked'));
    });
  });

  group('ContinentUnlocked', () {
    final now = DateTime.utc(2026, 1, 1);

    test('equality, fields, toString', () {
      const id = ContinentId('europe');
      final a = ContinentUnlocked(now, continentId: id);
      final b = ContinentUnlocked(now, continentId: id);
      expect(a, equals(b));
      expect(a.toString(), contains('ContinentUnlocked'));
    });

    test('exhaustive switch routes ContinentUnlocked', () {
      final GameEvent event = ContinentUnlocked(
        DateTime.utc(2026, 1, 1),
        continentId: const ContinentId('africa'),
      );
      final result = switch (event) {
        Tick() => 'tick',
        CountryTapped() => 'country_tapped',
        UpgradePurchased() => 'upgrade',
        LeaderHired() => 'leader_hired',
        LeaderUpgraded() => 'leader_upgraded',
        ContinentUnlocked() => 'continent_unlocked',
        CountryUnlocked() => 'country_unlocked',
        MilestoneReached() => 'milestone_reached',
        ContinentCompleted() => 'continent_completed',
        GoldenSpawned() => 'golden_spawned',
        GoldenClaimed() => 'golden_claimed',
        GoldenExpired() => 'golden_expired',
        BoostActivated() => 'boost_activated',
        BoostExpired() => 'boost_expired',
      };
      expect(result, equals('continent_unlocked'));
    });
  });

  group('MilestoneReached', () {
    final now = DateTime.utc(2026, 4, 24);

    test('equality, hashCode, toString', () {
      const cid = ContinentId('africa');
      final a = MilestoneReached(
        now,
        continentId: cid,
        percent: 25,
        rewardType: 'influence',
        rewardValue: Decimal.parse('10'),
      );
      final b = MilestoneReached(
        now,
        continentId: cid,
        percent: 25,
        rewardType: 'influence',
        rewardValue: Decimal.parse('10'),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a.toString(), contains('MilestoneReached'));
      expect(a.toString(), contains('percent: 25'));
    });

    test('exhaustive switch routes MilestoneReached', () {
      const cid = ContinentId('africa');
      final GameEvent event = MilestoneReached(
        now,
        continentId: cid,
        percent: 50,
        rewardType: 'influence',
        rewardValue: Decimal.one,
      );
      final result = switch (event) {
        Tick() => 'tick',
        CountryTapped() => 'country_tapped',
        UpgradePurchased() => 'upgrade',
        LeaderHired() => 'leader_hired',
        LeaderUpgraded() => 'leader_upgraded',
        ContinentUnlocked() => 'continent_unlocked',
        CountryUnlocked() => 'country_unlocked',
        MilestoneReached() => 'milestone_reached',
        ContinentCompleted() => 'continent_completed',
        GoldenSpawned() => 'golden_spawned',
        GoldenClaimed() => 'golden_claimed',
        GoldenExpired() => 'golden_expired',
        BoostActivated() => 'boost_activated',
        BoostExpired() => 'boost_expired',
      };
      expect(result, equals('milestone_reached'));
    });
  });

  group('ContinentCompleted', () {
    final now = DateTime.utc(2026, 4, 24);

    test('equality, toString', () {
      const cid = ContinentId('africa');
      final a = ContinentCompleted(now, continentId: cid);
      final b = ContinentCompleted(now, continentId: cid);
      expect(a, equals(b));
      expect(a.toString(), contains('ContinentCompleted'));
    });

    test('exhaustive switch routes ContinentCompleted', () {
      final GameEvent event = ContinentCompleted(
        now,
        continentId: const ContinentId('europe'),
      );
      final result = switch (event) {
        Tick() => 'tick',
        CountryTapped() => 'country_tapped',
        UpgradePurchased() => 'upgrade',
        LeaderHired() => 'leader_hired',
        LeaderUpgraded() => 'leader_upgraded',
        ContinentUnlocked() => 'continent_unlocked',
        CountryUnlocked() => 'country_unlocked',
        MilestoneReached() => 'milestone_reached',
        ContinentCompleted() => 'continent_completed',
        GoldenSpawned() => 'golden_spawned',
        GoldenClaimed() => 'golden_claimed',
        GoldenExpired() => 'golden_expired',
        BoostActivated() => 'boost_activated',
        BoostExpired() => 'boost_expired',
      };
      expect(result, equals('continent_completed'));
    });
  });

  group('BoostActivated / BoostExpired', () {
    final at = DateTime.utc(2026, 1, 1);
    final exp = DateTime.utc(2026, 1, 1, 0, 0, 30);
    final spent = Intel(Decimal.parse('100'));

    test('BoostActivated equality, hashCode, toString', () {
      final a = BoostActivated(
        at,
        multiplier: Decimal.parse('2.0'),
        expiresAt: exp,
        intelSpent: spent,
      );
      final b = BoostActivated(
        at,
        multiplier: Decimal.parse('2.0'),
        expiresAt: exp,
        intelSpent: spent,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a.toString(), contains('BoostActivated'));
      expect(a.toString(), contains('multiplier'));
      expect(a.toString(), contains('intelSpent'));
    });

    test('BoostExpired matches Tick pattern', () {
      final a = BoostExpired(at);
      final b = BoostExpired(at);
      expect(a, equals(b));
      expect(a.toString(), equals('BoostExpired(at: $at)'));
    });
  });
}
