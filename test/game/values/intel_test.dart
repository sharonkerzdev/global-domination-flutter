import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/values/intel.dart';

void main() {
  group('Intel arithmetic', () {
    test('addition', () {
      final a = Intel(Decimal.parse('50'));
      final b = Intel(Decimal.parse('30'));
      expect(a + b, equals(Intel(Decimal.parse('80'))));
    });

    test('subtraction', () {
      final a = Intel(Decimal.parse('50'));
      final b = Intel(Decimal.parse('18'));
      expect(a - b, equals(Intel(Decimal.parse('32'))));
    });

    test('multiplication by Decimal', () {
      final a = Intel(Decimal.parse('10'));
      final factor = Decimal.parse('2.5');
      expect(a * factor, equals(Intel(Decimal.parse('25'))));
    });

    test('multiplication by num', () {
      final a = Intel(Decimal.parse('20'));
      expect(a.multiplyByNum(3), equals(Intel(Decimal.parse('60'))));
    });
  });

  group('Intel precision', () {
    test('1e20 + 3e20 == 4e20 with no precision loss', () {
      final a = Intel(Decimal.parse('1e20'));
      final b = Intel(Decimal.parse('3e20'));
      expect(a + b, equals(Intel(Decimal.parse('4e20'))));
    });
  });

  group('Intel equality and comparisons', () {
    test('equal values are equal', () {
      final a = Intel(Decimal.parse('42'));
      final b = Intel(Decimal.parse('42'));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different values are not equal', () {
      final a = Intel(Decimal.parse('10'));
      final b = Intel(Decimal.parse('20'));
      expect(a, isNot(equals(b)));
    });

    test('less than', () {
      final a = Intel(Decimal.parse('5'));
      final b = Intel(Decimal.parse('10'));
      expect(a < b, isTrue);
    });

    test('greater than', () {
      final a = Intel(Decimal.parse('10'));
      final b = Intel(Decimal.parse('5'));
      expect(a > b, isTrue);
    });

    test('less than or equal', () {
      final a = Intel(Decimal.parse('10'));
      expect(a <= a, isTrue);
    });

    test('greater than or equal', () {
      final a = Intel(Decimal.parse('10'));
      expect(a >= a, isTrue);
    });

    test('compareTo', () {
      final a = Intel(Decimal.parse('5'));
      final b = Intel(Decimal.parse('10'));
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
      expect(a.compareTo(a), equals(0));
    });
  });

  group('Intel.zero, isZero, isNegative', () {
    test('zero is zero', () {
      expect(Intel.zero.isZero, isTrue);
      expect(Intel.zero.value, equals(Decimal.zero));
    });

    test('non-zero is not zero', () {
      expect(Intel(Decimal.parse('1')).isZero, isFalse);
    });

    test('positive is not negative', () {
      expect(Intel(Decimal.parse('10')).isNegative, isFalse);
    });

    test('negative is negative', () {
      expect(Intel(Decimal.parse('-5')).isNegative, isTrue);
    });
  });

  group('Intel toString', () {
    test('shows debug representation', () {
      expect(Intel(Decimal.parse('18')).toString(), equals('Intel(18)'));
    });
  });

  group('Intel format', () {
    test('delegates to formatter', () {
      expect(Intel(Decimal.parse('2500')).format(), equals('2.5K'));
    });
  });
}
