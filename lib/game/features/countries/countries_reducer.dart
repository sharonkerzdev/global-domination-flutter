import 'package:decimal/decimal.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

Map<CountryId, CountryState> tickCountries(
  Map<CountryId, CountryState> countries,
  Duration dt,
  ContentRegistry content,
) {
  assert(!dt.isNegative, 'tick dt must be non-negative');

  if (dt == Duration.zero) return countries;

  var anyChanged = false;
  final updated = <CountryId, CountryState>{};

  for (final entry in countries.entries) {
    final state = entry.value;
    if (!state.unlocked) {
      updated[entry.key] = state;
      continue;
    }

    final def = content.countries[entry.key];
    if (def == null || def.generationSeconds <= 0) {
      updated[entry.key] = state;
      continue;
    }

    final dtMicros = Decimal.fromInt(dt.inMicroseconds);
    final genMicros = Decimal.fromInt(def.generationSeconds * 1000000);
    final ratio = (dtMicros / genMicros).toDecimal(
      scaleOnInfinitePrecision: 18,
    );
    final deltaDecimal = def.baseInfluence * ratio;
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
