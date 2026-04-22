import 'package:decimal/decimal.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/economy/income_calculator.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

Map<CountryId, CountryState> tickCountries(
  GameState gameState,
  Duration dt,
  ContentRegistry content,
) {
  assert(!dt.isNegative, 'tick dt must be non-negative');

  if (dt == Duration.zero) return gameState.countries;

  final countries = gameState.countries;
  var anyChanged = false;
  final updated = <CountryId, CountryState>{};

  for (final entry in countries.entries) {
    final state = entry.value;
    if (!state.unlocked) {
      updated[entry.key] = state;
      continue;
    }

    final def = content.countries[entry.key];
    if (def == null) {
      updated[entry.key] = state;
      continue;
    }
    if (def.generationSeconds <= 0) {
      updated[entry.key] = state;
      continue;
    }
    final hasLeader = state.leaderTier != LeaderTier.none;

    final ratePerSecond = IncomeCalculator.compute(state, gameState, content);
    if (ratePerSecond.isZero) {
      updated[entry.key] = state;
      continue;
    }

    final dtMicros = Decimal.fromInt(dt.inMicroseconds);
    // With a leader, accrue at true per-second rate (automation / continuous).
    // Without, keep timer-gated pacing via [CountryDef.generationSeconds].
    final periodSeconds = hasLeader ? 1 : def.generationSeconds;
    final genMicros = Decimal.fromInt(periodSeconds * 1000000);
    final ratio = (dtMicros / genMicros).toDecimal(
      scaleOnInfinitePrecision: 18,
    );
    final deltaDecimal = ratePerSecond.value * ratio;
    if (deltaDecimal == Decimal.zero) {
      updated[entry.key] = state;
      continue;
    }
    final delta = Influence(deltaDecimal);
    final newState = state.copyWith(
      bankedInfluence: state.bankedInfluence + delta,
    );
    updated[entry.key] = newState;
    anyChanged = true;
  }

  if (!anyChanged) return countries;
  return updated;
}
