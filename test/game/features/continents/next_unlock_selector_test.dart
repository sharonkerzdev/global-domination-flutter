import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/features/continents/next_unlock_selector.dart';
import 'package:global_domination/game/features/continents/next_unlock_teaser.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

import '../../../helpers/next_unlock_test_fixtures.dart';

CountryState _cs(CountryId id, {required bool unlocked}) {
  return CountryState(
    id: id,
    unlocked: unlocked,
    ipLevel: unlocked ? 1 : 0,
    leaderTier: LeaderTier.none,
    bankedInfluence: Influence.zero,
  );
}

void main() {
  group('nextUnlockInContinent', () {
    test(
      'all locked in africa returns first declared country with def cost',
      () {
        final content = multiContinentNextUnlockFixture();
        const egypt = CountryId('egypt');
        final state = GameState(
          countries: {
            egypt: _cs(egypt, unlocked: false),
            CountryId('nigeria'): _cs(
              const CountryId('nigeria'),
              unlocked: false,
            ),
            CountryId('kenya'): _cs(const CountryId('kenya'), unlocked: false),
          },
        );
        final t = nextUnlockInContinent(
          state,
          content,
          const ContinentId('africa'),
        );
        expect(t, isNotNull);
        expect(t!.countryId, equals(egypt));
        expect(t.continent, equals(const ContinentId('africa')));
        expect(t.unlockCost, equals(Influence(Decimal.one)));
      },
    );

    test('egypt unlocked returns nigeria with its unlockCost', () {
      final content = multiContinentNextUnlockFixture();
      const egypt = CountryId('egypt');
      const nigeria = CountryId('nigeria');
      final state = GameState(
        countries: {
          egypt: _cs(egypt, unlocked: true),
          nigeria: _cs(nigeria, unlocked: false),
          CountryId('kenya'): _cs(const CountryId('kenya'), unlocked: false),
        },
      );
      final t = nextUnlockInContinent(
        state,
        content,
        const ContinentId('africa'),
      );
      expect(t, isNotNull);
      expect(t!.countryId, equals(nigeria));
      expect(t.unlockCost, equals(Influence(Decimal.fromInt(5))));
    });

    test('every africa country unlocked returns null', () {
      final content = multiContinentNextUnlockFixture();
      final state = GameState(
        countries: {
          CountryId('egypt'): _cs(const CountryId('egypt'), unlocked: true),
          CountryId('nigeria'): _cs(const CountryId('nigeria'), unlocked: true),
          CountryId('kenya'): _cs(const CountryId('kenya'), unlocked: true),
        },
      );
      expect(
        nextUnlockInContinent(state, content, const ContinentId('africa')),
        isNull,
      );
    });

    test('unknown continent id returns null', () {
      final content = multiContinentNextUnlockFixture();
      final state = GameState();
      expect(
        nextUnlockInContinent(state, content, const ContinentId('antarctica')),
        isNull,
      );
    });

    test('missing first declared country state still returns that country', () {
      final content = multiContinentNextUnlockFixture();
      final state = GameState(
        countries: {
          CountryId('nigeria'): _cs(
            const CountryId('nigeria'),
            unlocked: false,
          ),
          CountryId('kenya'): _cs(const CountryId('kenya'), unlocked: false),
        },
      );
      final t = nextUnlockInContinent(
        state,
        content,
        const ContinentId('africa'),
      );
      expect(t, isNotNull);
      expect(t!.countryId, equals(const CountryId('egypt')));
    });

    test('uses declaration order even when a later country is cheaper', () {
      final content = declarationOrderVsCostFixture();
      final state = GameState(
        countries: {
          CountryId('expensive_first'): _cs(
            const CountryId('expensive_first'),
            unlocked: false,
          ),
          CountryId('cheap_second'): _cs(
            const CountryId('cheap_second'),
            unlocked: false,
          ),
        },
      );
      final t = nextUnlockInContinent(
        state,
        content,
        const ContinentId('africa'),
      );
      expect(t, isNotNull);
      expect(t!.countryId, equals(const CountryId('expensive_first')));
      expect(t.unlockCost, equals(Influence(Decimal.fromInt(500))));
    });
  });

  group('nextUnlockOverall', () {
    test('only africa effectively unlocked returns africa next', () {
      final content = multiContinentNextUnlockFixture();
      const egypt = CountryId('egypt');
      final state = GameState(
        totalInfluence: Influence(Decimal.parse('500000000')),
        countries: {
          egypt: _cs(egypt, unlocked: false),
          const CountryId('nigeria'): _cs(
            CountryId('nigeria'),
            unlocked: false,
          ),
        },
      );
      final t = nextUnlockOverall(state, content);
      expect(t, isNotNull);
      expect(t!.continent, equals(const ContinentId('africa')));
      expect(t.countryId, equals(egypt));
    });

    test('africa fully unlocked and europe unlocked returns europe next', () {
      final content = multiContinentNextUnlockFixture();
      final state = GameState(
        totalInfluence: Influence(Decimal.parse('1000000000')),
        countries: {
          CountryId('egypt'): _cs(const CountryId('egypt'), unlocked: true),
          CountryId('nigeria'): _cs(const CountryId('nigeria'), unlocked: true),
          CountryId('kenya'): _cs(const CountryId('kenya'), unlocked: true),
          CountryId('france'): _cs(const CountryId('france'), unlocked: false),
        },
      );
      final t = nextUnlockOverall(state, content);
      expect(t, isNotNull);
      expect(t!.continent, equals(const ContinentId('europe')));
      expect(t.countryId, equals(const CountryId('france')));
      expect(t.unlockCost, equals(Influence(Decimal.fromInt(10))));
    });

    test(
      'africa fully unlocked but europe still below threshold returns null',
      () {
        final content = multiContinentNextUnlockFixture();
        final state = GameState(
          totalInfluence: Influence(Decimal.parse('999999999')),
          countries: {
            CountryId('egypt'): _cs(const CountryId('egypt'), unlocked: true),
            CountryId('nigeria'): _cs(
              const CountryId('nigeria'),
              unlocked: true,
            ),
            CountryId('kenya'): _cs(const CountryId('kenya'), unlocked: true),
            CountryId('france'): _cs(
              const CountryId('france'),
              unlocked: false,
            ),
          },
        );
        expect(nextUnlockOverall(state, content), isNull);
      },
    );

    test(
      'all countries unlocked on every effectively-unlocked continent → null',
      () {
        final content = multiContinentNextUnlockFixture();
        final state = GameState(
          totalInfluence: Influence(Decimal.parse('200000000000000')),
          countries: {
            for (final id in [
              'egypt',
              'nigeria',
              'kenya',
              'france',
              'germany',
              'japan',
            ])
              CountryId(id): _cs(CountryId(id), unlocked: true),
          },
        );
        expect(nextUnlockOverall(state, content), isNull);
      },
    );

    test('totalInfluence below every threshold → null', () {
      final content = allContinentsPositiveThresholdFixture();
      final state = GameState(
        countries: {
          CountryId('onlyland'): _cs(
            const CountryId('onlyland'),
            unlocked: false,
          ),
        },
      );
      expect(nextUnlockOverall(state, content), isNull);
    });

    test('tie on unlockThreshold breaks by ContinentId.value ASC', () {
      final content = tieBreakContinentFixture();
      final state = GameState(
        totalInfluence: Influence(Decimal.fromInt(50)),
        countries: {
          CountryId('magma_a'): _cs(
            const CountryId('magma_a'),
            unlocked: false,
          ),
          CountryId('mica_a'): _cs(const CountryId('mica_a'), unlocked: false),
        },
      );
      final t = nextUnlockOverall(state, content);
      expect(t, isNotNull);
      expect(t!.continent, equals(const ContinentId('magma')));
      expect(t.countryId, equals(const CountryId('magma_a')));
    });

    test('unlockCost matches Influence(def.unlockCost) for teaser country', () {
      final content = multiContinentNextUnlockFixture();
      const nigeria = CountryId('nigeria');
      final state = GameState(
        countries: {
          CountryId('egypt'): _cs(const CountryId('egypt'), unlocked: true),
          nigeria: _cs(nigeria, unlocked: false),
        },
      );
      final def = content.countries[nigeria]!;
      final t = nextUnlockInContinent(
        state,
        content,
        const ContinentId('africa'),
      );
      expect(t!.unlockCost, equals(Influence(def.unlockCost)));
    });
  });

  group('NextUnlockTeaser', () {
    test('equality hashCode and toString', () {
      final a = NextUnlockTeaser(
        countryId: const CountryId('x'),
        unlockCost: Influence(Decimal.fromInt(3)),
        continent: const ContinentId('c'),
      );
      final b = NextUnlockTeaser(
        countryId: const CountryId('x'),
        unlockCost: Influence(Decimal.fromInt(3)),
        continent: const ContinentId('c'),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      final s = a.toString();
      expect(s, contains('x'));
      expect(s, contains('3'));
      expect(s, contains('c'));
    });
  });
}
