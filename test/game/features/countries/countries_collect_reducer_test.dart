import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/features/countries/countries_collect_reducer.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

CountryState _country(
  String id, {
  bool unlocked = true,
  Influence? bankedInfluence,
  DateTime? lastCollectedAt,
}) {
  return CountryState(
    id: CountryId(id),
    unlocked: unlocked,
    ipLevel: 0,
    leaderTier: LeaderTier.none,
    bankedInfluence: bankedInfluence ?? Influence.zero,
    lastCollectedAt: lastCollectedAt,
  );
}

GameState _stateWith(Map<String, CountryState> countries, {Influence? total}) {
  return GameState(
    countries: {for (final e in countries.entries) CountryId(e.key): e.value},
    totalInfluence: total ?? Influence.zero,
  );
}

void main() {
  final now = DateTime.utc(2026, 1, 1, 12);

  group('collectInfluence', () {
    test(
      '4.1: country with banked > 0 → totalInfluence increases, banked resets, CountryTapped emitted',
      () {
        final banked = Influence(Decimal.parse('5'));
        final state = _stateWith({
          'egypt': _country('egypt', bankedInfluence: banked),
        });
        final cmd = const TapCountry(countryId: CountryId('egypt'));

        final result = collectInfluence(state, cmd, now: now);

        expect(result.isSuccess, isTrue);
        final (newState, event) = result.valueOrNull!;
        expect(newState.totalInfluence, equals(Influence(Decimal.parse('5'))));
        expect(
          newState.countries[CountryId('egypt')]!.bankedInfluence,
          equals(Influence.zero),
        );
        expect(event, isA<CountryTapped>());
        final tap = event! as CountryTapped;
        expect(tap.countryId, equals(CountryId('egypt')));
        expect(tap.collected, equals(banked));
        expect(tap.at, equals(now));
      },
    );

    test('4.2: country with banked = 0 → success, no event emitted', () {
      final state = _stateWith({
        'egypt': _country('egypt', bankedInfluence: Influence.zero),
      });
      final cmd = const TapCountry(countryId: CountryId('egypt'));

      final result = collectInfluence(state, cmd, now: now);

      expect(result.isSuccess, isTrue);
      final (newState, event) = result.valueOrNull!;
      expect(event, isNull);
      expect(newState.totalInfluence, equals(Influence.zero));
    });

    test('4.3: country not found → GameError.internalMissingCountry', () {
      final state = _stateWith({});
      final cmd = const TapCountry(countryId: CountryId('egypt'));

      final result = collectInfluence(state, cmd, now: now);

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<MissingCountry>());
      final err = result.errorOrNull! as MissingCountry;
      expect(err.id, equals(CountryId('egypt')));
    });

    test('4.4: country locked → GameError.userLocked', () {
      final state = _stateWith({
        'egypt': _country(
          'egypt',
          unlocked: false,
          bankedInfluence: Influence(Decimal.one),
        ),
      });
      final cmd = const TapCountry(countryId: CountryId('egypt'));

      final result = collectInfluence(state, cmd, now: now);

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<Locked>());
    });

    test(
      '4.5: large Decimal values (1e30) — precision preserved through collect',
      () {
        final bigVal = Decimal.parse('1000000000000000000000000000000'); // 1e30
        final banked = Influence(bigVal);
        final state = _stateWith({
          'egypt': _country('egypt', bankedInfluence: banked),
        });
        final cmd = const TapCountry(countryId: CountryId('egypt'));

        final result = collectInfluence(state, cmd, now: now);

        expect(result.isSuccess, isTrue);
        final (newState, event) = result.valueOrNull!;
        expect(newState.totalInfluence.value, equals(bigVal));
        final tap = event! as CountryTapped;
        expect(tap.collected.value, equals(bigVal));
      },
    );

    test('4.6: lastCollectedAt updated to injected now', () {
      final oldTime = DateTime.utc(2025, 1, 1);
      final state = _stateWith({
        'egypt': _country(
          'egypt',
          bankedInfluence: Influence(Decimal.one),
          lastCollectedAt: oldTime,
        ),
      });
      final cmd = const TapCountry(countryId: CountryId('egypt'));

      final result = collectInfluence(state, cmd, now: now);

      expect(result.isSuccess, isTrue);
      final (newState, _) = result.valueOrNull!;
      expect(
        newState.countries[CountryId('egypt')]!.lastCollectedAt,
        equals(now),
      );
    });

    test(
      '4.7: collecting from one country does not affect other countries bankedInfluence',
      () {
        final egyptBanked = Influence(Decimal.parse('3'));
        final ghanaBanked = Influence(Decimal.parse('7'));
        final state = _stateWith({
          'egypt': _country('egypt', bankedInfluence: egyptBanked),
          'ghana': _country('ghana', bankedInfluence: ghanaBanked),
        });
        final cmd = const TapCountry(countryId: CountryId('egypt'));

        final result = collectInfluence(state, cmd, now: now);

        expect(result.isSuccess, isTrue);
        final (newState, _) = result.valueOrNull!;
        expect(
          newState.countries[CountryId('ghana')]!.bankedInfluence,
          equals(ghanaBanked),
        );
        expect(
          newState.countries[CountryId('egypt')]!.bankedInfluence,
          equals(Influence.zero),
        );
      },
    );

    test('zero-banked collect returns same state value (no mutations)', () {
      final state = _stateWith({'egypt': _country('egypt')});
      final cmd = const TapCountry(countryId: CountryId('egypt'));

      final result = collectInfluence(state, cmd, now: now);

      expect(result.isSuccess, isTrue);
      final (newState, _) = result.valueOrNull!;
      expect(newState, equals(state));
    });

    test('totalInfluence accumulates correctly across sequential collects', () {
      final state = _stateWith({
        'egypt': _country(
          'egypt',
          bankedInfluence: Influence(Decimal.parse('4')),
        ),
      });
      final cmd = const TapCountry(countryId: CountryId('egypt'));

      // First collect
      var result = collectInfluence(state, cmd, now: now);
      expect(result.isSuccess, isTrue);
      final (state1, _) = result.valueOrNull!;
      expect(state1.totalInfluence, equals(Influence(Decimal.parse('4'))));

      // Re-bank some influence then collect again
      final state2 = state1.copyWith(
        countries: {
          CountryId('egypt'): state1.countries[CountryId('egypt')]!.copyWith(
            bankedInfluence: Influence(Decimal.parse('6')),
          ),
        },
      );
      result = collectInfluence(state2, cmd, now: now);
      expect(result.isSuccess, isTrue);
      final (state3, _) = result.valueOrNull!;
      expect(state3.totalInfluence, equals(Influence(Decimal.parse('10'))));
    });
  });
}
