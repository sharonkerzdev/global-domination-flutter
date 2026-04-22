import 'package:test/test.dart';

import 'package:global_domination/game/values/continent_id.dart';

void main() {
  group('ContinentId', () {
    test('equal when same value', () {
      expect(const ContinentId('africa'), equals(const ContinentId('africa')));
    });

    test('not equal when different value', () {
      expect(
        const ContinentId('africa'),
        isNot(equals(const ContinentId('europe'))),
      );
    });

    test('same hashCode for equal instances', () {
      expect(
        const ContinentId('africa').hashCode,
        equals(const ContinentId('africa').hashCode),
      );
    });

    test('toString includes value', () {
      expect(const ContinentId('africa').toString(), 'ContinentId(africa)');
    });

    test('can be used as map key', () {
      final map = <ContinentId, String>{};
      map[const ContinentId('africa')] = 'Africa';
      expect(map[const ContinentId('africa')], 'Africa');
    });
  });
}
