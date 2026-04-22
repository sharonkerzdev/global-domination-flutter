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
      };
      expect(result, equals('tap_country'));
    });
  });
}
