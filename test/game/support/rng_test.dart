import 'package:test/test.dart';

import 'package:global_domination/game/support/rng.dart';

void main() {
  test('SeededRng: same seed produces identical sequence', () {
    final a = SeededRng(42);
    final b = SeededRng(42);
    for (var i = 0; i < 20; i++) {
      expect(a.nextDouble(), equals(b.nextDouble()));
      expect(a.nextInt(10), equals(b.nextInt(10)));
    }
  });

  test('SeededRng: different seeds diverge', () {
    final a = SeededRng(1);
    final b = SeededRng(2);
    final la = <double>[for (var i = 0; i < 5; i++) a.nextDouble()];
    final lb = <double>[for (var i = 0; i < 5; i++) b.nextDouble()];
    expect(la, isNot(equals(lb)));
  });

  test('SeededRng: nextInt(max) is in [0, max)', () {
    final r = SeededRng(99);
    for (var m = 1; m < 20; m++) {
      for (var i = 0; i < 50; i++) {
        final v = r.nextInt(m);
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThan(m));
      }
    }
  });

  test('SeededRng: nextDouble is in [0.0, 1.0)', () {
    final r = SeededRng(3);
    for (var i = 0; i < 200; i++) {
      final v = r.nextDouble();
      expect(v, greaterThanOrEqualTo(0.0));
      expect(v, lessThan(1.0));
    }
  });

  test('SeededRng equality is keyed by seed', () {
    expect(SeededRng(5), equals(SeededRng(5)));
    expect(SeededRng(5), isNot(equals(SeededRng(6))));
  });
}
