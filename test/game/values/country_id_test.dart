import 'package:test/test.dart';

import 'package:global_domination/game/values/country_id.dart';

void main() {
  group('CountryId', () {
    test('equal when same value', () {
      expect(const CountryId('egypt'), equals(const CountryId('egypt')));
    });

    test('not equal when different value', () {
      expect(
        const CountryId('egypt'),
        isNot(equals(const CountryId('nigeria'))),
      );
    });

    test('same hashCode for equal instances', () {
      expect(
        const CountryId('egypt').hashCode,
        equals(const CountryId('egypt').hashCode),
      );
    });

    test('toString includes value', () {
      expect(const CountryId('egypt').toString(), 'CountryId(egypt)');
    });

    test('can be used as map key', () {
      final map = <CountryId, String>{};
      map[const CountryId('egypt')] = 'Egypt';
      expect(map[const CountryId('egypt')], 'Egypt');
    });
  });
}
