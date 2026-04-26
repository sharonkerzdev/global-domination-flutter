import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/features/boosts/boost_state.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/intel.dart';

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
        equals(
          'GameState(countries: 0 entries, totalInfluence: Influence(0), '
          'totalIntel: Intel(0), '
          'unlockedContinents: 0, reachedMilestones: 0, continentCompletions: 0, '
          'earnedAchievementIds: 0, '
          'activeGlobalUpgradeIds: 0, goldenOpportunityMultiplier: 1, '
          'activeBoost: null, activeGoldens: 0, activeGoldenEffect: null)',
        ),
      );
    });

    test('copyWith returns an equal GameState', () {
      final original = GameState();
      final copy = original.copyWith();
      expect(copy, equals(original));
    });

    test('equality includes unlockedContinents', () {
      const id = ContinentId('africa');
      final a = GameState(unlockedContinents: {id: true});
      final b = GameState(unlockedContinents: {id: true});
      final c = GameState(unlockedContinents: {id: false});
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('equality includes totalIntel', () {
      final a = GameState(totalIntel: Intel(Decimal.fromInt(10)));
      final b = GameState(totalIntel: Intel(Decimal.fromInt(10)));
      final c = GameState(totalIntel: Intel(Decimal.fromInt(5)));
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('equality includes activeBoost', () {
      final t1 = DateTime.utc(2026, 1, 1);
      final t2 = DateTime.utc(2026, 1, 2);
      final boost = BoostState(multiplier: Decimal.parse('2'), expiresAt: t1);
      final a = GameState(activeBoost: boost);
      final b = GameState(
        activeBoost: BoostState(multiplier: Decimal.parse('2'), expiresAt: t1),
      );
      final c = GameState(
        activeBoost: BoostState(multiplier: Decimal.parse('2'), expiresAt: t2),
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith clears activeBoost back to null', () {
      final s = GameState(
        activeBoost: BoostState(
          multiplier: Decimal.parse('2'),
          expiresAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final cleared = s.copyWith(activeBoost: null);
      expect(cleared.activeBoost, isNull);
    });

    test('equality includes reachedMilestones nested sets', () {
      const id = ContinentId('africa');
      final a = GameState(
        reachedMilestones: {
          id: {25, 50},
        },
      );
      final b = GameState(
        reachedMilestones: {
          id: {25, 50},
        },
      );
      final c = GameState(
        reachedMilestones: {
          id: {25},
        },
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith round-trips reachedMilestones', () {
      const id = ContinentId('africa');
      final s = GameState(
        reachedMilestones: {
          id: {25},
        },
      );
      final t = s.copyWith(
        reachedMilestones: {
          id: {25, 50},
        },
      );
      expect(t.reachedMilestones[id], {25, 50});
    });
  });
}
