import 'package:test/test.dart';

import 'package:global_domination/game/features/goldens/active_golden.dart';
import 'package:global_domination/game/values/country_id.dart';

void main() {
  test('ActiveGolden: equality, hashCode, toString', () {
    const id = 'eg@100';
    const egypt = CountryId('egypt');
    final t = DateTime.utc(2026, 1, 1, 12);
    const m = 50;
    final a = ActiveGolden(
      id: id,
      countryId: egypt,
      multiplier: m,
      expiresAt: t,
    );
    final b = ActiveGolden(
      id: id,
      countryId: egypt,
      multiplier: m,
      expiresAt: t,
    );
    final c = ActiveGolden(
      id: 'other',
      countryId: egypt,
      multiplier: m,
      expiresAt: t,
    );
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a, isNot(equals(c)));
    final s = a.toString();
    expect(s, contains('egypt'));
    expect(s, contains(id));
    expect(s, contains('50'));
  });
}
