import 'package:test/test.dart';

import 'package:global_domination/game/game_state.dart';

void main() {
  group('GameState', () {
    test('can be constructed with default args', () {
      final state = GameState();
      expect(state, isA<GameState>());
    });

    test('equality: two default GameState instances are equal', () {
      final a = GameState();
      final b = GameState();
      expect(a, equals(b));
    });

    test(
      'hashCode: two default GameState instances have the same hashCode',
      () {
        final a = GameState();
        final b = GameState();
        expect(a.hashCode, equals(b.hashCode));
      },
    );

    test('toString returns expected representation', () {
      expect(
        GameState().toString(),
        equals('GameState(countries: 0 entries, totalInfluence: Influence(0))'),
      );
    });

    test('copyWith returns an equal GameState', () {
      final original = GameState();
      final copy = original.copyWith();
      expect(copy, equals(original));
    });
  });
}
