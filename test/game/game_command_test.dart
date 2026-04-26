import 'package:test/test.dart';

import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/values/country_id.dart';

void main() {
  group('Noop', () {
    test('can be constructed with const', () {
      const cmd = Noop();
      expect(cmd, isA<GameCommand>());
      expect(cmd, isA<Noop>());
    });

    test('equality: two Noop instances are equal', () {
      const a = Noop();
      const b = Noop();
      expect(a, equals(b));
    });

    test('hashCode: two Noop instances have the same hashCode', () {
      const a = Noop();
      const b = Noop();
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString returns expected representation', () {
      expect(const Noop().toString(), equals('Noop()'));
    });

    test('exhaustive switch compiles on sealed hierarchy', () {
      const GameCommand cmd = Noop();
      final result = switch (cmd) {
        Noop() => 'noop',
        TapCountry() => 'tap_country',
        PurchaseUpgrade() => 'purchase',
        HireLeader() => 'hire',
        UpgradeLeader() => 'upgrade_leader',
        UnlockCountry() => 'unlock_country',
        ClaimGolden() => 'claim_golden',
        ActivateBoost() => 'activate_boost',
      };
      expect(result, equals('noop'));
    });
  });

  group('TapCountry', () {
    test('can be constructed with const', () {
      const cmd = TapCountry(countryId: CountryId('egypt'));
      expect(cmd, isA<GameCommand>());
      expect(cmd, isA<TapCountry>());
      expect(cmd.countryId, const CountryId('egypt'));
    });

    test('equality: same countryId → equal', () {
      const a = TapCountry(countryId: CountryId('egypt'));
      const b = TapCountry(countryId: CountryId('egypt'));
      expect(a, equals(b));
    });

    test('equality: different countryId → not equal', () {
      const a = TapCountry(countryId: CountryId('egypt'));
      const b = TapCountry(countryId: CountryId('kenya'));
      expect(a, isNot(equals(b)));
    });

    test('hashCode: equal instances share hashCode', () {
      const a = TapCountry(countryId: CountryId('egypt'));
      const b = TapCountry(countryId: CountryId('egypt'));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes country id', () {
      expect(
        const TapCountry(countryId: CountryId('egypt')).toString(),
        equals('TapCountry(egypt)'),
      );
    });

    test('exhaustive switch routes TapCountry', () {
      const GameCommand cmd = TapCountry(countryId: CountryId('egypt'));
      final result = switch (cmd) {
        Noop() => 'noop',
        TapCountry() => 'tap_country',
        PurchaseUpgrade() => 'purchase',
        HireLeader() => 'hire',
        UpgradeLeader() => 'upgrade_leader',
        UnlockCountry() => 'unlock_country',
        ClaimGolden() => 'claim_golden',
        ActivateBoost() => 'activate_boost',
      };
      expect(result, equals('tap_country'));
    });
  });

  group('PurchaseUpgrade', () {
    test('default bulk is 1', () {
      const cmd = PurchaseUpgrade(countryId: CountryId('egypt'));
      expect(cmd.bulk, equals(1));
    });

    test('exhaustive switch routes PurchaseUpgrade', () {
      const GameCommand cmd = PurchaseUpgrade(
        countryId: CountryId('egypt'),
        bulk: 10,
      );
      final result = switch (cmd) {
        Noop() => 'noop',
        TapCountry() => 'tap_country',
        PurchaseUpgrade() => 'purchase',
        HireLeader() => 'hire',
        UpgradeLeader() => 'upgrade_leader',
        UnlockCountry() => 'unlock_country',
        ClaimGolden() => 'claim_golden',
        ActivateBoost() => 'activate_boost',
      };
      expect(result, equals('purchase'));
    });
  });

  group('HireLeader', () {
    test('equality and toString', () {
      const a = HireLeader(countryId: CountryId('egypt'));
      const b = HireLeader(countryId: CountryId('egypt'));
      expect(a, equals(b));
      expect(a.toString(), equals('HireLeader(egypt)'));
    });
  });

  group('UpgradeLeader', () {
    test('switch routes UpgradeLeader', () {
      const GameCommand cmd = UpgradeLeader(countryId: CountryId('egypt'));
      final result = switch (cmd) {
        Noop() => 'noop',
        TapCountry() => 'tap_country',
        PurchaseUpgrade() => 'purchase',
        HireLeader() => 'hire',
        UpgradeLeader() => 'upgrade_leader',
        UnlockCountry() => 'unlock_country',
        ClaimGolden() => 'claim_golden',
        ActivateBoost() => 'activate_boost',
      };
      expect(result, equals('upgrade_leader'));
    });
  });

  group('UnlockCountry', () {
    test('equality and toString', () {
      const a = UnlockCountry(countryId: CountryId('nigeria'));
      const b = UnlockCountry(countryId: CountryId('nigeria'));
      expect(a, equals(b));
      expect(a.toString(), equals('UnlockCountry(nigeria)'));
    });

    test('switch routes UnlockCountry', () {
      const GameCommand cmd = UnlockCountry(countryId: CountryId('nigeria'));
      final result = switch (cmd) {
        Noop() => 'noop',
        TapCountry() => 'tap_country',
        PurchaseUpgrade() => 'purchase',
        HireLeader() => 'hire',
        UpgradeLeader() => 'upgrade_leader',
        UnlockCountry() => 'unlock_country',
        ClaimGolden() => 'claim_golden',
        ActivateBoost() => 'activate_boost',
      };
      expect(result, equals('unlock_country'));
    });
  });

  group('ClaimGolden', () {
    test('equality and toString', () {
      const a = ClaimGolden(goldenId: 'x@1');
      const b = ClaimGolden(goldenId: 'x@1');
      const c = ClaimGolden(goldenId: 'y@1');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.toString(), equals('ClaimGolden(x@1)'));
    });
  });

  group('ActivateBoost', () {
    test('equality, hashCode, toString, exhaustive switch', () {
      const a = ActivateBoost();
      const b = ActivateBoost();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a.toString(), equals('ActivateBoost()'));
      const GameCommand cmd = ActivateBoost();
      final result = switch (cmd) {
        Noop() => 'noop',
        TapCountry() => 'tap_country',
        PurchaseUpgrade() => 'purchase',
        HireLeader() => 'hire',
        UpgradeLeader() => 'upgrade_leader',
        UnlockCountry() => 'unlock_country',
        ClaimGolden() => 'claim_golden',
        ActivateBoost() => 'activate_boost',
      };
      expect(result, equals('activate_boost'));
    });
  });
}
