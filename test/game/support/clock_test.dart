import 'package:test/test.dart';

import 'package:global_domination/game/support/clock.dart';

import '../../helpers/fake_clock.dart';

void main() {
  group('SystemClock', () {
    test('now() returns a DateTime', () {
      const clock = SystemClock();
      final result = clock.now();
      expect(result, isA<DateTime>());
    });

    test('now() returns a time close to the current time', () {
      const clock = SystemClock();
      final before = DateTime.now();
      final result = clock.now();
      final after = DateTime.now();
      expect(
        result.millisecondsSinceEpoch,
        greaterThanOrEqualTo(before.millisecondsSinceEpoch),
      );
      expect(
        result.millisecondsSinceEpoch,
        lessThanOrEqualTo(after.millisecondsSinceEpoch),
      );
    });
  });

  group('FakeClock', () {
    test('returns the initial time', () {
      final initial = DateTime.utc(2026, 1, 1);
      final clock = FakeClock(initial);
      expect(clock.now(), equals(initial));
    });

    test('advance moves time forward correctly', () {
      final initial = DateTime.utc(2026, 1, 1);
      final clock = FakeClock(initial);
      clock.advance(const Duration(seconds: 30));
      expect(clock.now(), equals(DateTime.utc(2026, 1, 1, 0, 0, 30)));
    });

    test('multiple advances accumulate', () {
      final initial = DateTime.utc(2026, 1, 1);
      final clock = FakeClock(initial);
      clock.advance(const Duration(seconds: 10));
      clock.advance(const Duration(seconds: 20));
      expect(clock.now(), equals(DateTime.utc(2026, 1, 1, 0, 0, 30)));
    });
  });
}
