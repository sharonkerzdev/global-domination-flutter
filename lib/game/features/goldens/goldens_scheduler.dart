import 'package:decimal/decimal.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/goldens/active_golden.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/game/values/country_id.dart';

/// Per-tick goldens: effect expiry, map-spawn expiry, then optional spawn.
///
/// [content] is reserved for future tuning (Epic 10); spawn rules are currently
/// pure [BalanceConfig] constants. Kept in the signature for scheduler parity
/// with other `evaluateX(state, content, ...)` project patterns.
///
/// When a spawn **probability** roll passes but there are no unlocked
/// countries, the roll's [Rng.nextDouble] is still consumed, but we do **not**
/// call [Rng.nextInt] for country or multiplier, so test seeds stay stable
/// if country unlock flags are toggled in a fixture.
(GameState, List<GameEvent>) evaluateGoldens(
  GameState state,
  ContentRegistry content,
  Duration dt, {
  required DateTime now,
  required Rng rng,
}) {
  const maxTickDt = Duration(milliseconds: 100);
  assert(!dt.isNegative, 'evaluateGoldens dt must be non-negative, got $dt');
  assert(
    BalanceConfig.goldenMinMultiplier <= BalanceConfig.goldenMaxMultiplier,
  );
  assert(content == content);

  // Mirror GameWorld's tick clamp in release mode to keep spawn math bounded.
  final boundedDt = dt.isNegative
      ? Duration.zero
      : (dt > maxTickDt ? maxTickDt : dt);

  final events = <GameEvent>[];
  var nextEffect = state.activeGoldenEffect;
  var nextMult = state.goldenOpportunityMultiplier;
  final working = Map<String, ActiveGolden>.from(state.activeGoldens);

  if (nextEffect != null && nextEffect.expiresAt.compareTo(now) <= 0) {
    events.add(
      GoldenExpired(now, goldenId: nextEffect.goldenId, claimed: true),
    );
    nextEffect = null;
    nextMult = Decimal.one;
  }

  final expiredKeys =
      working.keys
          .where((id) => working[id]!.expiresAt.compareTo(now) <= 0)
          .toList()
        ..sort();
  for (final id in expiredKeys) {
    final entry = working.remove(id)!;
    events.add(GoldenExpired(now, goldenId: entry.id, claimed: false));
  }

  if (boundedDt > Duration.zero &&
      working.length < BalanceConfig.goldenMaxConcurrent) {
    final dtSeconds = boundedDt.inMicroseconds / 1000000.0;
    final rawPTick =
        BalanceConfig.goldenSpawnProbabilityPerSecond.toDouble() * dtSeconds;
    final pTick = rawPTick.clamp(0.0, 1.0);
    final roll = rng.nextDouble();
    if (roll < pTick) {
      final unlocked = <CountryId>[];
      for (final c in state.countries.values) {
        if (c.unlocked) unlocked.add(c.id);
      }
      unlocked.sort((a, b) => a.value.compareTo(b.value));
      if (unlocked.isNotEmpty) {
        final countryIdx = rng.nextInt(unlocked.length);
        final countryId = unlocked[countryIdx];
        final range =
            BalanceConfig.goldenMaxMultiplier -
            BalanceConfig.goldenMinMultiplier +
            1;
        final m = BalanceConfig.goldenMinMultiplier + rng.nextInt(range);
        final id = '${countryId.value}@${now.microsecondsSinceEpoch}';
        final golden = ActiveGolden(
          id: id,
          countryId: countryId,
          multiplier: m,
          expiresAt: now.add(
            const Duration(seconds: BalanceConfig.goldenSpawnExpirySeconds),
          ),
        );
        working[id] = golden;
        events.add(
          GoldenSpawned(
            now,
            goldenId: id,
            countryId: countryId,
            multiplier: m,
            expiresAt: golden.expiresAt,
          ),
        );
      }
    }
  }

  if (events.isEmpty) {
    return (state, const <GameEvent>[]);
  }

  return (
    state.copyWith(
      activeGoldens: working,
      activeGoldenEffect: nextEffect,
      goldenOpportunityMultiplier: nextMult,
    ),
    events,
  );
}
