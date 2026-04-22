import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/values/influence_formatter.dart';

void main() {
  group('InfluenceFormatter.abbreviated', () {
    group('below 1000 — plain integer', () {
      test('zero', () {
        expect(InfluenceFormatter.abbreviated(Decimal.zero), equals('0'));
      });

      test('small value', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('42')),
          equals('42'),
        );
      });

      test('999', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('999')),
          equals('999'),
        );
      });

      test('fractional below 1000 truncates', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('999.99')),
          equals('999'),
        );
      });

      test('value of 1', () {
        expect(InfluenceFormatter.abbreviated(Decimal.parse('1')), equals('1'));
      });
    });

    group('each abbreviation tier at exact boundary', () {
      test('1K', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1000')),
          equals('1K'),
        );
      });

      test('1M', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1e6')),
          equals('1M'),
        );
      });

      test('1B', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1e9')),
          equals('1B'),
        );
      });

      test('1T', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1e12')),
          equals('1T'),
        );
      });

      test('1Qa', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1e15')),
          equals('1Qa'),
        );
      });

      test('1Qi', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1e18')),
          equals('1Qi'),
        );
      });

      test('1Sx', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1e21')),
          equals('1Sx'),
        );
      });

      test('1Sp', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1e24')),
          equals('1Sp'),
        );
      });

      test('1Oc', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1e27')),
          equals('1Oc'),
        );
      });

      test('1No', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1e30')),
          equals('1No'),
        );
      });

      test('1De', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1e33')),
          equals('1De'),
        );
      });
    });

    group('intermediate values', () {
      test('1500 → 1.5K', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1500')),
          equals('1.5K'),
        );
      });

      test('2345678 → 2.34M', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('2345678')),
          equals('2.34M'),
        );
      });

      test('1500000000 → 1.5B', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1500000000')),
          equals('1.5B'),
        );
      });

      test('42300000000000 → 42.3T', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('42300000000000')),
          equals('42.3T'),
        );
      });
    });

    group('1e35 returns abbreviated notation (AC #3)', () {
      test('1e35 → 100De', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1e35')),
          equals('100De'),
        );
      });
    });

    group('values above De (1e36+)', () {
      test('1e36 → 1000De', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1e36')),
          equals('1000De'),
        );
      });

      test('1e38 → 100000De', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1e38')),
          equals('100000De'),
        );
      });

      test('5.5e34 → 55De', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('5.5e34')),
          equals('55De'),
        );
      });
    });

    group('negative values', () {
      test('negative small', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('-42')),
          equals('-42'),
        );
      });

      test('negative with suffix', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('-1500')),
          equals('-1.5K'),
        );
      });

      test('negative large', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('-2500000')),
          equals('-2.5M'),
        );
      });
    });

    group('no trailing zeros', () {
      test('1000 → 1K (not 1.00K)', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1000')),
          equals('1K'),
        );
      });

      test('1100 → 1.1K (not 1.10K)', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1100')),
          equals('1.1K'),
        );
      });

      test('1500000 → 1.5M (not 1.50M)', () {
        expect(
          InfluenceFormatter.abbreviated(Decimal.parse('1500000')),
          equals('1.5M'),
        );
      });
    });
  });
}
