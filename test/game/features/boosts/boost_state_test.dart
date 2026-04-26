import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/features/boosts/boost_state.dart';

void main() {
  group('BoostState', () {
    final t1 = DateTime.utc(2026, 1, 1);
    final t2 = DateTime.utc(2026, 1, 2);

    test('equality and hashCode for same (multiplier, expiresAt)', () {
      final a = BoostState(multiplier: Decimal.parse('2.0'), expiresAt: t1);
      final b = BoostState(multiplier: Decimal.parse('2.0'), expiresAt: t1);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when multiplier differs', () {
      final a = BoostState(multiplier: Decimal.parse('2.0'), expiresAt: t1);
      final b = BoostState(multiplier: Decimal.parse('3.0'), expiresAt: t1);
      expect(a, isNot(equals(b)));
    });

    test('inequality when expiresAt differs', () {
      final a = BoostState(multiplier: Decimal.parse('2.0'), expiresAt: t1);
      final b = BoostState(multiplier: Decimal.parse('2.0'), expiresAt: t2);
      expect(a, isNot(equals(b)));
    });

    test('toString includes both fields', () {
      final s = BoostState(multiplier: Decimal.parse('2.0'), expiresAt: t1);
      expect(s.toString(), contains('multiplier'));
      expect(s.toString(), contains('expiresAt'));
    });
  });
}
