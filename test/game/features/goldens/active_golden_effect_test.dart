import 'package:test/test.dart';

import 'package:global_domination/game/features/goldens/active_golden_effect.dart';

void main() {
  test('ActiveGoldenEffect: equality, hashCode, toString', () {
    const gid = 'g1';
    const mult = 75;
    final t = DateTime.utc(2026, 4, 25, 0);
    final a = ActiveGoldenEffect(goldenId: gid, multiplier: mult, expiresAt: t);
    final b = ActiveGoldenEffect(goldenId: gid, multiplier: mult, expiresAt: t);
    final c = ActiveGoldenEffect(
      goldenId: 'g2',
      multiplier: mult,
      expiresAt: t,
    );
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a, isNot(equals(c)));
    final s = a.toString();
    expect(s, contains(gid));
    expect(s, contains('75'));
  });
}
