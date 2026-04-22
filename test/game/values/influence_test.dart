import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/values/influence.dart';

void main() {
  group('Influence arithmetic', () {
    test('addition', () {
      final a = Influence(Decimal.parse('100'));
      final b = Influence(Decimal.parse('250'));
      expect(a + b, equals(Influence(Decimal.parse('350'))));
    });

    test('subtraction', () {
      final a = Influence(Decimal.parse('500'));
      final b = Influence(Decimal.parse('200'));
      expect(a - b, equals(Influence(Decimal.parse('300'))));
    });

    test('multiplication by Decimal', () {
      final a = Influence(Decimal.parse('100'));
      final factor = Decimal.parse('3.5');
      expect(a * factor, equals(Influence(Decimal.parse('350'))));
    });

    test('multiplication by num', () {
      final a = Influence(Decimal.parse('100'));
      expect(a.multiplyByNum(2.5), equals(Influence(Decimal.parse('250'))));
    });

    test('multiplication by int num', () {
      final a = Influence(Decimal.parse('100'));
      expect(a.multiplyByNum(3), equals(Influence(Decimal.parse('300'))));
    });
  });

  group('Influence precision', () {
    test('1e20 + 3e20 == 4e20 with no precision loss', () {
      final a = Influence(Decimal.parse('1e20'));
      final b = Influence(Decimal.parse('3e20'));
      expect(a + b, equals(Influence(Decimal.parse('4e20'))));
    });

    test('1e38 multiplication preserves precision', () {
      final a = Influence(Decimal.parse('1e38'));
      final factor = Decimal.parse('3.0');
      expect(a * factor, equals(Influence(Decimal.parse('3e38'))));
    });
  });

  group('Influence comparisons', () {
    test('less than', () {
      final a = Influence(Decimal.parse('10'));
      final b = Influence(Decimal.parse('20'));
      expect(a < b, isTrue);
      expect(b < a, isFalse);
    });

    test('greater than', () {
      final a = Influence(Decimal.parse('20'));
      final b = Influence(Decimal.parse('10'));
      expect(a > b, isTrue);
      expect(b > a, isFalse);
    });

    test('less than or equal', () {
      final a = Influence(Decimal.parse('10'));
      final b = Influence(Decimal.parse('10'));
      expect(a <= b, isTrue);
    });

    test('greater than or equal', () {
      final a = Influence(Decimal.parse('10'));
      final b = Influence(Decimal.parse('10'));
      expect(a >= b, isTrue);
    });

    test('compareTo', () {
      final a = Influence(Decimal.parse('10'));
      final b = Influence(Decimal.parse('20'));
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
      expect(a.compareTo(a), equals(0));
    });

    test('comparisons across magnitudes', () {
      final small = Influence(Decimal.parse('1'));
      final large = Influence(Decimal.parse('1e30'));
      expect(small < large, isTrue);
      expect(large > small, isTrue);
    });
  });

  group('Influence equality and hashCode', () {
    test('equal values are equal', () {
      final a = Influence(Decimal.parse('12345'));
      final b = Influence(Decimal.parse('12345'));
      expect(a, equals(b));
    });

    test('equal values have equal hashCodes', () {
      final a = Influence(Decimal.parse('12345'));
      final b = Influence(Decimal.parse('12345'));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different values are not equal', () {
      final a = Influence(Decimal.parse('100'));
      final b = Influence(Decimal.parse('200'));
      expect(a, isNot(equals(b)));
    });

    test('not equal to non-Influence', () {
      final a = Influence(Decimal.parse('100'));
      // ignore: unrelated_type_equality_checks
      expect(a == 100, isFalse);
    });
  });

  group('Influence.zero, isZero, isNegative', () {
    test('zero is zero', () {
      expect(Influence.zero.isZero, isTrue);
      expect(Influence.zero.value, equals(Decimal.zero));
    });

    test('non-zero is not zero', () {
      final a = Influence(Decimal.parse('1'));
      expect(a.isZero, isFalse);
    });

    test('positive is not negative', () {
      final a = Influence(Decimal.parse('10'));
      expect(a.isNegative, isFalse);
    });

    test('negative is negative', () {
      final a = Influence(Decimal.parse('-5'));
      expect(a.isNegative, isTrue);
    });

    test('zero is not negative', () {
      expect(Influence.zero.isNegative, isFalse);
    });
  });

  group('Influence toString', () {
    test('shows debug representation', () {
      final a = Influence(Decimal.parse('42'));
      expect(a.toString(), equals('Influence(42)'));
    });
  });

  group('Influence format', () {
    test('delegates to InfluenceFormatter', () {
      final a = Influence(Decimal.parse('1500'));
      expect(a.format(), equals('1.5K'));
    });

    test('format at 1e35', () {
      final a = Influence(Decimal.parse('1e35'));
      expect(a.format(), equals('100De'));
    });
  });
}
