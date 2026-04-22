import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

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
      };
      expect(result, equals('upgrade'));
    });
  });

  group('LeaderHired / LeaderUpgraded', () {
    final now = DateTime.utc(2026, 1, 1);

    test('switch routes new events', () {
      final hired = LeaderHired(
        now,
        countryId: const CountryId('egypt'),
        cost: Influence(Decimal.parse('100')),
      );
      final upgraded = LeaderUpgraded(
        now,
        countryId: const CountryId('egypt'),
        cost: Influence(Decimal.parse('200')),
        newTier: LeaderTier.tier2,
      );
      final rh = switch (hired) {
        LeaderHired() => 'h',
        Tick() => 't',
        CountryTapped() => 'c',
        UpgradePurchased() => 'u',
        LeaderUpgraded() => 'g',
      };
      final ru = switch (upgraded) {
        LeaderUpgraded() => 'g',
        Tick() => 't',
        CountryTapped() => 'c',
        UpgradePurchased() => 'u',
        LeaderHired() => 'h',
      };
      expect(rh, equals('h'));
      expect(ru, equals('g'));
    });
  });
}
