import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/features/goldens/active_golden.dart';
import 'package:global_domination/game/features/goldens/active_golden_effect.dart';
import 'package:global_domination/game/features/goldens/goldens_reducer.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 12);
  const egypt = CountryId('egypt');
  const nigeria = CountryId('nigeria');
  const kenya = CountryId('kenya');

  CountryState cs(CountryId id, {required bool unlocked}) {
    return CountryState(
      id: id,
      unlocked: unlocked,
      ipLevel: 1,
      leaderTier: LeaderTier.none,
      bankedInfluence: Influence.zero,
      lastCollectedAt: null,
    );
  }

  test('applyClaimGolden: happy path', () {
    final g = ActiveGolden(
      id: 'gid1',
      countryId: egypt,
      multiplier: 42,
      expiresAt: t0.add(const Duration(hours: 1)),
    );
    final s = GameState(
      countries: {egypt: cs(egypt, unlocked: true)},
      activeGoldens: {'gid1': g},
    );
    final r = applyClaimGolden(s, const ClaimGolden(goldenId: 'gid1'), now: t0);
    expect(r.isSuccess, isTrue);
    final (ns, ev) = r.valueOrNull!;
    expect(ns.activeGoldens, isEmpty);
    expect(ns.activeGoldenEffect, isNotNull);
    expect(ns.activeGoldenEffect!.multiplier, equals(42));
    expect(ns.goldenOpportunityMultiplier, equals(Decimal.fromInt(42)));
    expect(
      ns.activeGoldenEffect!.expiresAt,
      equals(
        t0.add(
          const Duration(seconds: BalanceConfig.goldenEffectDurationSeconds),
        ),
      ),
    );
    expect(ev, isA<GoldenClaimed>());
    final ge = ev as GoldenClaimed;
    expect(ge.goldenId, equals('gid1'));
    expect(
      ge.durationSeconds,
      equals(BalanceConfig.goldenEffectDurationSeconds),
    );
  });

  test('7a: golden not found', () {
    final s = GameState(countries: {egypt: cs(egypt, unlocked: true)});
    final r = applyClaimGolden(
      s,
      const ClaimGolden(goldenId: 'missing'),
      now: t0,
    );
    expect(r.isFailure, isTrue);
    expect(
      (r.errorOrNull! as InvalidTarget).detail,
      equals('golden_not_found'),
    );
  });

  test('7b: golden expired, entry stays', () {
    final g = ActiveGolden(
      id: 'gid1',
      countryId: egypt,
      multiplier: 20,
      expiresAt: t0,
    );
    final s = GameState(
      countries: {egypt: cs(egypt, unlocked: true)},
      activeGoldens: {'gid1': g},
    );
    final r = applyClaimGolden(s, const ClaimGolden(goldenId: 'gid1'), now: t0);
    expect(r.isFailure, isTrue);
    expect((r.errorOrNull! as Locked).reason, equals('golden_expired'));
    expect(s.activeGoldens['gid1'], equals(g));
  });

  test('7c: country locked (defensive)', () {
    final g = ActiveGolden(
      id: 'gid1',
      countryId: kenya,
      multiplier: 20,
      expiresAt: t0.add(const Duration(hours: 1)),
    );
    final s = GameState(
      countries: {kenya: cs(kenya, unlocked: false)},
      activeGoldens: {'gid1': g},
    );
    final r = applyClaimGolden(s, const ClaimGolden(goldenId: 'gid1'), now: t0);
    expect(r.isFailure, isTrue);
    expect((r.errorOrNull! as Locked).reason, equals('country_locked'));
  });

  test('replace: new claim supersedes existing effect, only GoldenClaimed', () {
    const oldGid = 'old';
    final oldEffect = ActiveGoldenEffect(
      goldenId: oldGid,
      multiplier: 25,
      expiresAt: DateTime.utc(2026, 1, 1, 12, 0, 15),
    );
    final g = ActiveGolden(
      id: 'newG',
      countryId: nigeria,
      multiplier: 75,
      expiresAt: t0.add(const Duration(hours: 1)),
    );
    final s = GameState(
      countries: {
        egypt: cs(egypt, unlocked: true),
        nigeria: cs(nigeria, unlocked: true),
      },
      activeGoldens: {'newG': g},
      activeGoldenEffect: oldEffect,
      goldenOpportunityMultiplier: Decimal.fromInt(25),
    );
    final r = applyClaimGolden(s, const ClaimGolden(goldenId: 'newG'), now: t0);
    expect(r.isSuccess, isTrue);
    final (ns, ev) = r.valueOrNull!;
    expect(ns.activeGoldenEffect!.multiplier, equals(75));
    expect(ns.activeGoldenEffect!.goldenId, equals('newG'));
    expect(
      ns.activeGoldenEffect!.expiresAt,
      equals(
        t0.add(
          const Duration(seconds: BalanceConfig.goldenEffectDurationSeconds),
        ),
      ),
    );
    expect(ev, isA<GoldenClaimed>());
  });
}
