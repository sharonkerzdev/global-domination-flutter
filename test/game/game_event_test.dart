import 'package:test/test.dart';

import 'package:global_domination/game/game_event.dart';

void main() {
  group('Tick', () {
    final now = DateTime.utc(2026, 1, 1);

    test('can be constructed with a DateTime', () {
      final event = Tick(now);
      expect(event, isA<GameEvent>());
      expect(event, isA<Tick>());
      expect(event.at, equals(now));
    });

    test('equality: two Ticks with the same DateTime are equal', () {
      final a = Tick(now);
      final b = Tick(now);
      expect(a, equals(b));
    });

    test('inequality: two Ticks with different DateTimes are not equal', () {
      final a = Tick(now);
      final b = Tick(now.add(const Duration(seconds: 1)));
      expect(a, isNot(equals(b)));
    });

    test('hashCode: equal Ticks have the same hashCode', () {
      final a = Tick(now);
      final b = Tick(now);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString returns expected representation', () {
      final event = Tick(now);
      expect(event.toString(), equals('Tick(at: $now)'));
    });

    test('exhaustive switch compiles on sealed hierarchy', () {
      final GameEvent event = Tick(now);
      final result = switch (event) {
        Tick() => 'tick',
        CountryTapped() => 'country_tapped',
      };
      expect(result, equals('tick'));
    });
  });
}
