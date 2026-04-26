import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/features/boosts/boost_state.dart';
import 'package:global_domination/game/features/boosts/boosts_reducer.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/intel.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 12);

  group('applyActivateBoost', () {
    test('happy path spends intel and returns BoostActivated', () {
      final s = GameState(totalIntel: Intel(Decimal.fromInt(500)));
      final r = applyActivateBoost(s, const ActivateBoost(), now: t0);
      expect(r.isSuccess, isTrue);
      final (next, event) = r.valueOrNull!;
      expect(next.totalIntel, Intel(Decimal.fromInt(400)));
      expect(next.activeBoost, isNotNull);
      expect(next.activeBoost!.multiplier, equals(Decimal.parse('2.0')));
      expect(next.activeBoost!.expiresAt, t0.add(const Duration(seconds: 30)));
      final e = event!;
      expect(e, isA<BoostActivated>());
      final a = e as BoostActivated;
      expect(a.at, t0);
      expect(a.multiplier, BalanceConfig.boostMultiplier);
      expect(a.intelSpent, BalanceConfig.boostCost);
    });

    test('boost_already_active when boost still valid', () {
      final s = GameState(
        totalIntel: Intel.zero,
        activeBoost: BoostState(
          multiplier: BalanceConfig.boostMultiplier,
          expiresAt: t0.add(const Duration(seconds: 10)),
        ),
      );
      final r = applyActivateBoost(s, const ActivateBoost(), now: t0);
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull, isA<Locked>());
      expect((r.errorOrNull! as Locked).reason, 'boost_already_active');
    });

    test(
      'allows re-activation when prior boost expiresAt == now (boundary)',
      () {
        final s = GameState(
          totalIntel: Intel(Decimal.fromInt(200)),
          activeBoost: BoostState(
            multiplier: BalanceConfig.boostMultiplier,
            expiresAt: t0,
          ),
        );
        final r = applyActivateBoost(s, const ActivateBoost(), now: t0);
        expect(r.isSuccess, isTrue);
      },
    );

    test('insufficient intel when no active boost', () {
      final s = GameState(totalIntel: Intel(Decimal.fromInt(50)));
      final r = applyActivateBoost(s, const ActivateBoost(), now: t0);
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull, isA<InsufficientIntel>());
      expect(
        (r.errorOrNull! as InsufficientIntel).required,
        BalanceConfig.boostCost,
      );
    });

    test(
      'active boost and low intel: boost_already_active wins (check order)',
      () {
        final s = GameState(
          totalIntel: Intel(Decimal.fromInt(1)),
          activeBoost: BoostState(
            multiplier: BalanceConfig.boostMultiplier,
            expiresAt: t0.add(const Duration(hours: 1)),
          ),
        );
        final r = applyActivateBoost(s, const ActivateBoost(), now: t0);
        expect(r.errorOrNull, isA<Locked>());
        expect((r.errorOrNull! as Locked).reason, 'boost_already_active');
      },
    );

    test('same inputs → identical result (purity)', () {
      final s = GameState(totalIntel: Intel(Decimal.fromInt(200)));
      final a = applyActivateBoost(s, const ActivateBoost(), now: t0);
      final b = applyActivateBoost(s, const ActivateBoost(), now: t0);
      expect(a, equals(b));
    });
  });

  group('evaluateBoostExpiry', () {
    test('no active boost → empty', () {
      final s = GameState();
      final (next, ev) = evaluateBoostExpiry(s, now: t0);
      expect(identical(next, s), isTrue);
      expect(ev, isEmpty);
    });

    test('unexpired boost → empty, same state identity', () {
      final s = GameState(
        activeBoost: BoostState(
          multiplier: Decimal.parse('2'),
          expiresAt: t0.add(const Duration(seconds: 1)),
        ),
      );
      final (next, ev) = evaluateBoostExpiry(s, now: t0);
      expect(identical(next, s), isTrue);
      expect(ev, isEmpty);
    });

    test('expiresAt < now → clear boost and BoostExpired', () {
      final s = GameState(
        activeBoost: BoostState(
          multiplier: Decimal.parse('2'),
          expiresAt: t0.subtract(const Duration(milliseconds: 1)),
        ),
      );
      final (next, ev) = evaluateBoostExpiry(s, now: t0);
      expect(next.activeBoost, isNull);
      expect(ev, hasLength(1));
      expect(ev.single, isA<BoostExpired>());
      expect((ev.single as BoostExpired).at, t0);
    });

    test('expiresAt == now (boundary) → expired', () {
      final s = GameState(
        activeBoost: BoostState(multiplier: Decimal.parse('2'), expiresAt: t0),
      );
      final (next, ev) = evaluateBoostExpiry(s, now: t0);
      expect(next.activeBoost, isNull);
      expect(ev.single, isA<BoostExpired>());
    });

    test('idempotent: second call on cleared state is empty', () {
      final s = GameState(
        activeBoost: BoostState(multiplier: Decimal.parse('2'), expiresAt: t0),
      );
      final (n1, e1) = evaluateBoostExpiry(s, now: t0);
      final (n2, e2) = evaluateBoostExpiry(n1, now: t0);
      expect(e1, hasLength(1));
      expect(e2, isEmpty);
      expect(n2.activeBoost, isNull);
    });
  });
}
