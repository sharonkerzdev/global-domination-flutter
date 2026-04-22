import 'package:meta/meta.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

@immutable
class GameState {
  final Map<CountryId, CountryState> countries;
  final Influence totalInfluence;

  GameState({
    Map<CountryId, CountryState>? countries,
    Influence? totalInfluence,
  }) : countries = countries ?? const {},
       totalInfluence = totalInfluence ?? Influence.zero;

  GameState copyWith({
    Map<CountryId, CountryState>? countries,
    Influence? totalInfluence,
  }) {
    return GameState(
      countries: countries ?? this.countries,
      totalInfluence: totalInfluence ?? this.totalInfluence,
    );
  }

  static GameState initialSeed(ContentRegistry content) {
    const seedCountryId = CountryId('egypt');
    assert(
      content.countries.containsKey(seedCountryId),
      'ContentRegistry must contain egypt to seed initial state',
    );
    final countries = <CountryId, CountryState>{
      for (final entry in content.countries.entries)
        entry.key: CountryState(
          id: entry.key,
          unlocked: entry.key == seedCountryId,
          ipLevel: entry.key == seedCountryId ? 1 : 0,
          leaderTier: LeaderTier.none,
          bankedInfluence: Influence.zero,
          lastCollectedAt: null,
        ),
    };
    return GameState(
      countries: Map.unmodifiable(countries),
      totalInfluence: Influence.zero,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameState &&
          _mapsEqual(countries, other.countries) &&
          totalInfluence == other.totalInfluence);

  @override
  int get hashCode => Object.hash(_mapHash(countries), totalInfluence);

  @override
  String toString() =>
      'GameState(countries: ${countries.length} entries, '
      'totalInfluence: $totalInfluence)';

  static bool _mapsEqual(
    Map<CountryId, CountryState> a,
    Map<CountryId, CountryState> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static int _mapHash(Map<CountryId, CountryState> map) {
    var h = 0;
    for (final entry in map.entries) {
      h ^= Object.hash(entry.key, entry.value);
    }
    return h;
  }
}
